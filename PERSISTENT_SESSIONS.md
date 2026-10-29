# Persistent login and explicit sign-out

The app keeps its signed-in identity and current route across request failures,
access-token expiry, notification reconnects, and app restarts. Network errors,
HTTP 401/403/500 responses and refresh failures do not clear stored login state.
Only an explicit sign-out/sign-in-again action or confirmed account deletion
clears the local session.

## Renewal

The existing five-hour access-token lifetime remains in place. Password login
now also creates a per-device server session. The app stores its opaque renewal
credential in Android Keystore/iOS Keychain through `flutter_secure_storage`.
It never stores the password. Existing access tokens remain in their existing
local preference location; the new long-lived credential does not.

On startup the app renews its session. Before an authenticated request with an
expired access token it renews first, then sends the request once. Concurrent
requests share one renewal. A request that already failed is not automatically
replayed, avoiding duplicate channel updates, submissions or file uploads.

Renewal extends a 90-day inactivity window, so regular use keeps the session
active. The random 256-bit renewal secret stays stable for the device session,
making lost responses and concurrent renewal recoverable. The server stores
only its SHA-256 hash, with an owner, expiry, revocation flag and fingerprint of
the encoded password. Access JWTs identify their server session, allowing both
access and renewal to be rejected after explicit server-side revocation.

New endpoints:

| Endpoint | Authorization | Purpose |
| --- | --- | --- |
| `POST /account/session` | Valid existing bearer access token | Upgrade a legacy login to a renewable session |
| `POST /public/session/refresh` | Opaque `refreshToken` in JSON body | Renew the credential's own account; no user selector accepted |
| `POST /public/session/logout` | Opaque `refreshToken` in JSON body | Idempotently revoke that device session |

Login and renewal responses use `Cache-Control: no-store`. No renewal credential
belongs in logs, URLs, analytics or the notification broker. The additive
`MOBILE_SESSION` table preserves existing data. No connection limits or
infrastructure services change.

## Verification without losing the screen

If the credential is invalid, inactive for 90 days, or absent from an already
expired legacy login, the app shows a **Verify** banner. It keeps the current
route and form. Password verification must return the same account ID; successful
verification replaces credentials without navigating away. The user can defer
verification and retry later. Protected actions still require valid server
authorization.

Locked, disabled, deleted and password-reset accounts cannot renew or use their
session-bound access tokens. These security decisions prompt verification rather
than silently navigating to the login screen. A legacy login can be upgraded
silently only while its original access token is still valid.

Sign-out changes local UI immediately and clears local credentials even offline.
Online sign-out also revokes the device session on the server. If the network is
unavailable, server revocation cannot be guaranteed; local credentials are still
removed. In-flight renewal cannot restore credentials after sign-out. Android
automatic app backup is disabled to avoid restoring encrypted credentials without
their device key.

## Verification coverage

- Backend tests: password login, legacy upgrade, hashed storage, owner identity,
  invalid credentials, inactive sessions, password changes, locked accounts,
  device-specific logout, rejection of revoked access tokens, and channel update
  followed by detail/list/notification requests using the same session.
- Mobile tests: expired-token renewal before a mutation, concurrent renewal,
  401/403/server errors, retained startup identity, logout versus in-flight renewal,
  and preservation of an unsaved form through the verification dialog.
- Existing channel, promotion, notification, account deletion and startup tests
  remain part of the regression suites. CI runs backend regressions plus the
  existing two-instance notification load/recovery test before publication.

Verification preserves an in-memory form while the app remains running; it does
not add draft persistence across process termination or reinstall.
