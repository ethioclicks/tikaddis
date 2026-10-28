# Tikaddis backend capability review

Updated on October 28, 2026, against backend source commit `216b681`.
This replaces the earlier review of `f9f8c15`; the old authorization findings
listed below as corrected should not be treated as current unresolved defects.

This is an inspection of controllers, service implementations, repositories,
entities, and the related mobile screens. It identifies implemented code and
missing behavior; it is not a live campaign execution test.

The backend update at `216b681` passed 29 backend tests, was deployed through
CI/CD, and received read-only live verification of its capability marker, schema
mode, category preservation, promotion-list response and attachment access rules.
That does not establish that the planned content-review workflow exists.

The approved product direction is now **direct requester–creator collaboration**.
See [the architecture plan](CONTENT_APPROVAL_ARCHITECTURE.md) for the proposed
implementation and [the deployed update](CHANNEL_WORKFLOW_UPDATE.md) for existing
request-form and channel fixes. This review distinguishes current code from that
target; editing these documents does not change the running backend.

## Current product

Tikaddis currently has a creator directory, channel management, account management,
and a manually operated promotion-request workflow. Campaign execution progress is
represented by the request's current status. Detailed campaign briefs and private
request attachments are implemented. Draft review, versioned creative approvals,
publication evidence and requester delivery acceptance are not yet implemented.
There is no implemented campaign performance-tracking engine.

## Implemented in the backend

| Capability | Existing behavior |
| --- | --- |
| Accounts and access | Registration, password sign-in, JWT authentication, roles, profiles, account enable/lock controls |
| Recovery and verification | Email verification and password-recovery code flows |
| Own-account soft deletion | Token-derived account selection, current-password confirmation, disabled sign-in, hidden owned channels |
| Creator onboarding | Candidate/creator roles and administrator approval |
| Channel listings | Create, owner-checked edit/soft delete, approval, discovery, category/platform filtering and supported username/handle normalization |
| Platform/category configuration | Administrator-managed catalogs and display ordering |
| Channel information | Description, channel/image URLs, audience count, minimum/maximum views, pricing options |
| Promotion requests | Authenticated requester linked to an approved available channel; campaign title, brand, objective, audience, free-text deliverables, creative brief, call to action, proposed ETB budget, requested dates, legacy image URL, feedback and current status |
| Private request attachments | Up to five JPG/PNG/PDF files, 5 MB each; metadata and binary content stored separately in the database; authenticated downloads |
| Lists and moderation | Paginated participant/admin lists, status filtering, admin review before creator visibility, owner-checked creator decisions and initial-request cancellation |
| Channel moderation fixes | Repeated approval succeeds consistently; disapproval returns success after saving; mobile list refresh and action state corrected |

Several legacy service methods for featured businesses, keyword searches, and tag
options return `null`. These method names do not establish working features.
The implemented category/platform filtering and approved-channel listing methods
are separate methods with repository queries.

## What tracking exists

### Current request status

The deployed path still uses the earlier admin gate:

```text
REQUESTED
  -> ADMIN_APPROVED
  -> ACCOUNT_OWNER_APPROVED
  -> RUNNING
  -> FULFILLED
```

Rejection and business cancellation statuses also exist. Business cancellation
currently changes only a request still in REQUESTED state.

Starting and fulfilling a promotion updates one status column and saves the
record. Those operations do not verify that a post exists or that the business
received a result.

This is the **current implementation**, not the chosen target architecture.
The intended replacement is:

```text
Requester sends directly to creator
  -> Creator accepts or counterproposes
  -> Both agree on scope
  -> Creator submits drafts
  -> Requester approves or requests changes
  -> Creator publishes and submits evidence
  -> Requester accepts delivery
```

Channel-listing approval remains separate. Admins handle reports, disputes and
support cases; they do not approve ordinary requests, creative or delivery in the
target workflow. The deployed backend still needs changes to support this.

### Briefs and attachments

The new multipart brief endpoint persists request details and files in one
transaction. It validates brief limits, requested dates, attachment count, size,
extension and file signatures. Files rejected during submission do not leave a
partial campaign request.

Currently the requester and admins can access request attachments; the channel
owner gains access after admin review. These are requester-supplied brief assets,
not creator draft submissions or publication evidence. There is no video draft
upload/preview pipeline. Existing file access is broader for admins than the new
architecture's proposed case-scoped staff access.

### Channel statistics supplied by users

The backend has `TopViewCount` and `RecentViewCount` entities containing a count,
post URL, and posted date. These are associated with a creator channel, and
channel creation/update accepts supplied values.

There is no implemented social-platform data fetch, scheduled synchronization,
verified data source, or campaign attribution for these numbers. They are channel
metadata, rather than measured results of a particular promotion request.

### Feedback

A promotion request has a `feedback` string that the update service can save.
There is no dedicated review, rating, revision, dispute, or business acceptance
workflow behind that field.

## Missing campaign functionality

