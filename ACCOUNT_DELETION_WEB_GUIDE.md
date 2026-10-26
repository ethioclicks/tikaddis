# Tikaddis account deletion — Website and API guide

## What this feature does

Tikaddis supports **authenticated soft deletion of the account owner's account**.
The account is deactivated, its channel listings are hidden, and sign-in is
blocked. Database records are retained. This is not permanent erasure of personal
information.

The API selects the account from the authenticated login token. There is no
endpoint for a user to delete someone else by supplying an ID or phone number.
Even an administrator using this endpoint can delete only their own account.

## API address

```text
DELETE https://tikaddis-app-w6zbh.ondigitalocean.app/account/me
```

Required headers:

```http
Authorization: Bearer <the signed-in user's JWT>
Content-Type: application/json
```

Required JSON body:

```json
{
  "password": "THE_ACCOUNT_OWNERS_CURRENT_PASSWORD",
  "confirmDeletion": true
}
```

Do not send a user ID, `pid`, phone number, or email to choose the account being
deleted. Those values cannot select another account. The bearer token identifies
the account, and its current password must match that account.

Never put the password or token in a URL, query string, analytics event, log,
support message, or public website source. Do not embed an administrator token or
administrator password in the website.

## Sign-in API for the website

```text
POST https://tikaddis-app-w6zbh.ondigitalocean.app/public/authenticate
```

```json
{
  "userName": "0912345678",
  "password": "THE_ACCOUNT_OWNERS_PASSWORD"
}
```

`userName` is normally the registered Ethiopian phone number, stored as ten
digits beginning with `0`. Normalize `+251912345678` to `0912345678`. Administrator
accounts may have an assigned username instead.

On successful sign-in, the JSON response includes `token`. Use that token in the
`Authorization` header of the DELETE request. Never use an ID returned by login
to build a deletion URL.

Keep the token and password in memory only for this flow. Clear them after
completion or when the user leaves the page. The backend's current token lifetime
is five hours; an expired token requires a new sign-in.

## Suggested website page

Publish an HTTPS page such as:

```text
https://YOUR-WEBSITE-DOMAIN/delete-account
```

Replace the domain with the real published domain. This webpage is distinct from
the API endpoint: visitors need a readable page and a working request form.

Suggested title:

> Tikaddis — Delete your account

Suggested explanation, matching the implemented behavior:

> This action deactivates your Tikaddis account and hides your channel listings.
> You will be signed out and will no longer be able to sign in. Your stored
> account and activity records will be retained. This action does not permanently
> erase your personal information.

Suggested flow:

1. Show the Tikaddis name, explanation, privacy-policy link, and actual support
   contact details.
2. Ask the user to sign in with their registered phone number and password.
3. Show a confirmation screen explaining the retained records and loss of access.
4. Ask for the current password and an unchecked confirmation checkbox. A freshly
   entered login password can be reused in memory if both steps are part of one
   explicit, immediate confirmation flow.
5. Offer **Cancel** and **Delete account** buttons. Make the destructive action
   visually distinct and prevent repeated clicks while a request is pending.
6. Send the authenticated DELETE request after explicit confirmation.
7. Show success only after a successful server response. Clear local credentials
   and tokens, and return the user to a signed-out state.

Do not issue the DELETE request when the page loads, when a link is opened, or
when a checkbox is merely selected.

## JavaScript integration example

```javascript
const API_BASE = "https://tikaddis-app-w6zbh.ondigitalocean.app";

export async function signIn(userName, password) {
  const response = await fetch(`${API_BASE}/public/authenticate`, {
    method: "POST",
    credentials: "omit",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ userName, password }),
  });

  if (!response.ok) {
    throw new Error("Sign-in failed. Check your account details.");
  }

  const result = await response.json();
  if (!result.token) throw new Error("Sign-in did not return a token.");
  return result.token;
}

// Call only after the user explicitly confirms the deletion action.
export async function deleteMyAccount(token, currentPassword) {
  const response = await fetch(`${API_BASE}/account/me`, {
    method: "DELETE",
    credentials: "omit",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      password: currentPassword,
      confirmDeletion: true,
    }),
  });

  if (response.status === 401) {
    throw new Error("Please sign in again before deleting your account.");
  }
  if (response.status === 403) {
    throw new Error("Your current password is incorrect.");
  }
  if (!response.ok) {
    throw new Error("The request could not be completed. Please try again.");
  }

  return response.json();
}
```

Connect these functions to real form state and error messages. Clear the password
inputs and in-memory token after success. Cross-origin requests use bearer tokens
without cookies; a CORS preflight is supported by the backend. Use HTTPS in production.

## API responses

Successful soft deletion returns HTTP **200**:

```json
{
  "status": "SOFT_DELETED",
  "dataPermanentlyDeleted": false,
  "message": "Your account has been deactivated and your channel listings hidden. Records are retained."
}
```

| HTTP status | Meaning | Website action |
| --- | --- | --- |
| 200 | Soft deletion completed | Show success and clear the session |
| 400 | Missing/invalid password field or confirmation not true | Ask the user to correct and confirm the form |
| 401 | Missing, invalid, or expired token; or account no longer available | Return to sign-in; do not claim a new deletion succeeded |
| 403 | The authenticated account's current password did not match | Allow the owner to correct the password |
| 5xx / network error | The outcome was not confirmed to the website | Show an error; do not display success |

Repeated deletion with the old token is rejected because that account is no
longer allowed to authenticate. A lost connection after submitting a request can
leave the result uncertain; do not assume a failed network response means the
account remained active.

## Data and access behavior

| Item | Effect |
| --- | --- |
| User record | Retained with `deleted=true` and a deletion timestamp |
| Account enabled/locked state | Disabled and locked |
| Existing tokens | Rejected on subsequent authenticated requests |
| New sign-in attempts | Rejected |
| Password recovery | Cannot reactivate a deleted account |
| Owned creator channels | Soft deleted and disapproved; excluded from discovery and direct channel detail access |
| Other users and their channels | Unchanged |
| Profile/contact details and password hash | Retained in the database |
| Promotion requests and historical campaign records | Retained; the endpoint does not cancel or erase campaigns |
| Phone-number reuse | No automatic release or re-registration process is provided |
| Automatic permanent purge | Not implemented by this endpoint |

There is no self-service restore action. Generic enable/unlock changes do not
remove the deletion flag.

## Mobile app entry point

The updated app provides **Profile → Delete account**, using the same API. It
asks for the current password and acknowledgement of retained records, then signs
the user out after success.

## Google Play submission limitation

Google Play requires an account-deletion path and deletion of associated user
data, with legitimate retention exceptions explained to users. Retaining every
record through soft deletion alone should not be presented as permanent account
and data erasure or assumed to meet that requirement.

Before using this page as the Play Console **Delete account URL**, define and
implement the actual process for erasing or irreversibly anonymizing personal
data, and document any justified retained data and retention periods. Do not
promise a deletion deadline until that process exists. The current API performs
immediate account deactivation and retains records.

Official reference:
[Google Play account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en).
