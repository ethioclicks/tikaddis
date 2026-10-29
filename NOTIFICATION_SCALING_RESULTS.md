# Event-driven notification delivery: implementation and results

October 29, 2026. The raw local results are in
[NOTIFICATION_LOAD_TEST_RESULTS.json](NOTIFICATION_LOAD_TEST_RESULTS.json).

## Implemented

- SSE notification connections no longer schedule database queries. An in-memory
  hub sends event invalidations and heartbeats through bounded writer queues.
- Initial connection authentication and snapshot reads remain short transactions.
  SSE is excluded from JPA Open EntityManager in View, avoiding a JDBC connection
  being retained for the life of a stream. Other existing screens retain their
  lazy-serialization behavior.
- A transactional outbox is saved with inbox revisions. Workers claim records
  through atomic expiring leases, acknowledge successful broker publication and
  retry failures with bounded backoff. Uncommitted low IDs are not skipped.
- Redis/Valkey broadcasts invalidations across instances. Local after-commit
  delivery is immediate; repeated event IDs are suppressed. Subscription recovery
  resynchronizes connected clients from the durable inbox.
- Account lock, disable and deletion produce stream-revocation signals. Token
  expiry is checked in memory, and every inbox request remains authenticated.
- The mobile app coalesces bursts over a 200 ms window. Heartbeats update stream
  health without fetching the inbox. Its 30-second timer performs recovery only
  for an unhealthy stream or failed refresh.
- New admin-only `/admin/notifications/operations` reports connection counts,
  queue activity, operating mode, broker state and outbox backlog without secrets.

## Measured local test

Two actual embedded HTTP backend instances shared an isolated H2 database and a
real Redis 7.4 container. The test used authenticated HTTP SSE connections, not
mock emitters. Production services and customer accounts were not load-tested.

| Check | Observed result |
| --- | --- |
| Concurrent connections | 400 across two instances |
| Limit per instance | 200, unchanged |
| Setup time for the main connection batch | 18.863 seconds |
| SQL statements in a three-second idle sample without streams | 12 |
| SQL statements in a three-second idle sample with 400 streams | 12 |
| Burst | 100 persisted notifications |
| Remote connection receipts measured | 199 |
| Burst-start to remote invalidation p95 | 1.492 seconds |
| Subscriber disconnect/reconnect | Full inbox resync passed |
| Broker paused/unpaused | Backlog retained, retried and recovered |
| Recipient isolation | Passed |
| Connection-limit behavior | HTTP 429 as configured |

The remaining idle SQL is the shared outbox worker, approximately two checks per
second per instance. It does not grow with the number of open SSE connections.
The p95 measures receipt of invalidations from the start of the burst; it is not
per-notification end-user rendering latency. Invalidations are intentionally
coalesced, while all individual notifications remain in the inbox.

These measurements cover this local configuration. They do not establish a
production user-capacity guarantee, multi-region latency, unlimited throughput,
or a highly available broker SLA. Connection limits remain unchanged. Repeat on
staging with production-like MySQL, resources, TLS and network topology before
raising them.

## Deployment modes

Without broker settings the new code uses `LOCAL_SINGLE_INSTANCE`: event-driven
local delivery plus durable outbox retry. This mode is explicit and is not
advertised as multi-instance Redis fan-out.
During this transitional mode a 30-second SSE resync signal preserves eventual
inbox recovery if multiple legacy instances are running. It has no server-side
per-connection SQL task, but clients fetch their inbox on that resync. Redis mode
disables the periodic resync and uses broker events plus non-fetching heartbeats.

For shared delivery configure the backend service with:

```text
NOTIFICATIONS_BROKER_ENABLED=true
SPRING_DATA_REDIS_URL=<secret rediss:// URL>
SPRING_DATA_REDIS_TIMEOUT=2s
SPRING_DATA_REDIS_CONNECT_TIMEOUT=2s
SPRING_DATA_REDIS_REPOSITORIES_ENABLED=false
NOTIFICATIONS_BROKER_TOPIC=tikaddis:prod:notifications:v1
```

Keep TLS verification enabled. No broker credentials belong in the Flutter app.
Broker outages can delay remote updates; persisted inboxes and outbox retries
provide recovery. Monitor pending backlog, retry counts, writer queues, broker
connectivity and database growth. Published outbox/revision history currently
has no automatic purge; define a maintenance retention window as traffic grows.

## New production broker

The repository includes `ops/notification_broker.py` and the manually dispatched
**Notification broker infrastructure** workflow. `plan` reads only the relevant
app/resource metadata. It never prints connection credentials. `apply` requires
explicit approval of the proposed $15/month single-node Valkey resource, creates
it only if absent, trusts the existing app, and configures its secret TLS URL.
Existing unrelated environment settings and connection limits are preserved.

DigitalOcean documents a single-node 1 GiB starting price of $15/month. It is not
highly available. Their HA configuration starts with a $30 primary and at least
one matching $30 standby. [Official pricing](https://docs.digitalocean.com/products/databases/valkey/details/pricing/)

No billed broker should be created before approval of the concrete plan. The
existing CI DigitalOcean token must have app/database read/write permissions;
registry-only access is insufficient. If provisioning succeeds but configuration
fails, rerunning apply reuses the named broker instead of creating another.

## Reproduce

Start the dedicated local fixture:

```powershell
docker run -d --name tikaddis-notification-scale-redis -p 127.0.0.1:16379:6379 redis:7.4-alpine
$env:NOTIFICATION_LOAD_TEST = 'true'
mvn -B -Dtest=NotificationBrokerLoadTest test
```

Run the command from the backend repository. The test pauses only a container
whose name starts with `tikaddis-notification-scale-` and unpauses it in cleanup.
Its report is written to `target/notification-load-report.json`.

The production CI/CD workflow runs ordinary regression tests plus the isolated
two-instance broker/load/recovery test before publishing the Docker image and
preserves its JSON report as an artifact. Firebase phone push and the planned
content-approval workflow are separate features.
