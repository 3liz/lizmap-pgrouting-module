// vite.config.js
import { resolve } from 'path'
import { defineConfig } from 'vite'

export default defineConfig(({ command, mode, ssrBuild }) => {
  return {
    build: {
      lib: {
        // Could also be a dictionary or array of multiple entry points
        entry: resolve(__dirname, 'pgrouting.js'),
        // the proper extensions will be added
        fileName: 'pgrouting',
        formats: ['umd'],
        name : 'pgrouting'
      },
      outDir: mode === 'prod' ? 'dist' : '../../../tests/lizmap/www/pgrouting/js/',
      sourcemap: true,
      emptyOutDir: true,
    }
  }
})
