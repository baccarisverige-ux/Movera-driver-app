# Phase 8 — Frontend service adapters and production readiness

Status: integration design pending; no real service adapters or credentials are added by this PR.

Dependencies: authorized staging API contracts, identity provider, non-production test accounts, realtime protocol, test payment environment and service ownership. Never commit tokens or secrets.

| Boundary | Frontend requirements | Staging acceptance |
| --- | --- | --- |
| Authentication/session | Explicit restore/loading/failure states, refresh/expiry, sign-out cleanup, account gate | Expired/revoked sessions cannot perform protected actions |
| Dispatch/trip | Implement `DriverTripGateway`; server status/version, idempotency keys and conflict reconciliation | Repeated/out-of-order actions produce one authoritative transition |
| Realtime/location | Reconnect, stale/duplicate/versioned event handling, lifecycle ownership | No regression or duplicate terminal outcome after reconnect |
| Rider chat/support | Delivery/queued/failed states, message IDs, retry and pagination | Delivery labels reflect server acknowledgement, not local persistence |
| Wallet/payments | Server-authoritative amounts, pending/error states, idempotent operations | Test-environment outcomes and retries reconcile with the server |
| Documents/profile | Validation, upload progress/failure, review status and permissions | Approval comes from the service; local previews remain labelled |

## Implementation order

1. Document provider/API request, response, error and event contracts without guessing endpoints.
2. Add injectable adapters and contract tests; preserve demo adapters for explicit preview mode.
3. Wire a distinct staging composition, test accounts and environment configuration.
4. Execute success, timeout, offline, retry, expiry, conflict and restart journeys.
5. Enable production composition only after adapter and staging evidence exists. Keep `validateDriverComposition(production: true)` fail-closed until then.

Legacy onboarding also requires validated prerequisites, real verification and session integration before its gate is enabled. No preview labels are removed because a button or local save works.

## Exit gate

Approved staging journeys pass with real server outcomes, explicit failure/recovery behavior, correct session ownership and no fabricated service success. Record remaining external blockers by service and owner.
