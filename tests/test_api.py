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
