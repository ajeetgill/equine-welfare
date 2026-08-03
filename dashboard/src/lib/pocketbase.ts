import PocketBase from "pocketbase";

let client: PocketBase | null = null;

// Same-origin in production (the app is served from PocketBase's pb_public);
// VITE_POCKETBASE_URL is only for the Vite dev server on its own port.
// Auth persists via the SDK's default localStorage store.
export function getPocketBase(): PocketBase {
  if (!client) {
    client = new PocketBase(import.meta.env.VITE_POCKETBASE_URL || "/");
  }
  return client;
}
