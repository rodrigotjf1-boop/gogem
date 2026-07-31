/// <reference types="vitest/config" />
import { fileURLToPath, URL } from 'node:url';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    port: 5173,
  },
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./test/setup.ts'],
    css: true,
    include: ['test/**/*.{test,spec}.{ts,tsx}', 'src/**/*.{test,spec}.{ts,tsx}'],
    // Os testes montam o App inteiro com um MSW server COMPARTILHADO; sob
    // paralelismo de arquivos, requisições em voo de um arquivo colidem com o
    // resetHandlers de outro (unhandled request → erro intermitente no CI).
    // Rodar os arquivos em série elimina a corrida (suíte pequena; custo baixo).
    fileParallelism: false,
  },
});
