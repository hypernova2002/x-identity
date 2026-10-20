<script setup lang="ts">
import TokenConfirmation from '@/components/auth/TokenConfirmation.vue'
import { authService } from '@/services/auth'
</script>

<template>
  <TokenConfirmation
    title="Confirm your new email"
    success-title="Email changed"
    success-message="Your email address has been updated, and you've been signed out everywhere. Sign in with your new address."
    :confirm="authService.confirmEmailChange"
  />
</template>
