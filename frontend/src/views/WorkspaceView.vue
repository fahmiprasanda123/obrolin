<script setup>
import { onBeforeUnmount, onMounted, ref, watch } from "vue";
import { useRoute } from "vue-router";
import { useWorkspaceStore } from "../stores/workspace";
import AppSidebar from "../components/AppSidebar.vue";

const route = useRoute();
const workspace = useWorkspaceStore();
const error = ref("");
const sidebarOpen = ref(false);

watch(
  () => Number(route.params.workspaceId),
  async (id) => {
    error.value = "";
    try {
      await workspace.enterWorkspace(id);
    } catch (e) {
      error.value = e.status === 404 ? "Workspace not found, or you are not a member." : e.message;
    }
  },
  { immediate: true },
);

// Coming back to the tab counts as reading the open channel.
function onVisibility() {
  if (document.visibilityState === "visible" && workspace.activeChannelId) {
    workspace.markRead(workspace.activeChannelId);
  }
}

onMounted(() => document.addEventListener("visibilitychange", onVisibility));
onBeforeUnmount(() => {
  document.removeEventListener("visibilitychange", onVisibility);
  workspace.leaveWorkspace();
});
</script>

<template>
  <main v-if="error" class="page-center">
    <div class="card">
      <p class="alert" role="alert">{{ error }}</p>
      <RouterLink to="/" class="btn">Back to workspaces</RouterLink>
    </div>
  </main>
  <div v-else class="shell" :class="{ 'is-sidebar-open': sidebarOpen }">
    <div class="shell__sidebar">
      <AppSidebar v-if="workspace.current" @navigate="sidebarOpen = false" />
    </div>
    <div class="shell__scrim" @click="sidebarOpen = false" />
    <div class="shell__main">
      <RouterView v-if="workspace.current" @toggle-sidebar="sidebarOpen = !sidebarOpen" />
      <p v-else class="muted shell__loading">Loading workspace…</p>
    </div>
  </div>
</template>

<style scoped>
.shell {
  display: grid;
  grid-template-columns: 260px 1fr;
  height: 100%;
}

.shell__sidebar {
  min-height: 0;
}

.shell__main {
  min-width: 0;
  min-height: 0;
  background: var(--surface);
}

.shell__scrim {
  display: none;
}

.shell__loading {
  padding: 20px;
}

@media (max-width: 760px) {
  .shell {
    grid-template-columns: 1fr;
  }

  .shell__sidebar {
    position: fixed;
    inset: 0 auto 0 0;
    z-index: 40;
    width: min(280px, 85vw);
    transform: translateX(-100%);
    transition: transform 0.2s ease;
  }

  .is-sidebar-open .shell__sidebar {
    transform: none;
  }

  .is-sidebar-open .shell__scrim {
    display: block;
    position: fixed;
    inset: 0;
    z-index: 30;
    background: rgb(10 16 15 / 0.45);
  }
}

@media (prefers-reduced-motion: reduce) {
  .shell__sidebar {
    transition: none;
  }
}
</style>
