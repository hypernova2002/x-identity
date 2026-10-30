import type { RouteLocation, RouteLocationRaw, RouteRecordRaw } from 'vue-router'

/**
 * A project's pages, grouped in the sidebar as Overview, Applications, Directory, Authentication,
 * Monitoring & testing and Project settings. Paths from before the grouping are kept, so deep links
 * and registered redirect URIs (such as the test sign-in page's) keep working; renamed pages redirect.
 */
const withQuery = (name: string, query: Record<string, string> = {}) => (to: RouteLocation): RouteLocationRaw => ({
  name,
  params: to.params,
  query: { ...to.query, ...query },
})

type Lazy = RouteRecordRaw['component']

const applicationTabs = (tabs: [path: string, name: string, component: Lazy][]): RouteRecordRaw[] =>
  tabs.map(([path, name, component]) => ({ path, name, component, meta: { navItem: 'applications', ownHeader: true } }) as RouteRecordRaw)

export const projectRoutes: RouteRecordRaw[] = [
  {
    path: '',
    name: 'project',
    component: () => import('../views/console/project/ProjectOverviewView.vue'),
    meta: { title: 'pages.overview.title', navItem: 'overview', ownHeader: true },
  },

  {
    path: 'applications',
    name: 'project-applications',
    component: () => import('../views/console/project/applications/ApplicationsView.vue'),
    meta: {
      title: 'pages.applications.title',
      navItem: 'applications',
      ownHeader: true,
      description: 'pages.applications.description',
    },
  },
  {
    path: 'applications/clients/:clientUid',
    component: () => import('../views/console/project/applications/AppClientLayout.vue'),
    children: applicationTabs([
      ['', 'project-app-client', () => import('../views/console/project/applications/AppClientOverviewTab.vue')],
      ['sign-in', 'project-app-client-sign-in', () => import('../views/console/project/applications/AppClientSignInTab.vue')],
      ['access', 'project-app-client-access', () => import('../views/console/project/applications/AppAccessTab.vue')],
      ['tokens', 'project-app-client-tokens', () => import('../views/console/project/applications/AppClientTokensTab.vue')],
      ['credentials', 'project-app-client-credentials', () => import('../views/console/project/applications/AppClientCredentialsTab.vue')],
      ['api-access', 'project-app-client-api-access', () => import('../views/console/project/applications/AppClientApiAccessTab.vue')],
      ['activity', 'project-app-client-activity', () => import('../views/console/project/applications/AppActivityTab.vue')],
    ]),
  },
  {
    path: 'applications/saml/:samlAppUid',
    component: () => import('../views/console/project/applications/SamlAppLayout.vue'),
    children: applicationTabs([
      ['', 'project-saml-app', () => import('../views/console/project/applications/SamlAppOverviewTab.vue')],
      ['configuration', 'project-saml-app-configuration', () => import('../views/console/project/applications/SamlAppConfigurationTab.vue')],
      ['access', 'project-saml-app-access', () => import('../views/console/project/applications/AppAccessTab.vue')],
      ['credentials', 'project-saml-app-credentials', () => import('../views/console/project/applications/SamlAppCredentialsTab.vue')],
      ['activity', 'project-saml-app-activity', () => import('../views/console/project/applications/AppActivityTab.vue')],
    ]),
  },
  {
    path: 'apis',
    name: 'project-apis',
    component: () => import('../views/console/project/applications/ApisView.vue'),
    meta: {
      title: 'pages.apis.title',
      navItem: 'apis',
      ownHeader: true,
      description: 'pages.apis.description',
    },
  },
  { path: 'app-clients', redirect: withQuery('project-applications', { kind_eq: 'oidc' }) },
  { path: 'saml-apps', redirect: withQuery('project-applications', { kind_eq: 'saml' }) },

  {
    path: 'end-users',
    name: 'project-end-users',
    component: () => import('../views/console/project/ProjectEndUsersView.vue'),
    meta: { title: 'pages.endUsers.title', navItem: 'end-users', ownHeader: true, description: 'pages.endUsers.description' },
  },
  {
    path: 'end-users/:endUserUid',
    name: 'project-end-user',
    component: () => import('../views/console/project/EndUserDetailView.vue'),
    meta: { title: 'pages.endUser.title', navItem: 'end-users', ownHeader: true },
  },
  {
    path: 'groups',
    name: 'project-groups',
    component: () => import('../views/console/project/ProjectGroupsView.vue'),
    meta: {
      title: 'pages.groups.title',
      navItem: 'groups',
      ownHeader: true,
      description: 'pages.groups.description',
    },
  },
  {
    path: 'attributes',
    name: 'project-attributes',
    component: () => import('../views/console/project/ProjectAttributesView.vue'),
    meta: {
      title: 'pages.attributes.title',
      navItem: 'attributes',
      ownHeader: true,
      description: 'pages.attributes.description',
    },
  },

  {
    path: 'authentication',
    component: () => import('../views/console/project/authentication/AuthenticationLayout.vue'),
    children: [
      { path: '', name: 'project-authentication', redirect: withQuery('project-auth-sign-in') },
      ...(
        [
          ['sign-in', 'project-auth-sign-in', 'sign-in'],
          ['mfa', 'project-auth-mfa', 'mfa'],
          ['policies', 'project-auth-policies', 'policies'],
          ['tokens', 'project-auth-tokens', 'tokens'],
          ['keys', 'project-auth-keys', 'signing'],
        ] as const
      ).map(([path, name, section]) => ({
        path,
        name,
        component: () => import('../views/console/project/authentication/AuthSettingsSectionView.vue'),
        meta: { title: 'pages.authentication.title', navItem: 'authentication', ownHeader: true, authSection: section },
      })),
    ],
  },
  {
    path: 'identity-providers',
    name: 'project-identity-providers',
    component: () => import('../views/console/project/ProjectIdentityProvidersView.vue'),
    meta: {
      title: 'pages.identityProviders.title',
      ownHeader: true,
      navItem: 'identity-providers',
      description: 'pages.identityProviders.description',
    },
  },
  {
    path: 'identity-providers/:providerUid',
    name: 'project-identity-provider',
    component: () => import('../views/console/project/IdentityProviderDetailView.vue'),
    meta: { title: 'pages.identityProvider.title', navItem: 'identity-providers', ownHeader: true },
  },
  { path: 'sign-in-providers', redirect: withQuery('project-identity-providers') },

  {
    path: 'test-sign-in',
    name: 'project-test-sign-in',
    component: () => import('../views/console/project/ProjectTestSignInView.vue'),
    meta: {
      title: 'pages.testSignIn.title',
      navItem: 'test-sign-in',
      description: 'pages.testSignIn.description',
    },
  },
  {
    path: 'audit-log',
    name: 'project-audit-log',
    component: () => import('../views/console/project/ProjectAuditLogView.vue'),
    meta: { title: 'pages.auditLog.title', navItem: 'audit-log', description: 'pages.auditLog.description' },
  },

  {
    path: 'settings',
    name: 'project-settings',
    component: () => import('../views/console/project/ProjectSettingsView.vue'),
    meta: { title: 'pages.settings.title', navItem: 'settings', description: 'pages.settings.description' },
  },
  {
    path: 'domain',
    name: 'project-domain',
    component: () => import('../views/console/project/ProjectDomainView.vue'),
    meta: {
      title: 'pages.domain.title',
      navItem: 'domain',
      description: 'pages.domain.description',
    },
  },
  {
    path: 'members',
    name: 'project-members',
    component: () => import('../views/console/project/ProjectMembersView.vue'),
    meta: {
      title: 'pages.members.title',
      navItem: 'members',
      description: 'pages.members.description',
    },
  },
]
