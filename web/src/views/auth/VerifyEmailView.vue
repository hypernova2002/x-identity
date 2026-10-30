<script setup lang="ts">
import TokenConfirmation from '@/components/auth/TokenConfirmation.vue'
import { authService } from '@/services/auth'
</script>

<template>
  <TokenConfirmation
    :title="$t('auth.verifyEmail.title')"
    :success-title="$t('auth.verifyEmail.successTitle')"
    :success-message="$t('auth.verifyEmail.successMessage')"
    :confirm="authService.confirmEmail"
  />
</template>
