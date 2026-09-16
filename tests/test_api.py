def test_coverage_endpoint_returns_hourly_gaps(client):
    response = client.post(
        "/api/v1/coverage",
        json={
            "demand": [{"hour": 8, "required": 2}, {"hour": 9, "required": 2}],
            "shifts": [{"start": 8, "end": 10}],
        },
    )

    assert response.status_code == 200
    body = response.get_json()
    assert body["understaffed_hours"] == [8, 9]
    assert body["coverage_ratio"] == 0.5


def test_coverage_endpoint_treats_missing_shifts_as_nobody_scheduled(client):
    response = client.post("/api/v1/coverage", json={"demand": [{"hour": 8, "required": 1}]})

    assert response.status_code == 200
    assert response.get_json()["coverage_ratio"] == 0.0


def test_coverage_endpoint_rejects_non_json_body(client):
    response = client.post("/api/v1/coverage", data="not json", content_type="text/plain")

    assert response.status_code == 400
    assert response.get_json() == {"error": "request body must be a JSON object"}


def test_coverage_endpoint_explains_invalid_demand(client):
    response = client.post("/api/v1/coverage", json={"demand": [{"hour": 25, "required": 1}]})

    assert response.status_code == 400
    assert "hour" in response.get_json()["error"]


def test_forecast_endpoint_returns_forecast_and_backtest(client):
    week = [100, 120, 130, 125, 180, 240, 210]

    response = client.post("/api/v1/forecast", json={"history": week * 2, "horizon": 3})

    assert response.status_code == 200
    body = response.get_json()
    assert body["forecast"] == [100.0, 120.0, 130.0]
    assert body["backtest_mape_percent"] == 0.0


def test_forecast_endpoint_skips_backtest_when_history_is_short(client):
    response = client.post("/api/v1/forecast", json={"history": [10] * 7})

    assert response.status_code == 200
    assert len(response.get_json()["forecast"]) == 7
    assert response.get_json()["backtest_mape_percent"] is None


def test_forecast_endpoint_rejects_bad_horizon(client):
    response = client.post("/api/v1/forecast", json={"history": [10] * 7, "horizon": 0})

    assert response.status_code == 400
