"""Rotawell coverage API."""

from flask import Flask, jsonify

from app.api import api
from app.version import build_info


def create_app() -> Flask:
    """Application factory used by tests, gunicorn and local runs."""
    app = Flask(__name__)
    app.register_blueprint(api)

    @app.get("/healthz")
    def healthz():
        return jsonify(status="ok")

    @app.get("/version")
    def version():
        return jsonify(build_info())

    return app
