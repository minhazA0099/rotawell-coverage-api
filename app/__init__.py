"""Rotawell coverage API."""

from flask import Flask, jsonify

from app.api import api


def create_app() -> Flask:
    """Application factory used by tests, gunicorn and local runs."""
    app = Flask(__name__)
    app.register_blueprint(api)

    @app.get("/healthz")
    def healthz():
        return jsonify(status="ok")

    return app
