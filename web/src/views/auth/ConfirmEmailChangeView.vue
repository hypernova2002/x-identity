<script setup lang="ts">
import TokenConfirmation from '@/components/auth/TokenConfirmation.vue'
import { authService } from '@/services/auth'
</script>

<template>
  <TokenConfirmation
    :title="$t('auth.confirmEmailChange.title')"
    :success-title="$t('auth.confirmEmailChange.successTitle')"
    :success-message="$t('auth.confirmEmailChange.successMessage')"
    :confirm="authService.confirmEmailChange"
  />
</template>
