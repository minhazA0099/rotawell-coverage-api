"""Errors shared by the calculation modules and the HTTP layer."""


class ValidationError(ValueError):
    """Raised when input cannot be used for a calculation; returned to clients as HTTP 400."""
