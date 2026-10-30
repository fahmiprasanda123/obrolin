<script setup>
import { computed, ref, watch } from "vue";
import { useWorkspaceStore } from "../stores/workspace";
import AppIcon from "./AppIcon.vue";
import UserAvatar from "./UserAvatar.vue";

const props = defineProps({ channel: { type: Object, required: true } });
const emit = defineEmits(["close"]);
const workspace = useWorkspaceStore();
const channelMembers = ref([]);
const loading = ref(true);
const adding = ref("");
const error = ref("");

// Presence comes from the workspace store so dots update live.
const rows = computed(() =>
  channelMembers.value
    .map((m) => ({ ...m, online: workspace.members.find((w) => w.id === m.id)?.online ?? m.online }))
    .sort((a, b) => Number(b.online) - Number(a.online) || a.display_name.localeCompare(b.display_name)),
);
const candidates = computed(() => {
  const ids = new Set(channelMembers.value.map((m) => m.id));
  return workspace.members.filter((m) => !ids.has(m.id));
});

async function load() {
  error.value = "";
  try {
    channelMembers.value = await workspace.fetchChannelMembers(props.channel.id);
  } catch (e) {
    error.value = e.message;
  } finally {
    loading.value = false;
  }
}

async function add() {
  if (!adding.value) return;
  try {
    await workspace.addChannelMember(props.channel.id, Number(adding.value));
    adding.value = "";
    await load();
  } catch (e) {
    error.value = e.message;
  }
}

watch(() => [props.channel.id, props.channel.member_count], load, { immediate: true });
</script>

<template>
  <aside class="panel" aria-label="Channel members">
    <header class="panel__header">
      <div>
        <h2>Members</h2>
        <span class="muted">#{{ channel.name }}</span>
      </div>
      <button class="icon-btn" type="button" aria-label="Close members" @click="emit('close')">
        <AppIcon name="x" />
      </button>
    </header>
    <div class="panel__body members">
      <p v-if="error" class="alert" role="alert">
        {{ error }}
        <button class="btn members__retry" type="button" @click="load">Try again</button>
      </p>
      <p v-if="loading && !channelMembers.length" class="muted" role="status">Loading members…</p>
      <form v-if="channel.is_private && channel.is_member && candidates.length" class="members__add" @submit.prevent="add">
        <label class="visually-hidden" for="add-member">Add a member</label>
        <select id="add-member" v-model="adding" class="members__select">
          <option value="">Add someone…</option>
          <option v-for="m in candidates" :key="m.id" :value="m.id">{{ m.display_name }} (@{{ m.username }})</option>
        </select>
        <button class="btn" type="submit" :disabled="!adding">Add</button>
      </form>
      <ul>
        <li v-for="member in rows" :key="member.id">
          <UserAvatar :user="member" :size="30" :online="member.online" />
          <div>
            <strong>{{ member.display_name }}</strong>
            <span class="muted">@{{ member.username }} · {{ member.online ? "online" : "offline" }}</span>
          </div>
        </li>
      </ul>
    </div>
  </aside>
</template>

<style scoped>
.members {
  padding: 12px 16px;
}

.members ul {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 10px;
}

.members li {
  display: flex;
  align-items: center;
  gap: 10px;
}

.members li div {
  display: grid;
  font-size: 14px;
}

.members__add {
  display: flex;
  gap: 8px;
  margin-bottom: 14px;
}

.members__select {
  flex: 1;
  min-width: 0;
  width: auto;
  min-height: max(38px, var(--tap));
  padding: 7px 8px;
}

.members__retry {
  display: flex;
  margin-top: 8px;
}
</style>
