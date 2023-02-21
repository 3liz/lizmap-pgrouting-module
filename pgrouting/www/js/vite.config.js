// vite.config.js
import { resolve } from 'path'
import { defineConfig } from 'vite'

export default defineConfig({
  build: {
    lib: {
      // Could also be a dictionary or array of multiple entry points
      entry: resolve(__dirname, 'pgrouting.js'),
      // the proper extensions will be added
      fileName: 'pgrouting',
      formats: ['es'],
    },
    outDir: '../../../tests/lizmap/www/assets/pgrouting/js/',
    sourcemap: true,
    emptyOutDir: true,
  },
})
