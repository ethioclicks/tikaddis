# Event-driven notification scaling

Implementation plan — October 29, 2026.

1. Replace each connection's database polling task with a shared local SSE hub.
   Heartbeats and token expiry use memory only. Keep the existing 200 connections
   per instance and five per account until load tests justify another setting.
2. Save an outbox record in the same transaction as each inbox revision. A bounded
   worker claims pending records with expiring leases, retries broker failures,
   and records successful publication. Never advance a global ID cursor past
   uncommitted rows or acknowledge a failed publication.
3. Redis/Valkey distributes invalidations to every instance. Duplicate invalidations
   are harmless. The inbox remains the source of truth. Subscription recovery and
   client reconnect trigger full resynchronization; Pub/Sub is not treated as a
   durable message store.
4. Coalesce bursts and bound background work, queues, connection counts and retry
   rates. Stream payloads contain no message bodies, tokens or recipient selectors.
   Authenticate each connection and every inbox API request.
5. Update mobile live-event handling to coalesce invalidations. Heartbeats do not
   fetch the inbox. Reconnect performs recovery; the 30-second timer becomes an
   offline-stream fallback instead of polling while SSE is healthy.
6. Add regression and integration tests, then run a local two-instance HTTP load
   test with a real broker and isolated test data. Measure idle SQL activity,
   bursts, reconnect recovery, isolation, connection-limit rejection and backlog
   recovery during a broker interruption. Report measured settings and limits;
   do not extrapolate local results to untested production capacity.
7. Provision a new production broker and configure its TLS connection as a secret.
   Prepare the complete deployment first; confirm any new recurring service cost
   before creating a billed resource. Deploy backend/mobile changes through the
   existing repositories and CI/CD, then verify production behavior without
   broadcasting test notifications to customers.

The current broker-free deployment can retain durable delivery through a shared
outbox recovery path while infrastructure is being connected. Its operating mode
must be explicit; broker-free mode is not reported as Redis-enabled multi-instance
delivery. Firebase phone push and the proposed content-approval workflow remain
separate work.
