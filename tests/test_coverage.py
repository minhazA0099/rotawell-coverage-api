import pytest

from app.coverage import Shift, calculate_coverage, parse_demand, parse_shifts
from app.errors import ValidationError


def test_day_shift_covers_start_hour_but_not_end_hour():
    shift = Shift(start=9, end=17)

    assert shift.covers(9)
    assert shift.covers(16)
    assert not shift.covers(17)
    assert not shift.covers(8)


def test_overnight_shift_wraps_past_midnight():
    shift = Shift(start=22, end=6)

    assert shift.covers(23)
    assert shift.covers(0)
    assert shift.covers(5)
    assert not shift.covers(6)
    assert not shift.covers(21)


@pytest.mark.parametrize(
    ("start", "end"),
    [(9, 9), (-1, 5), (5, 24), ("9", 17), (True, 17), (None, 17)],
)
def test_invalid_shifts_are_rejected(start, end):
    with pytest.raises(ValidationError):
        Shift(start=start, end=end)


def test_parse_demand_maps_hours_to_required_staff():
    assert parse_demand([{"hour": 8, "required": 3}, {"hour": 9, "required": 0}]) == {8: 3, 9: 0}


@pytest.mark.parametrize(
    "raw",
    [
        None,
        [],
        "8:3",
        [8, 3],
        [{"hour": 8, "required": -1}],
        [{"hour": 8, "required": 2.5}],
        [{"hour": 8, "required": True}],
        [{"hour": 8, "required": 1}, {"hour": 8, "required": 2}],
    ],
)
def test_parse_demand_rejects_bad_input(raw):
    with pytest.raises(ValidationError):
        parse_demand(raw)


def test_parse_shifts_builds_validated_shifts():
    assert parse_shifts([{"start": 7, "end": 15}]) == [Shift(start=7, end=15)]


def test_coverage_reports_gaps_per_hour():
    demand = {7: 1, 8: 3, 9: 2}
    shifts = [Shift(7, 15), Shift(8, 16)]

    result = calculate_coverage(demand, shifts)

    assert result["hours"] == [
        {"hour": 7, "required": 1, "scheduled": 1, "gap": 0},
        {"hour": 8, "required": 3, "scheduled": 2, "gap": -1},
        {"hour": 9, "required": 2, "scheduled": 2, "gap": 0},
    ]
    assert result["understaffed_hours"] == [8]
    assert result["overstaffed_hours"] == []


def test_overstaffing_one_hour_does_not_hide_understaffing_in_another():
    demand = {8: 1, 9: 3}
    shifts = [Shift(8, 9), Shift(8, 9)]

    result = calculate_coverage(demand, shifts)

    assert result["overstaffed_hours"] == [8]
    assert result["understaffed_hours"] == [9]
    assert result["coverage_ratio"] == 0.25


def test_zero_demand_counts_as_fully_covered():
    assert calculate_coverage({3: 0}, [])["coverage_ratio"] == 1.0
