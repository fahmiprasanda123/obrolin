<script setup>
import { reactive, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useAuthStore } from "../stores/auth";

const auth = useAuthStore();
const router = useRouter();
const route = useRoute();
const form = reactive({ display_name: "", username: "", email: "", password: "" });
const fieldErrors = ref({});
const error = ref("");
const loading = ref(false);

async function submit() {
  loading.value = true;
  error.value = "";
  fieldErrors.value = {};
  try {
    await auth.register({ ...form });
    router.replace(route.query.redirect || "/");
  } catch (e) {
    fieldErrors.value = e.fieldErrors ?? {};
    if (!Object.keys(fieldErrors.value).length) error.value = e.message;
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <main class="page-center">
    <div class="card">
      <div class="brand"><img src="/favicon.svg" alt="" /> Obrolin</div>
      <h1 class="title">Create your account</h1>
      <form class="stack" novalidate @submit.prevent="submit">
        <p v-if="error" class="alert" role="alert">{{ error }}</p>
        <div class="field">
          <label for="display_name">Full name</label>
          <input id="display_name" v-model="form.display_name" type="text" autocomplete="name" required />
          <span v-for="msg in fieldErrors.display_name" :key="msg" class="error">{{ msg }}</span>
        </div>
        <div class="field">
          <label for="username">Username</label>
          <input id="username" v-model="form.username" type="text" autocomplete="username" required />
          <span class="hint">Used for @mentions. Lowercase letters, numbers and _.</span>
          <span v-for="msg in fieldErrors.username" :key="msg" class="error">{{ msg }}</span>
        </div>
        <div class="field">
          <label for="email">Email</label>
          <input id="email" v-model="form.email" type="email" autocomplete="email" required />
          <span v-for="msg in fieldErrors.email" :key="msg" class="error">{{ msg }}</span>
        </div>
        <div class="field">
          <label for="password">Password</label>
          <input id="password" v-model="form.password" type="password" autocomplete="new-password" required />
          <span class="hint">At least 8 characters.</span>
          <span v-for="msg in fieldErrors.password" :key="msg" class="error">{{ msg }}</span>
        </div>
        <button class="btn btn--primary btn--block" type="submit" :disabled="loading">
          {{ loading ? "Creating account…" : "Create account" }}
        </button>
      </form>
      <p class="muted footnote">
        Already have an account? <RouterLink :to="{ path: '/login', query: route.query }">Sign in</RouterLink>
      </p>
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
