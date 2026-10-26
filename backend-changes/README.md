# Admin channel options

The current implementation has been pushed to the backend repository's `main`
branch and deployed through CI/CD. Use that repository for future deployments;
the source files in this folder are an earlier preparation snapshot.

Production now uses `ddl-auto=update`, disables SQL initialization, and rejects
destructive schema modes before connecting to the database. The deployment
workflow runs the full backend test suite against an isolated test database.
The invalid legacy workflow has been removed. The local sibling backend
checkout is synchronized with published commit `f9f8c15`, which also adds the
authenticated `DELETE /account/me` soft-deletion endpoint. See
[the website integration guide](../ACCOUNT_DELETION_WEB_GUIDE.md).

This bundle contains the matching backend changes for the Flutter app. Apply it
with `./backend-changes/Apply-BackendChanges.ps1`. The script verifies original
file hashes before copying files into the sibling backend repository; it does
not deploy or change the running database.

Deploy the backend before installing the updated mobile app. Hibernate's existing
`ddl-auto=update` setting creates CHANNEL_PLATFORM and adds the optional
PLATFORM_CODE foreign key to INFLUENCER_ACCOUNT. The original ACCOUNT_TYPE enum
column and its ordinal values are preserved. Existing channels are linked to
the seeded platform catalog on startup. New platforms use the new relation.

Admin → Channels → Options provides category and platform CRUD. Existing category
write endpoints are reused. The new GET /admin/account-category lets admins read
categories without gaining access to other /user endpoints. The two platform list
endpoints are /admin/channel-platforms and /user/channel-platforms; writes live
under /admin/channel-platforms. Existing security rules restrict writes to ADMIN.

Names must be nonempty and unique within their option list. Platform codes are
stable uppercase identifiers, with letters, digits and underscores. Display order
controls selection ordering. Referenced options cannot be deleted. Deleted
platform records are retained so built-in platforms do not reappear on restart.
Platform codes are reserved even after deletion.

The category relation is now ManyToOne, allowing channels to share a category.
If an older deployed MySQL schema has a single-column UNIQUE index on
INFLUENCER_ACCOUNT.ACCOUNT_CATEGORY_ID, remove that UNIQUE index during deployment
while retaining the foreign key and a nonunique index. Hibernate update does not
reliably remove old uniqueness constraints. Inspect `SHOW CREATE TABLE
INFLUENCER_ACCOUNT` to identify whether this applies to the deployed schema.

Validation: Flutter analyzer and widget tests; Maven ChannelOptionsTest and
ChannelOptionsPersistenceTest. Persistence tests use an isolated H2 database,
disable SQL initialization, and never connect to the deployed database.
