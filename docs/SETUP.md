# Setup Notes

This repository contains sanitized n8n workflow exports. Credential IDs are placeholders on purpose.

## Required local services

- n8n
- Twenty CRM + PostgreSQL + Redis
- Mailpit
- Docker network connectivity from n8n to Twenty and Mailpit

## n8n credentials

Create these names exactly or re-select equivalent credentials after import:

| Credential | n8n type | Local value |
|---|---|---|
| `Twenty \| n8n Lead Automation` | HTTP Bearer Auth | Twenty API key |
| `Mailpit \| n8n Lead Automation` | SMTP | host `mailpit`, port `1025` |
| `OpenAI \| n8n Lead Automation` | HTTP Header Auth | optional; only for `mockAI=false` |


## Import order

1. Import `00_setup_data_tables.json` and run it once.
2. Import `01` and bind Twenty credentials; run the connectivity check.
3. Import `02`, bind Twenty/Mailpit credentials and leave `mockAI=true` for the free deterministic demo.
4. Import `03` and bind Twenty credentials.
5. Import `04`; select it as the Error Workflow for the relevant production workflows.
6. Import `05` and publish it to serve the demo form.

## Publish

After import, publish production webhooks through the n8n UI. This also makes the demo and booking endpoints available.

## Dynamic n8n port

If Docker maps port 5678 dynamically, run:

```powershell
docker port lead-automatisation 5678/tcp
```

or use `scripts/OPEN_DEMO.cmd`.
