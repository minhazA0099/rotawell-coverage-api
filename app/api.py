"""Version 1 of the HTTP API."""

from flask import Blueprint, jsonify, request

from app.coverage import calculate_coverage, parse_demand, parse_shifts
from app.errors import ValidationError

api = Blueprint("api_v1", __name__, url_prefix="/api/v1")


def _json_object() -> dict:
    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        raise ValidationError("request body must be a JSON object")
    return body


@api.errorhandler(ValidationError)
def _validation_error(error: ValidationError):
    return jsonify(error=str(error)), 400


@api.post("/coverage")
def coverage():
    body = _json_object()
    demand = parse_demand(body.get("demand"))
    shifts = parse_shifts(body.get("shifts", []))
    return jsonify(calculate_coverage(demand, shifts))
