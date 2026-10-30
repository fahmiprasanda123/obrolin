<script setup>
import { watchEffect } from "vue";
import { useRouter } from "vue-router";
import { useWorkspaceStore } from "../stores/workspace";

// /workspaces/:id lands on #general (or the first joined channel).
const workspace = useWorkspaceStore();
const router = useRouter();

watchEffect(() => {
  if (!workspace.current) return;
  const target = workspace.joinedChannels.find((c) => c.name === "general") ?? workspace.joinedChannels[0];
  if (target) router.replace(`/workspaces/${workspace.current.id}/channels/${target.id}`);
});
</script>

<template>
  <p class="muted" style="padding: 20px">
    You have not joined any channel yet. Use "Browse channels" in the sidebar to find one.
  </p>
</template>
