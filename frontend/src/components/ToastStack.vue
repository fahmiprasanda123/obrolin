<script setup>
import { useRouter } from "vue-router";
import { useWorkspaceStore } from "../stores/workspace";

const workspace = useWorkspaceStore();
const router = useRouter();

function open(toast) {
  workspace.dismissToast(toast.id);
  router.push(toast.to);
}
</script>

<template>
  <div class="toasts" aria-live="polite">
    <div v-for="toast in workspace.toasts" :key="toast.id" class="toast">
      <button class="toast__main" type="button" @click="open(toast)">
        <strong>{{ toast.title }}</strong>
        <span v-if="toast.body" class="toast__body">{{ toast.body }}</span>
      </button>
      <button class="icon-btn" type="button" aria-label="Dismiss" @click="workspace.dismissToast(toast.id)">×</button>
    </div>
  </div>
</template>

<style scoped>
.toasts {
  position: fixed;
  right: 16px;
  bottom: 16px;
  z-index: 60;
  display: grid;
  gap: 8px;
  width: min(360px, calc(100vw - 32px));
}

.toast {
  display: flex;
  align-items: flex-start;
  gap: 4px;
  padding: 10px 6px 10px 14px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  box-shadow: var(--shadow-pop);
}

.toast__main {
  flex: 1;
  display: grid;
  gap: 2px;
  text-align: left;
  font: inherit;
  font-size: 14px;
  color: var(--text);
  background: none;
  border: 0;
  padding: 0;
  cursor: pointer;
}

.toast__body {
  color: var(--text-muted);
  overflow: hidden;
  text-overflow: ellipsis;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}
</style>
