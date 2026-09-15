import pytest

from app.errors import ValidationError
from app.forecast import backtest, forecast_demand, mean_absolute_percentage_error

WEEK = [100, 120, 130, 125, 180, 240, 210]  # covers, Monday to Sunday


def test_one_week_of_history_repeats_the_weekly_pattern():
    assert forecast_demand(WEEK, horizon=7) == [float(value) for value in WEEK]


def test_averages_the_same_weekday_across_recent_weeks():
    history = WEEK + [value + 20 for value in WEEK]

    assert forecast_demand(history, horizon=2) == [110.0, 130.0]


def test_only_the_most_recent_weeks_count():
    history = [0] * 7 + WEEK * 4

    assert forecast_demand(history, horizon=1, weeks=4) == [100.0]


def test_horizon_longer_than_a_week_builds_on_earlier_forecasts():
    assert forecast_demand(WEEK, horizon=14)[7:] == [float(value) for value in WEEK]


@pytest.mark.parametrize(
    "history",
    [
        None,
        "100,120",
        [100] * 6,
        [100, -1, 3, 4, 5, 6, 7],
        [100, True, 3, 4, 5, 6, 7],
        [float("nan")] * 7,
    ],
)
def test_rejects_unusable_history(history):
    with pytest.raises(ValidationError):
        forecast_demand(history)


@pytest.mark.parametrize("horizon", [0, 29, 2.5, True, "7"])
def test_rejects_unusable_horizon(horizon):
    with pytest.raises(ValidationError):
        forecast_demand(WEEK, horizon=horizon)


def test_mape_ignores_days_with_zero_actual_demand():
    assert mean_absolute_percentage_error([100, 0, 50], [90, 5, 55]) == 10.0


def test_mape_is_undefined_when_every_actual_is_zero():
    with pytest.raises(ValidationError):
        mean_absolute_percentage_error([0, 0], [1, 2])


def test_backtest_is_perfect_for_a_repeating_pattern():
    assert backtest(WEEK * 3) == 0.0


def test_backtest_needs_two_weeks_of_history():
    with pytest.raises(ValidationError):
        backtest(WEEK)
