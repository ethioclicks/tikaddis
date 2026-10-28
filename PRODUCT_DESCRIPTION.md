# Tikaddis — Product Description

## Overview

Tikaddis is a mobile platform that connects businesses with social media creators
for promotional campaigns. Businesses discover creator channels, compare audience
information and promotion prices, and submit promotion requests. Creators list
their channels, provide promotion pricing, and manage requests. Administrators
review creator applications, channels, and promotion activity.

The app is designed primarily for the Ethiopian market, with Ethiopian phone
number support and promotion prices displayed in Ethiopian birr (ETB).

| Item | Details |
| --- | --- |
| Product name | Tikaddis |
| Android package name | `com.ethioclicks.tikaddis` |
| Product type | Creator discovery and promotion management platform |
| Main users | Businesses, social media creators, and administrators |
| Initial social platforms | Telegram, YouTube, TikTok, Facebook, and Instagram |
| Additional platforms | Administrators can configure additional platforms |

## Website-ready description

Tikaddis helps businesses find social media creators and manage promotional
collaborations in one place. Businesses can browse approved creator channels,
review audience information and pricing, and request promotions. Creators can
showcase their channels and manage incoming requests, while administrators review
applications and oversee platform activity.

## How the product works

1. A user creates an account and signs in with a phone number and password.
2. Businesses browse approved creator channels and review channel descriptions,
   audience size, view ranges, and promotion prices.
3. Users who want to offer promotions apply to become creators.
4. Approved creators add channels with a platform, category, title, description,
   channel URL, audience information, and pricing.
5. Businesses submit promotion requests with promotional content and requested dates.
6. Creators and administrators review requests. The system tracks approval,
   rejection, cancellation, running, and fulfillment states.

Administrator accounts use the same authentication system and can sign in with
their assigned username. Their permissions provide access to the admin area.

## Main features

### Business features

- Browse and search approved creator channels.
- Review channel information, audience statistics, and promotion pricing.
- Submit promotional text, an optional promotional image URL, and requested dates.
- Track promotion requests and their status.
- View account information.
- Deactivate their own account through a password-confirmed soft-deletion flow.

### Creator features

- Apply to become a creator.
- Create and edit channel listings.
- Select administrator-managed platforms and categories.
- Provide audience counts, estimated view ranges, and pricing options.
- Approve or reject incoming promotion requests.
- Remove channel listings through the channel management flow.

### Administrator features

- Review creator applications and channel listings.
- Approve or disapprove channels and review promotions.
- View users and manage relevant account permissions and approvals.
- Create, edit, and manage channel categories and social platforms.
- Set the display order of selection options.

## Information handled by the system

The following inventory describes fields and behavior identified in the current
application. It is background for preparing the privacy policy, rather than a
statement of legal terms or a complete audit of deployed infrastructure.

| Information | Examples | Product purpose |
| --- | --- | --- |
| Account information | First name, last name, phone number, optional email address | Registration, identification, and account management |
| Address information | User-entered city and street | Account profile information |
| Authentication information | Password credentials, authentication tokens, and account roles | Sign-in and access control |
| Account recovery information | Phone number, email delivery information, and one-time verification codes | Password recovery |
| Creator channel information | Channel title, description, social platform, category, channel URL, and image URL | Creator listings and discovery |
| Audience information | Audience count and view ranges | Help businesses evaluate channels |
| Pricing information | Promotion costs, pricing types, and remarks | Describe promotion offers |
| Promotion information | Promotional text, image URL, requested dates, status, and feedback | Process and manage promotion requests |
| Local app preferences | Saved session token, profile identifiers, roles, and onboarding flag | Restore sessions and remember app state |

Passwords are hashed by the backend. Authentication tokens and selected account
details are stored locally by the mobile app to maintain the signed-in session.
Password recovery uses an email-based verification-code flow associated with the
provided phone number.

Creator listing information is intended to be shown to other authorized users
browsing channels. The policy should explain the distinction between listing
information, private account details, and information shared for a promotion.

## Privacy-policy drafting context

- The mobile app communicates with a hosted backend over HTTPS. The current
  backend is hosted on DigitalOcean.
- The reviewed Android main manifest requests internet access. City and street
  are entered by the user; those fields do not establish GPS location collection.
- Campaign requests can include uploaded JPG/PNG artwork and PDF briefs, plus
  campaign objectives, target audience, deliverables, call to action and a proposed
  budget. Files are stored by the backend. Businesses and admins can access them;
  the channel owner gains access after admin approval. Soft deletion retains them.
- Channel and promotional images can be represented by URLs. Confirm the actual
  image hosting providers and whether images load directly from third-party servers.
- The reviewed Flutter dependencies do not include an advertising or analytics SDK.
  Confirm any backend, hosting, monitoring, or website analytics separately.
- Notification records and alert preferences are stored by the backend. Live
  in-app updates use an authenticated connection; closed-app phone push is not
  configured. Archiving and account soft deletion retain these records.
- The product stores promotion prices. The reviewed mobile implementation does
  not establish an integrated payment-processing flow; do not claim that it
  collects card or bank details without checking the deployed service.
- Removing a channel listing is separate from deleting a user account. Channel
  removal uses a backend soft-delete flow and does not establish permanent erasure.
- Account soft deletion disables sign-in and hides owned channels while retaining
  database records. See [the account-deletion website guide](ACCOUNT_DELETION_WEB_GUIDE.md)
  for the authenticated API and the distinction from permanent data erasure.

## Details the owner must supply before publishing the policy

These facts are not established by the app source and should be completed with
accurate operational information:

- Legal operator or business name and business address.
- Privacy contact email and support contact details.
- Final website domain, privacy policy URL, and effective date.
- Published account-deletion webpage URL and the permanent personal-data erasure
  process, which is separate from the implemented soft-deletion endpoint.
- Data retention periods, including backups, logs, and deleted records.
- Infrastructure locations and the providers used for email, images, and monitoring.
- Which information businesses, creators, administrators, and service providers
  can access in the deployed service.
- Intended minimum user age and whether minors may use the service.
- Any analytics, advertising, payment, or tracking services added to the final release.

Do not publish promises about automatic account deletion, permanent erasure,
retention periods, data sales, or third-party sharing until the operator has
confirmed those practices.

## Privacy website direction

Use the Tikaddis name and its existing visual identity: primary blue `#0E7BFD`,
orange accent `#FC8A02`, white backgrounds, rounded cards, and readable typography.

The website can include a short product overview, the privacy policy, privacy
contact information, and a clearly explained account-deletion request page once
the request process is defined. Keep the policy readable on mobile and accessible
without signing in. Replace all owner-supplied placeholders before publication.
