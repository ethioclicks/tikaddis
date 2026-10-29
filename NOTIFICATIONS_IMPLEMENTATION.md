# Live notification inbox

Implemented for the existing Tikaddis promotion/channel/account workflows.
Backend commit: `508fe51`. Mobile implementation commit: `155dc98`.
The event-driven scaling upgrade is described in
[NOTIFICATION_SCALING_RESULTS.md](NOTIFICATION_SCALING_RESULTS.md), including
broker setup, the transitional mode and measured load-test results. The commit
references above identify the original inbox implementation.
Validated with 38 backend tests, 31 mobile tests, clean Dart analysis and a
successful Android debug APK build.
Background phone push is not configured: the project has no Firebase setup yet.

## User experience

- Persistent inbox for business users, creators and admins; no demonstration messages.
- Actual unread counts on dashboard/admin notification bells, plus profile access.
- All, Unread and Archived filters, with paginated older messages.
- Mark an item read/unread, mark all active inbox items read, archive and restore.
- Notification preferences for live in-app alerts and promotion/channel/account categories.
  Muting an alert does not discard its inbox record.
- Promotion notifications open the matching request; channel notifications open the
  listing or channel list. Admin notifications open the appropriate management list.
- Foreground live alerts reuse AppToast. Historical messages are not replayed as a
  burst of toasts on sign-in. Notifications are retained for return visits.
- Resume reconnects and refreshes; backgrounding stops the stream/retry timers.
  Signing out or changing accounts disposes the previous user's inbox and connection.

## Events currently connected

| Event | Recipients |
| --- | --- |
| Registration | New user's welcome inbox message |
| Creator application | Applicant and active admins |
| Creator approval/access change | Affected account |
| Channel submitted/updated/removed | Owner and active admins |
| Channel approved/disapproved | Owner; repeated unchanged approval creates no new alert |
| Promotion requested | Requester acknowledgement and active admins under the current workflow |
| Admin promotion review approved | Requester and channel owner; describes awaiting creator acceptance |
| Admin promotion review rejected | Requester |
| Creator accepts/declines | Requester and active admins |
| Promotion marked running/fulfilled | Requester and creator, described as an admin's status decision |
| Initial request withdrawn | Active admins |

Recipients who are deleted, disabled or locked are skipped. Messages do not include
passwords, tokens, uploaded artwork or the full private brief.

The current deployed workflow still requires admin review before the creator sees
a request. This module follows that existing visibility rule; it does not implement
the planned direct-booking/content-approval workflow. Future draft, comment,
revision, publication and delivery events should call the same notification service
from their own authorized business transactions once those features exist.

## Backend and APIs

All endpoints use bearer authentication under `/account/notifications`. The server
derives the inbox owner from the authenticated principal. Client-supplied recipient
IDs do not select an inbox. An admin's inbox endpoint returns that admin's own
notifications; it is not a way to read every member's messages.

| Endpoint | Purpose |
| --- | --- |
| `GET /account/notifications?filter=ALL&page=0&size=20` | Paginated active inbox; filters also `UNREAD` and `ARCHIVED`; size capped at 50 |
| `GET /account/notifications/snapshot` | Own durable revision, unread count and preferences |
| `GET /account/notifications/stream` | Authenticated SSE invalidation/resync stream |
| `PUT /account/notifications/{id}/read` | JSON `{ "value": true }` or false |
| `POST /account/notifications/read-all` | Mark only the owner's unarchived unread items read |
| `PUT /account/notifications/{id}/archive` | JSON `{ "value": true }` or false to restore |
| `PUT /account/notifications/preferences` | Complete boolean `liveAlerts`, `promotionAlerts`, `channelAlerts`, `accountAlerts` object |

Another user's notification cannot be changed, even by an admin using these
owner endpoints. Foreign/nonexistent IDs return 404. Notification DTOs omit the
recipient selector and internal event key. Read/archive changes are idempotent.

The notification row and durable change revision are written in the same
transaction as the originating business change. Rollbacks do not leave false
success notifications. Event keys provide duplicate suppression when the same
business event is delivered again. Ordinary business transitions continue to
validate their current state before emitting events.

New tables are `APP_NOTIFICATION`, `NOTIFICATION_CHANGE`, and
`NOTIFICATION_PREFERENCES`. They are additive; existing records and the production
destructive-schema guard remain in place. No old status enum values are reordered.

## Live delivery

The SSE endpoint sends only an owner-scoped snapshot, not arbitrary notification
payloads or tokens. The app reloads the durable REST inbox on a signal. Standard
authorization headers are used; credentials are not placed in the stream URL.

The scaling upgrade removes connection-specific database polling. It stores a
transactional outbox and distributes committed invalidations through Redis/Valkey
when configured. Heartbeats perform no database reads or inbox fetches. Broker
subscription recovery and client reconnect trigger resynchronization from the
durable inbox. Broker-free transitional mode uses a 30-second resync signal until
shared infrastructure is enabled; this mode is reported explicitly.

Streams have a two-minute lifetime, unchanged per-user/per-instance limits,
bounded writers, cleanup hooks, no-store headers and proxy-buffering suppression.
The server checks token expiry in memory and sends revocation events for account
lock/disable/deletion. Every inbox API request remains independently authenticated.
The app reconnects with bounded backoff and uses its foreground 30-second timer
only when streaming is unhealthy or a refresh has failed.

The shared-broker implementation passed a local two-instance, 400-connection
HTTP load/recovery test without increasing connection limits. Local measurements
do not establish production capacity. Live propagation is best effort, with the
durable inbox, outbox retries and resync providing recovery.

## Firebase follow-up

OS push alerts while the app is closed require a Firebase project/configuration,
Android registration for `com.ethioclicks.tikaddis`, secure server credentials,
device-token registration/revocation, delivery retries and permission handling.
None of these credentials are invented or embedded in this implementation.

Connect push delivery to the existing durable event/inbox model when configured.
The inbox must remain available if permission is denied or a push cannot be
delivered. Opening a push should resolve the same safe resource targets and
server-side authorization as an inbox notification.

## Retention and privacy

Archiving hides a notification from the active inbox; it does not erase it.
No automatic retention period is claimed. Account soft deletion disables access
and retains notification/preferences records alongside existing retained data.
The operator must define any future permanent-erasure and retention policy.

## Validation

Backend tests cover authenticated/owner-only access, no broad admin inbox access,
read/unread/archive/restore, scoped read-all, preferences, validation, event-key
deduplication, transaction rollback, owner-only SSE snapshots and notifications
from real promotion transitions. Mobile tests cover SSE frame/UTF-8 parsing,
navigation, saved management actions, failed mutations, reconnect/pause,
account switching, alert preferences, duplicate resync suppression and real UI
empty states. The updated APK and hosted REST/SSE behavior are checked separately
before handover.
