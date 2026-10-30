import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";

// The browser always talks to its own origin (/api, /cable). In development
// Vite proxies those paths to Rails; in Kubernetes the ingress does the same
// job, so the frontend never needs to know where the backend lives.
const apiTarget = process.env.VITE_API_PROXY || "http://localhost:3001";
const cableTarget = process.env.VITE_CABLE_PROXY || apiTarget;

export default defineConfig({
  plugins: [vue()],
  server: {
    host: true,
    port: 5173,
    strictPort: true,
    // Bind mounts on macOS/Windows Docker do not always deliver file events.
    watch: process.env.VITE_USE_POLLING ? { usePolling: true, interval: 300 } : undefined,
    proxy: {
      // xfwd adds X-Forwarded-For so Rails sees the real client IP
      // (rate limiting is keyed by IP).
      "/api": { target: apiTarget, xfwd: true },
      "/cable": { target: cableTarget, ws: true, xfwd: true },
    },
  },
  test: {
    environment: "jsdom",
  },
});
