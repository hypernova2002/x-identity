import { createRouter, createWebHistory } from 'vue-router'

import { useSessionStore } from '@/stores/session'

declare module 'vue-router' {
  interface RouteMeta {
    requiresAuth?: boolean
    requiresAdmin?: boolean
    title?: string
  }
}

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    { path: '/', redirect: '/console' },
    {
      path: '/',
      component: () => import('../layouts/AuthLayout.vue'),
      children: [
        { path: 'sign-up', name: 'sign-up', component: () => import('../views/auth/SignUpView.vue') },
        { path: 'sign-in', name: 'account-picker', component: () => import('../views/auth/AccountPickerView.vue') },
        { path: ':slug/sign-in', name: 'sign-in', component: () => import('../views/auth/SignInView.vue') },
        { path: ':slug/forgot-password', name: 'forgot-password', component: () => import('../views/auth/ForgotPasswordView.vue') },
        { path: ':slug/reset-password', name: 'reset-password', component: () => import('../views/auth/ResetPasswordView.vue') },
        { path: ':slug/verify-email', name: 'verify-email', component: () => import('../views/auth/VerifyEmailView.vue') },
        {
          path: ':slug/confirm-email-change',
          name: 'confirm-email-change',
          component: () => import('../views/auth/ConfirmEmailChangeView.vue'),
        },
        {
          path: ':slug/accept-invitation',
          name: 'accept-invitation',
          component: () => import('../views/auth/AcceptInvitationView.vue'),
        },
      ],
    },
    {
      path: '/auth/:slug/:projectUid',
      component: () => import('../layouts/HostedLayout.vue'),
      children: [
        { path: 'login', name: 'hosted-login', component: () => import('../views/hosted/HostedLoginView.vue') },
        { path: 'error', name: 'hosted-error', component: () => import('../views/hosted/HostedErrorView.vue') },
        { path: 'signed-out', name: 'hosted-signed-out', component: () => import('../views/hosted/HostedSignedOutView.vue') },
        { path: 'apps', name: 'hosted-portal', component: () => import('../views/hosted/HostedPortalView.vue') },
      ],
    },
    {
      path: '/console',
      component: () => import('../layouts/ConsoleLayout.vue'),
      meta: { requiresAuth: true },
      children: [
        { path: '', name: 'console-home', component: () => import('../views/console/ConsoleHomeView.vue') },
        { path: 'welcome', name: 'welcome', component: () => import('../views/console/WelcomeView.vue') },
        {
          path: 'projects/:projectUid',
          component: () => import('../views/console/project/ProjectLayout.vue'),
          children: [
            {
              path: '',
              name: 'project',
              component: () => import('../views/console/project/ProjectOverviewView.vue'),
              meta: { title: 'Overview' },
            },
            {
              path: 'members',
              name: 'project-members',
              component: () => import('../views/console/project/ProjectMembersView.vue'),
              meta: { title: 'Members' },
            },
            {
              path: 'app-clients',
              name: 'project-app-clients',
              component: () => import('../views/console/project/ProjectAppClientsView.vue'),
              meta: { title: 'App clients' },
            },
            {
              path: 'saml-apps',
              name: 'project-saml-apps',
              component: () => import('../views/console/project/ProjectSamlAppsView.vue'),
              meta: { title: 'SAML apps' },
            },
            {
              path: 'groups',
              name: 'project-groups',
              component: () => import('../views/console/project/ProjectGroupsView.vue'),
              meta: { title: 'Groups' },
            },
            {
              path: 'end-users',
              name: 'project-end-users',
              component: () => import('../views/console/project/ProjectEndUsersView.vue'),
              meta: { title: 'End users' },
            },
            {
              path: 'attributes',
              name: 'project-attributes',
              component: () => import('../views/console/project/ProjectAttributesView.vue'),
              meta: { title: 'Attributes' },
            },
            {
              path: 'authentication',
              name: 'project-authentication',
              component: () => import('../views/console/project/ProjectAuthSettingsView.vue'),
              meta: { title: 'Authentication' },
            },
            {
              path: 'sign-in-providers',
              name: 'project-sign-in-providers',
              component: () => import('../views/console/project/ProjectSignInProvidersView.vue'),
              meta: { title: 'Sign-in providers' },
            },
            {
              path: 'test-sign-in',
              name: 'project-test-sign-in',
              component: () => import('../views/console/project/ProjectTestSignInView.vue'),
              meta: { title: 'Test sign-in' },
            },
            {
              path: 'audit-log',
              name: 'project-audit-log',
              component: () => import('../views/console/project/ProjectAuditLogView.vue'),
              meta: { title: 'Audit log' },
            },
          ],
        },
        { path: 'projects', name: 'projects', component: () => import('../views/console/ProjectsView.vue') },
        {
          path: 'account/users',
          name: 'users',
          component: () => import('../views/console/UsersView.vue'),
          meta: { requiresAdmin: true },
        },
        {
          path: 'account/authentication',
          name: 'auth-settings',
          component: () => import('../views/console/AuthSettingsView.vue'),
          meta: { requiresAdmin: true },
        },
        {
          path: 'account/audit-log',
          name: 'audit-log',
          component: () => import('../views/console/AuditLogView.vue'),
          meta: { requiresAdmin: true },
        },
        { path: 'security', name: 'security', component: () => import('../views/console/SecurityView.vue') },
      ],
    },
    {
      path: '/:pathMatch(.*)*',
      name: 'not-found',
      component: () => import('../views/NotFoundView.vue'),
    },
  ],
})

router.beforeEach(async (to) => {
  if (!to.matched.some((record) => record.meta.requiresAuth)) return true

  const session = useSessionStore()
  const signInRoute = () => {
    const slug = session.lastAccountSlug()
    return { path: slug ? `/${slug}/sign-in` : '/sign-in', query: { redirect: to.fullPath } }
  }

  if (!(await session.restore())) return signInRoute()

  if (!session.me && !(await session.loadMe().catch(() => null))) {
    session.clear()
    return signInRoute()
  }

  if (to.matched.some((record) => record.meta.requiresAdmin) && !session.isAccountAdmin) {
    return { name: 'projects' }
  }

  return true
})

/** Only follow redirects to paths inside this app, never to another origin. */
export function safeRedirect(value: unknown, fallback = '/console'): string {
  return typeof value === 'string' && value.startsWith('/') && !value.startsWith('//') ? value : fallback
}

export default router
