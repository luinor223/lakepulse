## Summary

Please describe the purpose of this PR. What feature, improvement, or fix does it introduce?

---

## Changes

List all major changes in this PR:

- Added ...
- Modified ...
- Removed ...

---

## Data Pipeline Impact

- [ ] Ingestion (batch or streaming)
- [ ] Transformation (Bronze/Silver/Gold)
- [ ] Data Quality / Validation
- [ ] Metadata or schema change
- [ ] Trino / Serving Layer
- [ ] Monitoring / Alerting
- [ ] CI/CD

---

## Checklist

### Code Quality
- [ ] Code runs locally without errors
- [ ] Code follows naming, style, and folder conventions
- [ ] Logging and error handling are included
- [ ] Secrets/configs are handled via `.env` or vault

### Data Validation

(Optional -- remove this section if not needed)

- [ ] Great Expectations validation updated or run
- [ ] CDC logic tested (if applicable)
- [ ] Output Delta tables validated

### CI/CD
- [ ] GitHub Actions passed
- [ ] Docker build successful (if changed)
- [ ] Airflow DAG tested locally (if added/modified)

---

## How to Test

Explain how reviewers can test this PR locally:

```bash
# Example commands
docker-compose up -d
spark-submit spark_jobs/bronze/ingest_orders.py
