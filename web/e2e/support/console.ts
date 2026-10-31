import * as fixtures from './fixtures'
import { listPage, type MockApi } from './mockApi'
import type { Me, Project } from '@/types/api'

export interface ConsoleOptions {
  user?: Me
  projects?: Project[]
}

/** The calls every console page makes: the signed-in user, and the projects for the project switcher. */
export function mockConsole(api: MockApi, { user = fixtures.me(), projects = [] }: ConsoleOptions = {}) {
  const base = `/v1/accounts/${user.account.uid}`
  api.on('GET', `${base}/me`, { body: user })
  api.on('GET', `${base}/projects`, listPage(projects))
  api.on('GET', `${base}/projects/:project/members`, listPage([]))
  for (const project of projects) api.on('GET', `${base}/projects/${project.uid}`, { body: project })
  return { user, base }
}
