# Phase 10: Alerting (Implementation)

This file documents what was added for Phase 10 (basic alerting).

What's included
- Prometheus: now loads `alert_rules.yml` via `prometheus-config` ConfigMap
  - Rules added:
    - `FastAPIDown`: Fires when the FastAPI job's `up` == 0 for 2m
    - `PrometheusDown`: Fires when Prometheus' `up` == 0 for 1m
    - `PrometheusHighMemory`: Prometheus memory > 200MB for 5m
- Alertmanager: added Helm templates for:
  - `ConfigMap` (`alertmanager.yml`) with a default route/receiver
  - `Deployment` and `Service` (ClusterIP)
- Chart values: `alertmanager` block added to `values.yaml` to configure image, service, and Slack integration

How to enable Slack notifications (example)
1. Provide a Slack webhook URL. Avoid storing it plaintext in `values.yaml` for production.
   Example:
     helm install wiki ./wiki-chart --set alertmanager.config.slack_api_url="https://hooks.slack.com/services/TOKEN" \
       --set alertmanager.config.slack_channel="#alerts"
2. Alternatively, patch the `alertmanager-config` ConfigMap with your `alertmanager.yml` including desired receivers.

Notes & Next steps
- Alerts are basic examples; expand to include application-specific error rates or SLO-based alerts.
- Consider securing Alertmanager via RBAC and using Secrets for sensitive data.
- Optionally integrate Grafana for alert notifications or configure PagerDuty/Email receivers.

Enjoy alerting! ✅
