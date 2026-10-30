<script setup>
import { onMounted, ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { api } from "../api/client";
import { useAuthStore } from "../stores/auth";

const route = useRoute();
const router = useRouter();
const auth = useAuthStore();
const invitation = ref(null);
const error = ref("");
const accepting = ref(false);
const redirect = { redirect: route.fullPath };

onMounted(async () => {
  try {
    invitation.value = await api(`/invitations/${route.params.token}`);
  } catch (e) {
    error.value = e.status === 404 ? "This invitation link is not valid." : e.message;
  }
});

async function accept() {
  accepting.value = true;
  error.value = "";
  try {
    const workspace = await api(`/invitations/${route.params.token}/accept`, { method: "POST" });
    router.replace(`/workspaces/${workspace.id}`);
  } catch (e) {
    error.value = e.message;
  } finally {
    accepting.value = false;
  }
}
</script>

<template>
  <main class="page-center">
    <div class="card">
      <div class="brand"><img src="/favicon.svg" alt="" /> Obrolin</div>
      <p v-if="error" class="alert" role="alert">{{ error }}</p>
      <p v-if="!invitation && !error" class="muted">Loading invitation…</p>
      <div v-if="invitation" class="stack">
        <h1 class="title">Join {{ invitation.workspace.name }}</h1>
        <p class="muted">
          {{ invitation.inviter.display_name }} invited <strong>{{ invitation.email }}</strong> to this workspace.
        </p>
        <p v-if="invitation.status !== 'pending'" class="alert">This invitation is {{ invitation.status }}.</p>
        <template v-else-if="auth.isAuthenticated">
          <p v-if="auth.user && auth.user.email !== invitation.email" class="muted">
            You are signed in as {{ auth.user.email }}. Sign in with {{ invitation.email }} to accept.
          </p>
          <button class="btn btn--primary btn--block" type="button" :disabled="accepting" @click="accept">
            {{ accepting ? "Joining…" : "Accept invitation" }}
          </button>
        </template>
        <template v-else>
          <RouterLink class="btn btn--primary btn--block" :to="{ path: '/register', query: redirect }">Create an account</RouterLink>
          <RouterLink class="btn btn--block" :to="{ path: '/login', query: redirect }">I already have an account</RouterLink>
        </template>
      </div>
    </div>
  </main>
</template>

<style scoped>
.title {
  font-size: 22px;
}

.stack p {
  margin: 0;
}
</style>
