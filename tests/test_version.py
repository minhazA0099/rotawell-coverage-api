from app import create_app


def test_version_reports_build_and_release_metadata(monkeypatch):
    monkeypatch.setenv("APP_VERSION", "1.0.0")
    monkeypatch.setenv("GIT_SHA", "abc123")
    monkeypatch.setenv("BUILD_DATE", "2026-09-15T12:00:00Z")

    response = create_app().test_client().get("/version")

    assert response.status_code == 200
    assert response.get_json() == {
        "version": "1.0.0",
        "commit": "abc123",
        "built": "2026-09-15T12:00:00Z",
    }


def test_version_defaults_make_untraceable_builds_obvious(monkeypatch):
    for name in ("APP_VERSION", "GIT_SHA", "BUILD_DATE"):
        monkeypatch.delenv(name, raising=False)

    response = create_app().test_client().get("/version")

    assert response.get_json() == {"version": "unreleased", "commit": "unknown", "built": "unknown"}
