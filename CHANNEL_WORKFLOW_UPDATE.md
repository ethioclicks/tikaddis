# Channel and campaign request update

Backend commit: `216b681`. Local verification: 29 backend tests and 23 mobile tests
passed; Dart analysis reported no issues, and the Android debug APK built successfully.

## Mobile changes

1. Channel editing sends the required `pid` header. The server checks the signed-in owner independently of that header.
2. Influencer requests appear only after admin approval. Approve/Reject actions appear only while the status is `ADMIN_APPROVED`.
3. Campaign requests include a title, brand, objective, target audience, requested deliverables, creative brief, call to action, optional proposed ETB budget, and attachments.
4. Admin channel moderation refreshes the list and related cached channel data. Already approved channels have a disabled Approved button. Disapproval returns success correctly, and loading states clear after actions.
5. Channel addresses accept URLs or handles/usernames for Telegram, YouTube, TikTok, Instagram and Facebook. Handles are converted into full URLs. Custom platforms require a URL.
6. Channel list icons use the platform's color against a light tint; cards remain white.
7. All screen toasts use `AppToast`, matching authentication.

## Posting dates

Each selected date is a requested day for content publication. Multiple dates request multiple posting days; they are not a date range and do not automatically publish anything. Dates remain subject to agreement with the creator. The form sorts dates, prevents duplicates, and explains this before submission. The backend rejects past dates and more than 30 dates.

## Campaign brief API

`POST /user/promotion/secure/brief`

- Bearer authentication, business user or influencer role.
- Header: `accountPublicId` for the selected approved channel.
- Body: multipart form data with one `brief` part (`application/json`) and optional repeated `files` parts.
- JSON fields: `campaignTitle` (120 characters), `brandName` (120), `objective` (500), `targetAudience` (500), `deliverables` (2000), `promotionText` (10–6000), `callToAction` (500), optional `proposedBudget` (>0, up to 100000000 ETB), and `dateList` (1–30 dates).
- At most 5 JPG, PNG or PDF attachments, 5 MB each. The backend checks extension and file signature.
- The request and attachments are saved in one transaction. Rejected uploads leave no partial request.
- The requester is taken from the authenticated session. Supplying another user's ID does not change ownership.
- The proposed budget is an offer, not a payment or an agreed invoice.
- The original JSON creation endpoint remains available to older apps.

`GET /promotion-files/{attachmentId}`

- Bearer authentication required.
- The requesting business and admins can download files. The channel owner can download after admin approval. Other users cannot access them.
- Files are stored in the database, separately from attachment metadata, so application redeployment does not remove them and list queries do not load binary contents.
- Responses use attachment disposition, `nosniff`, and `Cache-Control: no-store`.
- Uploaded images can be viewed inside the mobile app. PDFs can be saved through the device's file picker.

## Workflow protections

Channel edits and deletions use the signed-in owner. Promotion creation and participant lists derive the user from the session, not a supplied owner header. Request reads, edits, deletion, cancellation, and creator decisions check the corresponding participant. Admin approval only applies to `REQUESTED` requests. Running/fulfilled transitions require admin access, including the old alternate routes under `/user/`.

Existing campaign delivery remains manual. This update adds a professional request brief and assets; it does not add automatic publishing, performance analytics, payments, or delivery verification.

## Operations and data

Production continues to use schema update with the existing destructive-schema guard. New columns and attachment tables are additive. No production records are deleted to test this update. Uploaded briefs and artwork are additional user-provided data and should be described in the product privacy policy. Account soft deletion still retains these records; it is not permanent erasure.
