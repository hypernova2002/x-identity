import { createRouter, createWebHistory } from 'vue-router'

import { projectRoutes } from './projectRoutes'
import { useSessionStore } from '@/stores/session'
import type { AuthSettingsSection } from '@/utils/authSettings'

declare module 'vue-router' {
  interface RouteMeta {
    requiresAuth?: boolean
    requiresAdmin?: boolean
    title?: string
    /** Shown under the title by the project layout. */
    description?: string
    /** Which sidebar entry is current, including on detail pages below it. */
    navItem?: string
    /** Detail pages render their own header, with breadcrumbs and actions. */
    ownHeader?: boolean
    authSection?: AuthSettingsSection
    /** Account pages swap the project sidebar for the account's own navigation. */
    context?: 'account'
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
          children: projectRoutes,
        },
        { path: 'projects', name: 'projects', component: () => import('../views/console/ProjectsView.vue'), meta: { navItem: 'account-projects', context: 'account' } },
        {
          path: 'account/users',
          name: 'users',
          component: () => import('../views/console/UsersView.vue'),
          meta: { requiresAdmin: true, navItem: 'account-users', context: 'account' },
        },
        {
          path: 'account/authentication',
          name: 'auth-settings',
          component: () => import('../views/console/AuthSettingsView.vue'),
          meta: { requiresAdmin: true, navItem: 'account-authentication', context: 'account' },
        },
        {
          path: 'account/audit-log',
          name: 'audit-log',
          component: () => import('../views/console/AuditLogView.vue'),
          meta: { requiresAdmin: true, navItem: 'account-audit-log', context: 'account' },
        },
        { path: 'security', name: 'security', component: () => import('../views/console/SecurityView.vue'), meta: { navItem: 'security' } },
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
