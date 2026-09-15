"""Rotawell coverage API."""

from flask import Flask, jsonify


def create_app() -> Flask:
    """Application factory used by tests, gunicorn and local runs."""
    app = Flask(__name__)

    @app.get("/healthz")
    def healthz():
        return jsonify(status="ok")

    return app
