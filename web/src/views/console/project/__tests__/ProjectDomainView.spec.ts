import { beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { ref } from 'vue'
import { createMemoryHistory, createRouter } from 'vue-router'
import OpenVue from 'openvue/config'

import ProjectDomainView from '../ProjectDomainView.vue'
import { projectAdminService } from '@/services/project'
import type { ProjectDomain } from '@/types/api'

type Service = typeof projectAdminService

vi.mock('@/services/project', () => ({
  projectAdminService: {
    listDomains: vi.fn<Service['listDomains']>(),
    addDomain: vi.fn<Service['addDomain']>(),
    checkDomain: vi.fn<Service['checkDomain']>(),
    removeDomain: vi.fn<Service['removeDomain']>(),
  },
}))

const admin = ref(true)
vi.mock('@/composables/useProjectContext', () => ({
  useProjectContext: () => ({ accountUid: ref('acct_1'), project: ref({ uid: 'proj_1' }), access: ref({ admin: admin.value }) }),
}))

const domain = (changes: Partial<ProjectDomain> = {}): ProjectDomain => ({
  uid: 'dom_1',
  hostname: 'login.acme.com',
  status: 'pending',
  verified_at: null,
  last_checked_at: null,
  check_error: null,
  dns_missing_since: null,
  certificate_status: 'external',
  verify_until: '2026-10-28T12:00:00Z',
  created_at: '2026-10-25T12:00:00Z',
  saml_apps: [],
  saml_identity_providers: [],
  passkey_count: 0,
  passkey_related_origins: [],
  dns_records: [
    { type: 'CNAME', name: 'login.acme.com', value: 'domains.x-identity.localhost' },
    { type: 'TXT', name: '_x-identity.login.acme.com', value: 'token-123' },
  ],
  ...changes,
})

const router = createRouter({ history: createMemoryHistory(), routes: [{ path: '/:any(.*)*', name: 'any', component: { render: () => null } }] })
for (const name of ['project-saml-app-credentials', 'project-identity-provider']) {
  router.addRoute({ path: `/${name}/:projectUid/:uid?/:samlAppUid?/:providerUid?`, name, component: { render: () => null } })
}

async function mountView() {
  const wrapper = mount(ProjectDomainView, { global: { plugins: [router, [OpenVue, { unstyled: true }]] }, attachTo: document.body })
  await flushPromises()
  return wrapper
}

const button = (wrapper: Awaited<ReturnType<typeof mountView>>, name: string) => wrapper.findAll('button').find((candidate) => candidate.text() === name)

describe('ProjectDomainView', () => {
  beforeEach(() => {
    vi.resetAllMocks()
    admin.value = true
  })

  it('adds a domain and shows the DNS records to create', async () => {
    vi.mocked(projectAdminService.listDomains).mockResolvedValueOnce([]).mockResolvedValueOnce([domain()])
    vi.mocked(projectAdminService.addDomain).mockResolvedValue(domain())
    const wrapper = await mountView()

    await wrapper.get('input').setValue(' login.acme.com ')
    await wrapper.get('form').trigger('submit')
    await flushPromises()

    expect(projectAdminService.addDomain).toHaveBeenCalledWith('acct_1', 'proj_1', 'login.acme.com')
    expect(wrapper.text()).toContain('Waiting for DNS')
    expect(wrapper.text()).toContain('_x-identity.login.acme.com')
    expect(wrapper.text()).toContain('token-123')
    expect(wrapper.find('form').exists()).toBe(false)
  })

  it('checks DNS on request', async () => {
    vi.mocked(projectAdminService.listDomains).mockResolvedValueOnce([domain()]).mockResolvedValueOnce([domain({ status: 'verified', verified_at: '2026-10-25T13:00:00Z' })])
    vi.mocked(projectAdminService.checkDomain).mockResolvedValue(domain({ status: 'verified' }))
    const wrapper = await mountView()

    await button(wrapper, 'Check now')!.trigger('click')
    await flushPromises()

    expect(projectAdminService.checkDomain).toHaveBeenCalledWith('acct_1', 'proj_1', 'dom_1')
    expect(wrapper.text()).toContain('Verified')
    expect(wrapper.text()).toContain('Replace the custom domain')
  })

  it('warns when a verified domain loses its DNS records', async () => {
    vi.mocked(projectAdminService.listDomains).mockResolvedValue([
      domain({ status: 'verified', verified_at: '2026-10-20T12:00:00Z', dns_missing_since: '2026-10-25T10:00:00Z', check_error: 'No CNAME record for login.acme.com was found.' }),
    ])
    const wrapper = await mountView()

    expect(wrapper.text()).toContain('DNS records missing')
    expect(wrapper.text()).toContain('No CNAME record for login.acme.com was found.')
  })

  it('lists the SAML connections on a verified domain, and warns which ones removing it affects', async () => {
    vi.mocked(projectAdminService.listDomains).mockResolvedValue([
      domain({
        status: 'verified',
        verified_at: '2026-10-20T12:00:00Z',
        saml_apps: [{ uid: 'sapp_1', name: 'Wiki', on_custom_domain: true }],
        saml_identity_providers: [{ uid: 'idp_1', name: 'Acme Okta', on_custom_domain: false }],
      }),
    ])
    const wrapper = await mountView()

    expect(wrapper.text()).toContain('Uses login.acme.com')
    expect(wrapper.text()).toContain('Uses the standard URLs')

    await button(wrapper, 'Remove domain')!.trigger('click')
    await flushPromises()
    expect(document.body.textContent).toContain('These go back to the standard URLs')
    expect(document.body.textContent).toContain('Wiki (SAML app)')
    expect(document.body.textContent).not.toContain('Acme Okta (SAML identity provider)')
    wrapper.unmount()
  })

  it("lists the apps' origins that can use the domain's passkeys", async () => {
    vi.mocked(projectAdminService.listDomains).mockResolvedValue([
      domain({ status: 'verified', verified_at: '2026-10-20T12:00:00Z', passkey_related_origins: ['https://app.acme.com'] }),
    ])
    const wrapper = await mountView()

    expect(wrapper.text()).toContain('Apps that can use its passkeys')
    expect(wrapper.text()).toContain('https://app.acme.com')
    wrapper.unmount()
  })

  it('shows the domain to non-admins without letting them change it', async () => {
    admin.value = false
    vi.mocked(projectAdminService.listDomains).mockResolvedValue([domain()])
    const wrapper = await mountView()

    expect(wrapper.text()).toContain('Only project and account admins can change the custom domain.')
    expect(button(wrapper, 'Check now')).toBeUndefined()
    expect(wrapper.find('form').exists()).toBe(false)
  })
})
