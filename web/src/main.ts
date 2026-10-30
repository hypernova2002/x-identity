import './assets/main.css'

import { createApp } from 'vue'
import { createPinia } from 'pinia'
import OpenVue from 'openvue/config'
import ConfirmationService from 'openvue/confirmationservice'

import App from './App.vue'
import { i18n } from './i18n'
import router from './router'

const app = createApp(App)

app.use(i18n)
app.use(createPinia())
app.use(router)
app.use(OpenVue, { unstyled: true })
app.use(ConfirmationService)

app.mount('#app')
