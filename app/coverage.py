"""Compare scheduled shifts with hourly staffing demand for a single day."""

from collections.abc import Mapping
from dataclasses import dataclass

from app.errors import ValidationError

HOURS_IN_DAY = 24


def _records(raw: object, field: str) -> list[Mapping[str, object]]:
    if not isinstance(raw, list) or not all(isinstance(item, Mapping) for item in raw):
        raise ValidationError(f"{field} must be a list of objects")
    return raw


def _hour(value: object, field: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or not 0 <= value < HOURS_IN_DAY:
        raise ValidationError(f"{field} must be a whole hour from 0 to 23")
    return value


@dataclass(frozen=True)
class Shift:
    """A shift from ``start`` (inclusive) to ``end`` (exclusive), in whole hours.

    When ``end`` is earlier than ``start`` the shift runs overnight, for example 22 to 6.
    """

    start: int
    end: int

    def __post_init__(self) -> None:
        _hour(self.start, "shift start")
        _hour(self.end, "shift end")
        if self.start == self.end:
            raise ValidationError("a shift cannot start and end at the same hour")

    def covers(self, hour: int) -> bool:
        if self.start < self.end:
            return self.start <= hour < self.end
        return hour >= self.start or hour < self.end


def parse_demand(raw: object) -> dict[int, int]:
    """Turn ``[{"hour": 8, "required": 3}, ...]`` into ``{8: 3, ...}``."""
    demand: dict[int, int] = {}
    for item in _records(raw, "demand"):
        hour = _hour(item.get("hour"), "demand hour")
        required = item.get("required")
        if isinstance(required, bool) or not isinstance(required, int) or required < 0:
            raise ValidationError("required staff must be a whole number of zero or more")
        if hour in demand:
            raise ValidationError(f"hour {hour} appears more than once in demand")
        demand[hour] = required
    if not demand:
        raise ValidationError("demand must contain at least one hour")
    return demand


def parse_shifts(raw: object) -> list[Shift]:
    """Turn ``[{"start": 7, "end": 15}, ...]`` into validated shifts."""
    return [Shift(start=item.get("start"), end=item.get("end")) for item in _records(raw, "shifts")]


def calculate_coverage(demand: Mapping[int, int], shifts: list[Shift]) -> dict[str, object]:
    """Report scheduled staff against demand for each hour, plus an overall coverage ratio.

    The ratio only counts staff who meet demand, so overstaffing one hour cannot hide
    understaffing in another.
    """
    hours = []
    for hour in sorted(demand):
        required = demand[hour]
        scheduled = sum(1 for shift in shifts if shift.covers(hour))
        gap = scheduled - required
        hours.append({"hour": hour, "required": required, "scheduled": scheduled, "gap": gap})
    total_required = sum(demand.values())
    covered = sum(min(entry["scheduled"], entry["required"]) for entry in hours)
    return {
        "hours": hours,
        "understaffed_hours": [entry["hour"] for entry in hours if entry["gap"] < 0],
        "overstaffed_hours": [entry["hour"] for entry in hours if entry["gap"] > 0],
        "coverage_ratio": round(covered / total_required, 3) if total_required else 1.0,
    }
