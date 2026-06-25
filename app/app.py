import os
import socket

from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/")
def index():
    return jsonify(
        message="Hello from my highly available Flask app, deployed via CI/CD!",
        served_by=socket.gethostname(),
    )


@app.route("/health")
def health():
    # Used by the ALB target group health check. Keep this fast and
    # dependency-free so a slow downstream service doesn't cause the
    # ALB to mark a healthy instance as unhealthy.
    return jsonify(status="ok"), 200


if __name__ == "__main__":
    port = int(os.environ.get("APP_PORT", 5000))
    app.run(host="0.0.0.0", port=port)
