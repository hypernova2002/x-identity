import { globalIgnores } from 'eslint/config'
import { defineConfigWithVueTs, vueTsConfigs } from '@vue/eslint-config-typescript'
import pluginVue from 'eslint-plugin-vue'
import pluginVitest from '@vitest/eslint-plugin'
import pluginOxlint from 'eslint-plugin-oxlint'

// To allow more languages other than `ts` in `.vue` files, uncomment the following lines:
// import { configureVueProject } from '@vue/eslint-config-typescript'
// configureVueProject({ scriptLangs: ['ts', 'tsx'] })
// More info at https://github.com/vuejs/eslint-config-typescript/#advanced-setup

export default defineConfigWithVueTs(
  {
    name: 'app/files-to-lint',
    files: ['**/*.{vue,ts,mts,tsx}'],
  },

  globalIgnores(['**/dist/**', '**/dist-ssr/**', '**/coverage/**']),

  ...pluginVue.configs['flat/essential'],
  vueTsConfigs.recommended,

  {
    ...pluginVitest.configs.recommended,
    files: ['src/**/__tests__/*'],
  },

  {
    name: 'app/translated-text',
    files: ['src/**/*.vue'],
    rules: {
      // Text goes through vue-i18n. Besides the rule's defaults, this checks the props our components
      // take text in, and allows the symbols used as icons.
      'vue/no-bare-strings-in-template': [
        'error',
        {
          allowlist: ['(', ')', ',', '.', '&', '+', '-', '=', '*', '/', '#', '%', '!', '?', ':', '[', ']', '{', '}', '<', '>', '·', '•', '‐', '–', '—', '−', '|', '←', '→', '⌄', '✓'],
          attributes: {
            '/.+/': [
              'title',
              'aria-label',
              'aria-placeholder',
              'aria-roledescription',
              'aria-valuetext',
              'label',
              'hint',
              'description',
              'caption',
              'placeholder',
              'empty-message',
              'no-matches-message',
              'confirm-label',
              'search-label',
              'search-placeholder',
              'success-title',
              'success-message',
              'submit-label',
              'button-label',
              'any-label',
              'email-verification-hint',
            ],
            img: ['alt'],
          },
        },
      ],
    },
  },

  ...pluginOxlint.buildFromOxlintConfigFile('.oxlintrc.json'),
)
