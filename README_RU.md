# AI Lead Automation — n8n + Twenty CRM

Production-like автоматизация обработки лидов на **n8n** с **Twenty CRM**, **Mailpit** и опциональной AI-квалификацией через **OpenAI**.

Локальный demo-режим по умолчанию использует `mockAI=true`: CRM и SMTP работают по-настоящему, а AI-квалификация детерминирована и **не требует оплаченного OpenAI API**.

## Сценарий

```text
Demo form / webhook
→ validation
→ idempotency lock
→ HOT / WARM / COLD qualification
→ Twenty Person upsert
→ HOT: Twenty Opportunity
→ follow-up email
→ HOT: sales notification
→ state + audit
→ response

Calendly invitee.created
→ lead lookup
→ linked Opportunity
→ stage update
```

## Что уже проверено

Regression suite прошёл **11/11**: production webhooks, invalid payload, HOT/WARM/COLD, idempotency, Twenty Person upsert, Calendly HOT, безопасный WARM/no-deal сценарий, ignored Calendly event и Mailpit delivery.

## Ключевые инженерные решения

- Валидация до внешних вызовов.
- Идемпотентность через `request_id` и state table.
- Processing lock от параллельной повторной обработки.
- Upsert Person по email.
- Opportunity создаётся только для HOT lead.
- Retry для CRM/SMTP/OpenAI.
- Deterministic fallback для AI.
- Audit table и global error workflow.
- Раздельные флаги `mockAI`, `mockCRM`, `mockEmail`, `mockNotification`.

## Workflows

`00` — Data Tables setup  
`01` — Twenty connectivity check  
`02` — main qualification + CRM automation  
`03` — Calendly booking handler  
`04` — global error handler  
`05` — локальная portfolio demo form

Публичные JSON-экспорты санитизированы: внутри только placeholder ID credentials, секретов нет.

## Локальный режим

```text
mockAI=true
mockCRM=false
mockEmail=false
mockNotification=false
```

Twenty доступен из n8n по `http://twenty:3000`, Mailpit SMTP — `mailpit:1025`. Host-port n8n может быть динамическим; `scripts/OPEN_DEMO.cmd` определяет его через Docker автоматически.

## Быстрая демонстрация

Открой demo form → отправь HOT preset → покажи новый Person в AI Leads → Opportunity в Kanban → письмо в Mailpit → повтори request ID и покажи idempotency → вызови Calendly sample → покажи смену stage → открой dashboard → покажи `11/11 PASS`.

Подробности: [`docs/DEMO_SCRIPT.md`](docs/DEMO_SCRIPT.md), [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), [`docs/DESIGN_DECISIONS.md`](docs/DESIGN_DECISIONS.md).

## Скриншоты

![AI Leads](docs/screenshots/ai-leads.png)

![AI Sales Pipeline](docs/screenshots/sales-pipeline.png)

![Dashboard](docs/screenshots/dashboard.png)

## Для production

Перед публикацией наружу нужны webhook auth/signature validation, HTTPS, rate limiting, production SMTP, monitoring/alerts, секреты вне репозитория и persistent volume для n8n. Текущий вариант специально собран как локальный portfolio project.
