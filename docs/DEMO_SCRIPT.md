# 3–5 Minute Interview Demo

## 0:00–0:30 — Context

"This project automates inbound B2B lead processing. n8n orchestrates validation, idempotency, qualification, Twenty CRM synchronization, follow-up email and booking updates. Twenty and SMTP are real local integrations; AI is mocked by default so the demo is deterministic and has no inference cost."

## 0:30–1:15 — Submit a HOT lead

Open the portfolio demo form and use the HOT preset. Submit it. Point out the returned score/category, `request_id`, Person ID, Opportunity ID and email status.

## 1:15–2:00 — Show CRM effects

Open Twenty → **AI Leads**. Show the new Person with category, score, budget, service, source and company size. Open **AI Sales Pipeline** and show that a HOT lead created a linked Opportunity while WARM/COLD leads do not.

## 2:00–2:30 — Show real email integration

Open Mailpit and show the captured follow-up/sales email. Mention that the SMTP call is real, but Mailpit safely captures it locally.

## 2:30–3:10 — Idempotency

Submit the same request ID again. Show `already_completed` and explain that duplicate webhook delivery does not create another Person/Opportunity or resend side effects.

## 3:10–3:40 — Booking update

Send the Calendly sample for a HOT lead and show the linked Opportunity moving to the meeting stage. Mention the safe no-deal path for WARM/COLD leads.

## 3:40–4:20 — Reliability

Open workflow `02` and briefly point out validation, processing lock, retry settings, AI fallback, state persistence, audit and failure path.

## 4:20–5:00 — Test evidence

Open the Twenty dashboard, then show the regression summary: 11/11 scenarios passed. Finish with the architecture trade-off: deterministic local AI mode for repeatable demos, real AI branch available behind the same contract.
