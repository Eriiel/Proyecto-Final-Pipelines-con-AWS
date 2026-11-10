import { defineConfig } from "vite";

// En desarrollo local, /api se redirige al backend (uvicorn en el puerto 8000).
// En AWS no hace falta: el ALB envía /api/* directamente al servicio backend.
export default defineConfig({
  server: {
    port: 5173,
    proxy: {
      "/api": "http://localhost:8000",
    },
  },
});
