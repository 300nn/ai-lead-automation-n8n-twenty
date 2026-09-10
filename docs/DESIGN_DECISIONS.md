# Design Decisions

## 1. Idempotency before external side effects

Retries and duplicate webhook deliveries are normal integration behavior. A stable `request_id` is therefore resolved before CRM or email work. Completed requests return `already_completed`; recent processing requests return `already_processing`.

## 2. Separate processing state from audit history

The state table answers "what is the current status of this request?" while the audit table answers "what happened during its lifecycle?". Mixing those concerns would make both duplicate detection and troubleshooting harder.

## 3. Person upsert by email

Twenty is searched before create. Existing People are updated instead of creating duplicate CRM records. Regression coverage explicitly verifies that the same email reuses the same Person ID.

## 4. Opportunity only for HOT leads

WARM and COLD leads stay in People without polluting the sales pipeline. HOT leads get a linked Opportunity with amount, source, service, score/category and AI summary context.

## 5. Mock AI as the default local mode

The purpose of the local demo is to exercise the workflow, CRM and SMTP deterministically without requiring paid inference. `mockAI=true` keeps the demo reproducible. The real OpenAI path remains implemented behind the same qualification contract.

## 6. Deterministic fallback around AI

The automation does not make downstream CRM behavior depend on perfect model availability. If the OpenAI branch fails or violates the expected structured contract, parsing falls back to deterministic qualification and records provider/fallback metadata.

## 7. Real local integrations where they matter

Twenty and Mailpit are not mocked in the validated setup. This tests network connectivity, auth, JSON shapes, CRM record IDs, relations, SMTP delivery and booking stage updates end to end.

## 8. Retry policy at unstable boundaries

CRM and OpenAI HTTP requests use retries; SMTP delivery also retries. Business validation and idempotency logic do not retry because they are deterministic local operations.

## 9. Explicit production-hardening boundary

The demo webhook is intentionally easy to use locally. An internet-facing version should add auth/signature validation, HTTPS, rate limiting, secret rotation, persistence/backup, monitoring and production email infrastructure before exposure.
