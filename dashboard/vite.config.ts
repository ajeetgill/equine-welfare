import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  build: {
    // The built app is served by PocketBase itself (pb_public is auto-served
    // at / with SPA fallback). This directory is gitignored — build artifact.
    outDir: "../pocketbase/pb_public",
    emptyOutDir: true,
  },
});
