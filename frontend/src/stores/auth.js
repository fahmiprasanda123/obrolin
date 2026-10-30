import { defineStore } from "pinia";
import { computed, ref } from "vue";
import { api, configureApi } from "../api/client";
import { connectCable, disconnectCable } from "../api/cable";
import { storage } from "../utils/storage";

const TOKEN_KEY = "obrolin.token";

export const useAuthStore = defineStore("auth", () => {
  const token = ref(storage.get(TOKEN_KEY));
  const user = ref(null);
  const isAuthenticated = computed(() => Boolean(token.value));

  configureApi({
    getToken: () => token.value,
    onUnauthorized: () => clearSession(),
  });

  function setSession(data) {
    token.value = data.token;
    user.value = data.user;
    storage.set(TOKEN_KEY, data.token);
    connectCable(data.token);
  }

  function clearSession() {
    token.value = null;
    user.value = null;
    storage.remove(TOKEN_KEY);
    disconnectCable();
  }

  async function login(login, password) {
    setSession(await api("/auth/login", { method: "POST", body: { login, password } }));
  }

  async function register(fields) {
    setSession(await api("/auth/register", { method: "POST", body: { user: fields } }));
  }

  // Restores the session after a page reload. Returns false if the stored
  // token is no longer valid.
  async function restore() {
    if (!token.value) return false;
    if (user.value) return true;
    try {
      user.value = await api("/me");
      connectCable(token.value);
      return true;
    } catch {
      clearSession();
      return false;
    }
  }

  async function logout() {
    try {
      await api("/auth/logout", { method: "DELETE" });
    } catch {
      /* the token is dropped locally either way */
    }
    clearSession();
  }

  // fields: { display_name } and/or { password, current_password }
  async function updateProfile(fields) {
    user.value = await api("/me", { method: "PATCH", body: { user: fields } });
    return user.value;
  }

  return { token, user, isAuthenticated, login, register, restore, logout, clearSession, updateProfile };
});
