import { inject, type ComputedRef, type InjectionKey, type Ref } from 'vue'

import type { AppRef } from './useAppAccess'
import type { AppClient, SamlApp } from '@/types/api'

/** The application an application page belongs to, whichever kind it is. */
export const APPLICATION_KEY: InjectionKey<ComputedRef<AppRef>> = Symbol('application')

export interface Loaded<T> {
  record: Ref<T>
  /** Puts a record the API returned (after saving) in place of the loaded one. */
  replace: (updated: T) => void
}

export const APP_CLIENT_KEY: InjectionKey<Loaded<AppClient>> = Symbol('app-client')
export const SAML_APP_KEY: InjectionKey<Loaded<SamlApp>> = Symbol('saml-app')

function required<T>(key: InjectionKey<T>, name: string): T {
  const value = inject(key)
  if (!value) throw new Error(`${name} pages must be rendered inside their layout`)
  return value
}

export const useApplication = () => required(APPLICATION_KEY, 'Application')
export const useAppClient = () => required(APP_CLIENT_KEY, 'App client')
export const useSamlApp = () => required(SAML_APP_KEY, 'SAML application')
