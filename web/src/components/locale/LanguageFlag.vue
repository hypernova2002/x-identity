<script setup lang="ts">
import { useId } from 'vue'

import type { SupportedLocale } from '@/i18n'

// Flags are drawn in their official colours, so they don't use the design tokens. The UK flag
// stands for English, matching the British spelling of the copy.
defineProps<{
  locale: SupportedLocale
}>()

const id = useId()
</script>

<template>
  <svg v-if="locale === 'en'" viewBox="0 0 60 30" preserveAspectRatio="xMidYMid slice" class="h-4 w-6 rounded-sm ring-1 ring-border" aria-hidden="true">
    <clipPath :id="`${id}-flag`"><path d="M0,0 v30 h60 v-30 z" /></clipPath>
    <clipPath :id="`${id}-diagonals`"><path d="M30,15 h30 v15 z v15 h-30 z h-30 v-15 z v-15 h30 z" /></clipPath>
    <g :clip-path="`url(#${id}-flag)`">
      <path d="M0,0 v30 h60 v-30 z" fill="#012169" />
      <path d="M0,0 L60,30 M60,0 L0,30" stroke="#ffffff" stroke-width="6" />
      <path d="M0,0 L60,30 M60,0 L0,30" :clip-path="`url(#${id}-diagonals)`" stroke="#c8102e" stroke-width="4" />
      <path d="M30,0 v30 M0,15 h60" stroke="#ffffff" stroke-width="10" />
      <path d="M30,0 v30 M0,15 h60" stroke="#c8102e" stroke-width="6" />
    </g>
  </svg>
  <svg v-else-if="locale === 'ja'" viewBox="0 0 30 20" preserveAspectRatio="xMidYMid slice" class="h-4 w-6 rounded-sm ring-1 ring-border" aria-hidden="true">
    <rect width="30" height="20" fill="#ffffff" />
    <circle cx="15" cy="10" r="6" fill="#bc002d" />
  </svg>
</template>
