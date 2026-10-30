<script setup>
import { onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import { useAuthStore } from "../stores/auth";
import { useWorkspaceStore } from "../stores/workspace";

const auth = useAuthStore();
const workspace = useWorkspaceStore();
const router = useRouter();
const name = ref("");
const error = ref("");
const loading = ref(true);
const creating = ref(false);

onMounted(async () => {
  try {
    await workspace.fetchWorkspaces();
  } catch (e) {
    error.value = e.message;
  } finally {
    loading.value = false;
  }
});

async function create() {
  creating.value = true;
  error.value = "";
  try {
    const created = await workspace.createWorkspace(name.value);
    router.push(`/workspaces/${created.id}`);
  } catch (e) {
    error.value = e.message;
  } finally {
    creating.value = false;
  }
}

async function logout() {
  workspace.resetSession();
  await auth.logout();
  router.push("/login");
}
</script>

<template>
  <main class="page-center">
    <div class="card card--wide">
      <div class="top">
        <div class="brand"><img src="/favicon.svg" alt="" /> Obrolin</div>
        <button class="btn" type="button" @click="logout">Sign out</button>
      </div>
      <h1 class="title">Hi {{ auth.user?.display_name }}, pick a workspace</h1>
      <p v-if="error" class="alert" role="alert">{{ error }}</p>
      <p v-if="loading" class="muted">Loading workspaces…</p>
      <ul v-else-if="workspace.workspaces.length" class="workspaces">
        <li v-for="w in workspace.workspaces" :key="w.id">
          <RouterLink :to="`/workspaces/${w.id}`" class="workspace">
            <span class="workspace__mark" aria-hidden="true">{{ w.name.slice(0, 1).toUpperCase() }}</span>
            <span class="workspace__text">
              <strong>{{ w.name }}</strong>
              <span class="muted">{{ w.slug }} · {{ w.role }}</span>
            </span>
          </RouterLink>
        </li>
      </ul>
      <p v-else class="muted">
        You are not in any workspace yet. Create one below, or open an invitation link you received by email.
      </p>

      <form class="create" @submit.prevent="create">
        <h2>Create a workspace</h2>
        <div class="create__row">
          <label class="visually-hidden" for="workspace-name">Workspace name</label>
          <input id="workspace-name" v-model="name" type="text" required maxlength="80" placeholder="e.g. Design Studio" />
          <button class="btn btn--primary" type="submit" :disabled="creating || !name.trim()">
            {{ creating ? "Creating…" : "Create" }}
          </button>
        </div>
        <p class="muted hint">You become the owner. #general and #random are created for you.</p>
      </form>
    </div>
  </main>
</template>

<style scoped>
.top {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
}

.title {
  font-size: 20px;
  margin-bottom: 16px;
}

.workspaces {
  list-style: none;
  margin: 0 0 8px;
  padding: 0;
  display: grid;
  gap: 8px;
}

.workspace {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 12px;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  color: var(--text);
  text-decoration: none;
}

.workspace:hover {
  background: var(--surface-muted);
}

.workspace__mark {
  display: grid;
  place-items: center;
  width: 38px;
  height: 38px;
  border-radius: var(--radius);
  background: var(--sidebar-bg);
  color: var(--sidebar-text-strong);
  font-weight: 700;
}

.workspace__text {
  display: grid;
}

.workspace__text .muted {
  font-size: 13px;
}

.create {
  margin-top: 24px;
  padding-top: 20px;
  border-top: 1px solid var(--border);
}

.create h2 {
  font-size: 16px;
  margin-bottom: 10px;
}

.create__row {
  display: flex;
  gap: 8px;
}

.hint {
  font-size: 13px;
  margin: 8px 0 0;
}
</style>
