<script setup lang="ts">
import TokenConfirmation from '@/components/auth/TokenConfirmation.vue'
import { authService } from '@/services/auth'
</script>

<template>
  <TokenConfirmation
    title="Verify your email"
    success-title="Email verified"
    success-message="Thanks for confirming your email address."
    :confirm="authService.confirmEmail"
  />
</template>