| Capability | Finding |
| --- | --- |
| Progress timeline | No persisted transition-event history, actor, or transition timestamp |
| Actual execution dates | Requested dates are stored, but no dedicated started/completed timestamps |
| Structured deliverables | One free-text deliverables field; no separately scheduled/reviewed item records |
| Creator draft submissions | No scripts, storyboards or final-preview submission/version records |
| Creative approval | No requester approval of a specific draft or final publication package |
| Revision discussion | One feedback field; no version-linked comment threads, revision rounds or change requests |
| Formats and templates | Platform/category catalogs exist; content-format schemas, reusable templates and brand libraries do not |
| Delivery evidence | No campaign-specific published-post link, screenshot evidence, or submission record |
| Business review | No dedicated approve-delivery or request-changes step |
| Campaign results | No campaign-specific views, clicks, reach, impressions, or conversions |
| Automatic measurement | No social-platform API integration, tracking URL service, pixel, or analytics ingestion found |
| Automatic publishing | No posting integration, bot, scheduled publisher, or automatic campaign start/finish job found |
| Financial agreement | Proposed budget exists; no mutually accepted scope/price snapshot, counterproposal or payable amount |
| Payments | No payment transaction, receipt verification, webhook, escrow, payout, refund, or reconciliation flow found |
| Campaign notifications | No backend notification records, push delivery, or event notifications found |
| Support/dispute cases | No dedicated case records, case-scoped staff grants, holds or resolution workflow |

`PER_CLICK`, `PER_VIEW`, and `PER_DAY` are pricing types. They do not implement
click measurement, view measurement, or automatic billing.

The mobile notification screen currently contains hardcoded demonstration
messages. Its displayed relative times are not a backend activity timeline.

## Authorization fixes and remaining workflow differences

Corrected in `216b681`:

- Channel create/list/edit/delete routes derive ownership from the signed-in user;
  editing another owner's channel is rejected even with a forged owner header.
- Promotion creation and participant lists use the authenticated identity.
- Request reads check participation; updates, deletion and cancellation check the
  requester, while creator acceptance/rejection checks the channel owner.
- Creator decisions require the deployed `ADMIN_APPROVED` state. Lists exclude
  requests that have not passed admin review.
- Both running/fulfilled service methods require admin access, including when
  reached through the alternate `/user/` routes.
- Admin approval/rejection is limited to requests in `REQUESTED` state.
- Promotion deletion no longer cascades removal to its requester or channel.

These changes address the earlier findings in these operations; they are not a
claim that every unrelated account/profile route received a complete security audit.

Remaining changes required by the chosen product architecture:

- Remove the admin approval dependency from new-workflow creation, creator lists,
  shared-asset reads and creator decisions together. Merely exposing buttons is
  insufficient while the service still rejects the action.
- Replace admin-driven running/fulfilled commands with participant agreement,
  deliverable progress and requester-confirmed delivery.
- Add version-specific creative approvals and immutable accepted scope; a free-text
  edit or single status update cannot enforce these guarantees.
- Replace blanket admin access to new private creative with explicit, audited
  support/report/dispute case access.
- Keep legacy endpoints from bypassing new workflow rules during migration.
- Current completion still checks only the previous status. It does not require
  publication evidence, requester confirmation, payment or campaign results.

## What happens after influencer acceptance today

The influencer publishes outside Tikaddis. An admin manually marks the request
RUNNING and later FULFILLED. The system records those decisions but cannot
independently establish whether the promotion was delivered or how it performed.

## Suggested next implementation

A useful complete first workflow can work without automatic social-platform APIs:

1. Introduce a versioned direct-booking workflow. Sent requests immediately reach
   the booked creator, who can accept, decline or counterpropose.
2. Save mutually accepted scope, price, itemized deliverables, dates, review stages
   and revision terms. Participant agreement activates the booking.
3. Add creator draft versions, private media and requester comments, approval and
   formal revision requests. Script approval is separate from final-video approval.
4. Add per-item publication links/evidence and requester delivery acceptance.
   Derive normal completion from all required deliverables, without admin approval.
5. Record real activity events and create real in-app notifications for each
   relevant participant action.
6. Provide separate support/report/dispute cases with scoped staff access and
   audited exceptional outcomes, never impersonated participant approvals.
7. Add reusable content templates and format-specific fields; preserve populated
   template and format versions in each accepted assignment.

Use explicit new state columns/tables rather than reordering the legacy ordinal
status enum. Preserve existing history and offer pending legacy requests an
explicit Send directly migration action. Block old admin status commands from
acting on new-workflow bookings. Backend support, mobile permissions/filtering
and asset access must roll out together as described in the architecture plan.

Campaign results, payment handling and automatic platform integrations can build
on these records later. They should not be represented as existing functionality.

## Main source references

- `bussinesLogic/entity/PromotionRequest.java`: stored request fields.
- `bussinesLogic/services/impl/PromotionRequestServiceImpl.java`: request changes and transitions.
- `bussinesLogic/controllers/PromotionBriefController.java`: multipart brief and authenticated file endpoints.
- `bussinesLogic/services/PromotionBriefService.java`: transactional brief/file validation and download authorization.
- `bussinesLogic/entity/PromotionAttachment.java` and `PromotionAttachmentContent.java`: attachment metadata and stored bytes.
- `bussinesLogic/controllers/PromotionRequestController.java`: business/user routes.
- `bussinesLogic/controllers/PromotionController.java`: creator acceptance and lists.
- `security/service/impl/UserServiceImplementation.java`: admin approval behavior.
- `security/service/CurrentActor.java`: authenticated participant and admin checks.
- `bussinesLogic/entity/InfluencerAccount.java`: channel metadata and statistics relations.
- `bussinesLogic/entity/TopViewCount.java` and `RecentViewCount.java`: stored post counts.
- `bussinesLogic/services/impl/InfluencerAccountServiceImpl.java`: supplied channel data and legacy stubs.
- `security/enums/PriceTypeEnum.java`: pricing labels.
- Mobile `lib/screens/notifications/notifications_screen.dart`: demonstration notification data.
