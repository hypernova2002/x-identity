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
    meta: { title: 'Overview', navItem: 'overview', ownHeader: true },
  },

  {
    path: 'applications',
    name: 'project-applications',
    component: () => import('../views/console/project/applications/ApplicationsView.vue'),
    meta: {
      title: 'Applications',
      navItem: 'applications',
      description: 'The apps that sign this project\'s end users in: OpenID Connect and API clients, and SAML applications.',
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
  { path: 'app-clients', redirect: withQuery('project-applications', { type: 'oidc' }) },
  { path: 'saml-apps', redirect: withQuery('project-applications', { type: 'saml' }) },

  {
    path: 'end-users',
    name: 'project-end-users',
    component: () => import('../views/console/project/ProjectEndUsersView.vue'),
    meta: { title: 'End users', navItem: 'end-users', description: 'The people who sign in to this project\'s apps. Console users are managed separately, under Account.' },
  },
  {
    path: 'end-users/:endUserUid',
    name: 'project-end-user',
    component: () => import('../views/console/project/EndUserDetailView.vue'),
    meta: { title: 'End user', navItem: 'end-users', ownHeader: true },
  },
  {
    path: 'groups',
    name: 'project-groups',
    component: () => import('../views/console/project/ProjectGroupsView.vue'),
    meta: { title: 'Groups', navItem: 'groups', description: 'Sets of end users, for giving access to applications and sending group names to them.' },
  },
  {
    path: 'attributes',
    name: 'project-attributes',
    component: () => import('../views/console/project/ProjectAttributesView.vue'),
    meta: { title: 'Attributes', navItem: 'attributes', description: 'Custom fields on end users, optionally required, user-editable or included in ID tokens.' },
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
        meta: { title: 'Authentication settings', navItem: 'authentication', ownHeader: true, authSection: section },
      })),
    ],
  },
  {
    path: 'identity-providers',
    name: 'project-identity-providers',
    component: () => import('../views/console/project/ProjectIdentityProvidersView.vue'),
    meta: {
      title: 'Identity providers',
      navItem: 'identity-providers',
      description: 'External systems end users can sign in with: social providers, OpenID Connect providers and companies\' SAML identity providers.',
    },
  },
  {
    path: 'identity-providers/:providerUid',
    name: 'project-identity-provider',
    component: () => import('../views/console/project/IdentityProviderDetailView.vue'),
    meta: { title: 'Identity provider', navItem: 'identity-providers', ownHeader: true },
  },
  { path: 'sign-in-providers', redirect: withQuery('project-identity-providers') },

  {
    path: 'test-sign-in',
    name: 'project-test-sign-in',
    component: () => import('../views/console/project/ProjectTestSignInView.vue'),
    meta: {
      title: 'Test sign-in',
      navItem: 'test-sign-in',
      description: 'Sign an end user in the way an app would, step through challenges, and inspect the tokens.',
    },
  },
  {
    path: 'audit-log',
    name: 'project-audit-log',
    component: () => import('../views/console/project/ProjectAuditLogView.vue'),
    meta: { title: 'Audit log', navItem: 'audit-log', description: 'Sign-ins, failures and configuration changes in this project.' },
  },

  {
    path: 'settings',
    name: 'project-settings',
    component: () => import('../views/console/project/ProjectSettingsView.vue'),
    meta: { title: 'General settings', navItem: 'settings', description: 'The project\'s name, sign-up and email links.' },
  },
  {
    path: 'members',
    name: 'project-members',
    component: () => import('../views/console/project/ProjectMembersView.vue'),
    meta: {
      title: 'Members',
      navItem: 'members',
      description: 'Console users who work on this project, and their project roles. End users are under Directory.',
    },
  },
]
