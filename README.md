# rotawell-coverage-api

Staffing coverage API for the Rotawell scheduling platform: compares scheduled shifts with hourly
staffing demand and reports the gaps.

## Run locally

```bash
python3.12 -m venv .venv && . .venv/bin/activate
pip install --require-hashes -r requirements.txt
pip install --require-hashes -r requirements-dev.txt
pytest
flask --app "app:create_app()" run
```
