# Regression Result

Validated locally on the Twenty + Mailpit stack.

```text
WEBHOOK REGISTRATION .............. PASS
INVALID PAYLOAD ................... PASS
HOT LEAD .......................... PASS
WARM LEAD ......................... PASS
COLD LEAD ......................... PASS
IDEMPOTENCY ....................... PASS
TWENTY PERSON UPSERT .............. PASS
CALENDLY HOT -> TWENTY STAGE ...... PASS
CALENDLY WARM -> NO DEAL .......... PASS
CALENDLY IGNORED EVENT ............ PASS
MAILPIT DELIVERY .................. PASS

11 PASS / 0 FAIL / 0 SKIP / 11 TOTAL
```

The suite uses real Twenty CRM and real local SMTP delivery to Mailpit while keeping AI inference mocked for deterministic, cost-free testing.
