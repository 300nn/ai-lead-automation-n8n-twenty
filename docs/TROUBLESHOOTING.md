# Troubleshooting

## Webhook returns 404 after import

Confirm the workflow is published in the n8n UI. Do not assume an imported draft has a registered production webhook.

## Twenty request works from the browser but not from n8n

Use the Docker-internal URL (`http://twenty:3000`) from n8n, not `http://localhost:3000`, when services run in separate containers.

## View sorting in Twenty behaves unexpectedly

The automation does not depend on Twenty UI multi-sort order. The validated AI Leads view uses one primary sort (`Lead Score DESC`). Keep CRM display concerns separate from automation correctness.

## Dynamic n8n host port

Use `docker port lead-automatisation 5678/tcp`. The helper scripts already do this.

## AI provider shows fallback

If `mockAI=true`, the expected provider is `mock`. If `mockAI=false`, inspect the OpenAI credential, HTTP response and parser output. A real-AI failure intentionally falls back rather than breaking CRM processing.
