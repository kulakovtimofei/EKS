import { defineConfig } from 'vite';

// Relative base so the build works on GitHub Pages under /EKS/ or any sub-path.
export default defineConfig({
  base: './',
  build: { chunkSizeWarningLimit: 800 },
});
