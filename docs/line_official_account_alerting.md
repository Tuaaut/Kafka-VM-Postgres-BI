# LINE Official Account Alerting — Retired

This document is retained as a compact history record. LINE notification delivery for this project was decommissioned on 2026-11-08 because the channel was no longer needed.

## Previous Verification

The `Kafka Alert Bot` Official Account had Messaging API enabled. Before retirement, a direct LINE API check and a Grafana-to-bridge check returned HTTP 200. These are historical results; no test or broadcast was sent during decommissioning.

## Current State

1. The repository no longer provisions the LINE webhook contact point or critical LINE notification route.
2. Docker Compose no longer defines the LINE alert bridge.
3. The old bridge sender defaults to disabled and requires explicit `LINE_ALERTS_ENABLED=true` to send.
4. Gmail remains the active notification channel.
5. The GCP VM is stopped. Its startup-script metadata applies the same LINE removal after the existing Git pull and before Compose starts; confirm the result after the next scheduled boot.

The LINE token was not displayed, rotated, or revoked. Legacy setup and test commands are retired and must not be used for this project.

See [current project status](current_status.md#line-alert-channel-decommission--2026-11-08) and [alerting and monitoring](alerting_monitoring.md).
