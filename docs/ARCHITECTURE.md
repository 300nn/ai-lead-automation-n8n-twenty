# Architecture

## Main workflow (`02`)

1. **Webhook intake** — `POST /webhook/portfolio/lead`.
2. **Normalize + Config** — sanitizes strings, validates numeric fields, builds configuration flags, derives `request_id` when it is not supplied.
3. **Validation gate** — malformed requests return HTTP 400 before CRM/email calls.
4. **Idempotency lookup** — reads `lead_automation_state` by `request_id`.
5. **Processing lock** — prevents concurrent reprocessing while a request is in the processing window.
6. **Qualification** — either deterministic mock qualification or OpenAI structured-output qualification.
7. **Fallback parser** — if the real AI branch fails or produces unusable output, a deterministic fallback produces a valid score/category/action contract.
8. **Twenty Person upsert** — searches by primary email, then creates or updates the Person.
9. **HOT gate** — only HOT leads enter Opportunity processing.
10. **Twenty Opportunity** — searches by deterministic deal key and creates it only when missing.
11. **Follow-up** — composes email based on qualification result and sends through SMTP.
12. **Sales notification** — HOT leads additionally trigger a sales notification.
13. **Persistence** — state is marked completed and audit events are appended.
14. **Response** — returns status, qualification, CRM IDs, delivery status, provider and fallback metadata.

## Calendly workflow (`03`)

`invitee.created` is normalized, matched to the lead state by email, checked for an Opportunity, then the Opportunity stage is updated in Twenty. Leads without an Opportunity return a safe success/no-deal response rather than failing.

## State model

`lead_automation_state` stores one logical record per request and supports statuses such as processing/completed/failed. `lead_automation_audit` is append-oriented and records lifecycle events with execution IDs and details.

## External boundaries

- **Twenty CRM** — REST for record create/update, GraphQL for searches/introspection.
- **Mailpit** — local SMTP sink used for end-to-end delivery testing without sending external email.
- **OpenAI** — optional HTTP Responses API branch; disabled in the default local portfolio mode.
- **Calendly** — represented by the booking webhook contract and sample payload.
