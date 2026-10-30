<script setup>
import { ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useAuthStore } from "../stores/auth";

const auth = useAuthStore();
const router = useRouter();
const route = useRoute();
const login = ref("");
const password = ref("");
const error = ref("");
const loading = ref(false);

async function submit() {
  loading.value = true;
  error.value = "";
  try {
    await auth.login(login.value, password.value);
    router.replace(route.query.redirect || "/");
  } catch (e) {
    error.value = e.message;
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <main class="page-center">
    <div class="card">
      <div class="brand"><img src="/favicon.svg" alt="" /> Obrolin</div>
      <h1 class="title">Sign in</h1>
      <form class="stack" @submit.prevent="submit">
        <p v-if="error" class="alert" role="alert">{{ error }}</p>
        <div class="field">
          <label for="login">Email or username</label>
          <input id="login" v-model="login" type="text" autocomplete="username" required autofocus />
        </div>
        <div class="field">
          <label for="password">Password</label>
          <input id="password" v-model="password" type="password" autocomplete="current-password" required />
        </div>
        <button class="btn btn--primary btn--block" type="submit" :disabled="loading">
          {{ loading ? "Signing in…" : "Sign in" }}
        </button>
      </form>
      <p class="muted footnote">
        New here? <RouterLink :to="{ path: '/register', query: route.query }">Create an account</RouterLink>
      </p>
      <p class="muted footnote">Demo accounts: alice, budi, citra and dimas. The password for each is <code>password123</code>.</p>
    </div>
  </main>
</template>

<style scoped>
.title {
  font-size: 22px;
  margin-bottom: 18px;
}

.footnote {
  margin: 16px 0 0;
  font-size: 14px;
}
</style>
