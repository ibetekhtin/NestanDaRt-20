import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
// base управляется через VITE_BASE: '/hq/' для деплоя на nestandart.online/hq/,
// '/' для отдельного сабдомена (hq.nestandart.online).
export default defineConfig({
  base: process.env.VITE_BASE || '/',
  plugins: [react()],
})
