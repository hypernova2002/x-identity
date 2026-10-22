# Groups and app access

## Groups

A **group** is a named set of a project's end users. Groups are managed on the **Groups** page or
the `groups` API (create, rename, describe, delete; add and remove members). A user's groups are
shown on the End users page.

**New end users join automatically** is an option per group. Users created any way after it's
turned on (self sign-up, an admin, an invitation, an identity provider) join the group; existing
users aren't added.

Groups are used to assign apps, are sent to apps as the `groups` claim (OIDC, with the `groups`
scope) or a SAML attribute, and can be kept in step with a customer's IdP through
[SAML group mappings](end-user-auth/saml-providers.md#group-sync).

## Assignment-only access

Every app (app client or SAML app) is **assignment-only**: an end user can only sign in to it when
the app is assigned to them directly or to one of their groups. Assign with the **Access** button on
the App clients and SAML apps pages, or the `assignments` API under each app.

Access is checked:

- at password sign-in and every challenge,
- at provider sign-in (browser and native),
- when refreshing tokens: unassigned users can't refresh (`app_access_denied`),
- at hosted login and single sign-on, where OIDC apps get `error=access_denied` and SAML apps show
  the hosted error page.

Refusals are audited (`end_user.app_access_denied`). The system-managed app portal client is open to
everyone, since it only lists the apps a user is assigned.

A new app can't be used by anyone until it's assigned.

### Existing projects

When assignment was introduced, each project got an **All end users** group that new users join
automatically, containing every existing end user and assigned to every existing app client, so
nothing stopped working. Narrow or remove it as needed.
