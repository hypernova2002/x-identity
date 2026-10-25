/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_BASE_URL: string
  /** Where the console is served; the app runs only hosted pages on any other origin (a project's custom domain). */
  readonly VITE_CONSOLE_URL?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
