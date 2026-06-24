#!/bin/bash
# Bootstraps an Amazon Linux 2023 instance to run the Flask app.
# Runs once at boot via EC2 user-data.
set -euxo pipefail

dnf update -y
dnf install -y python3 python3-pip unzip amazon-cloudwatch-agent

mkdir -p /opt/app
cd /opt/app

# Pull the latest app artifact built & uploaded by the CI/CD pipeline.
aws s3 cp "s3://${artifact_bucket}/${artifact_key}" /opt/app/app.zip --region "${aws_region}"
unzip -o /opt/app/app.zip -d /opt/app
pip3 install -r /opt/app/requirements.txt

# Create a dedicated, unprivileged user to run the app (least privilege).
id -u appuser &>/dev/null || useradd -r -s /sbin/nologin appuser
chown -R appuser:appuser /opt/app

# systemd unit so the app survives reboots and restarts on crash.
cat > /etc/systemd/system/flaskapp.service <<'EOF'
[Unit]
Description=Flask demo application
After=network.target

[Service]
Type=simple
User=appuser
WorkingDirectory=/opt/app
ExecStart=/usr/bin/python3 -m gunicorn -w 2 -b 0.0.0.0:${app_port} app:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

pip3 install gunicorn

systemctl daemon-reload
systemctl enable flaskapp
systemctl restart flaskapp

# Minimal CloudWatch agent config: ship app + system logs.
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/${project_name}/system",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
