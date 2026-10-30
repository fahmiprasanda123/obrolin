<script setup>
import { computed, ref } from "vue";
import { useWorkspaceStore } from "../stores/workspace";
import ModalDialog from "./ModalDialog.vue";
import AppIcon from "./AppIcon.vue";

const emit = defineEmits(["close", "open"]);
const workspace = useWorkspaceStore();
const filter = ref("");
const busyId = ref(null);
const error = ref("");

const visible = computed(() =>
  workspace.channels.filter((c) => c.name.includes(filter.value.trim().toLowerCase())),
);

async function join(channel) {
  busyId.value = channel.id;
  error.value = "";
  try {
    if (!channel.is_member) await workspace.joinChannel(channel.id);
    emit("open", channel);
  } catch (e) {
    error.value = e.message;
  } finally {
    busyId.value = null;
  }
}
</script>

<template>
  <ModalDialog title="Browse channels" @close="emit('close')">
    <div class="stack">
      <input v-model="filter" type="search" placeholder="Search channels" aria-label="Search channels" />
      <p v-if="error" class="alert" role="alert">{{ error }}</p>
      <ul class="list">
        <li v-for="channel in visible" :key="channel.id" class="row">
          <AppIcon :name="channel.is_private ? 'lock' : 'hash'" :size="16" />
          <div class="row__text">
            <strong>{{ channel.name }}</strong>
            <span class="muted">
              {{ channel.member_count }} {{ channel.member_count === 1 ? "member" : "members" }}
              <template v-if="channel.description"> · {{ channel.description }}</template>
            </span>
          </div>
          <button class="btn" type="button" :disabled="busyId === channel.id" @click="join(channel)">
            {{ channel.is_member ? "Open" : "Join" }}
          </button>
        </li>
        <li v-if="visible.length === 0" class="muted">No channels match "{{ filter }}".</li>
      </ul>
    </div>
  </ModalDialog>
</template>

<style scoped>
.list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 4px;
}

.row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 0;
  border-bottom: 1px solid var(--border);
}

.row__text {
  flex: 1;
  min-width: 0;
  display: grid;
  font-size: 14px;
}

.row__text .muted {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
