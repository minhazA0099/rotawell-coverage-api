"""Baseline demand forecast: a weekday-seasonal moving average.

Deliberately simple. In the delivery strategy this is the "champion" that any new
machine-learning model has to beat in a backtest before it can be promoted.
"""

import math

from app.errors import ValidationError

SEASON_DAYS = 7
MAX_HORIZON_DAYS = 28


def _usable(value: object) -> bool:
    return (
        not isinstance(value, bool)
        and isinstance(value, int | float)
        and math.isfinite(value)
        and value >= 0
    )


def _history(raw: object) -> list[float]:
    if not isinstance(raw, list) or not all(_usable(value) for value in raw):
        raise ValidationError("history must be a list of non-negative numbers")
    if len(raw) < SEASON_DAYS:
        raise ValidationError(f"history must contain at least {SEASON_DAYS} days")
    return [float(value) for value in raw]


def forecast_demand(history: object, horizon: object = SEASON_DAYS, weeks: int = 4) -> list[float]:
    """Forecast each future day as the mean of the same weekday over the last ``weeks`` weeks."""
    series = _history(history)
    whole_number = isinstance(horizon, int) and not isinstance(horizon, bool)
    if not whole_number or not 1 <= horizon <= MAX_HORIZON_DAYS:
        raise ValidationError(f"horizon must be a whole number of days from 1 to {MAX_HORIZON_DAYS}")
    observed = len(series)
    for _ in range(horizon):
        position = len(series)
        same_weekday = [
            series[position - SEASON_DAYS * week]
            for week in range(1, weeks + 1)
            if position - SEASON_DAYS * week >= 0
        ]
        series.append(round(sum(same_weekday) / len(same_weekday), 2))
    return series[observed:]


def mean_absolute_percentage_error(actual: list[float], predicted: list[float]) -> float:
    """MAPE in percent, ignoring days where actual demand was zero."""
    pairs = [(a, p) for a, p in zip(actual, predicted, strict=True) if a != 0]
    if not pairs:
        raise ValidationError("MAPE is undefined when every actual value is zero")
    return round(100 * sum(abs(a - p) / a for a, p in pairs) / len(pairs), 2)


def backtest(history: object, holdout_days: int = SEASON_DAYS) -> float:
    """Hide the most recent days, forecast them from the rest and return the MAPE (%)."""
    series = _history(history)
    if len(series) < SEASON_DAYS + holdout_days:
        raise ValidationError(f"backtest needs at least {SEASON_DAYS + holdout_days} days of history")
    training, actual = series[:-holdout_days], series[-holdout_days:]
    return mean_absolute_percentage_error(actual, forecast_demand(training, horizon=holdout_days))
