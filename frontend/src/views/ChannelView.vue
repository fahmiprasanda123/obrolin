<script setup>
import { computed, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useMessagesStore } from "../stores/messages";
import { useWorkspaceStore } from "../stores/workspace";
import { typingText } from "../utils/format";
import AppIcon from "../components/AppIcon.vue";
import MessageComposer from "../components/MessageComposer.vue";
import MessageList from "../components/MessageList.vue";
import MembersPanel from "../components/MembersPanel.vue";
import SearchPanel from "../components/SearchPanel.vue";
import ThreadPanel from "../components/ThreadPanel.vue";

const emit = defineEmits(["toggle-sidebar"]);
const route = useRoute();
const router = useRouter();
const workspace = useWorkspaceStore();
const messages = useMessagesStore();
const panel = ref(null); // "members" | "search" | null (thread uses messages.thread)
const error = ref("");

const channelId = computed(() => Number(route.params.channelId));
const channel = computed(() => workspace.channels.find((c) => c.id === channelId.value) ?? null);
const typing = computed(() => typingText(messages.typingUsers(channelId.value)));
const sidePanel = computed(() => (messages.thread ? "thread" : panel.value));

watch(
  channelId,
  (id) => {
    messages.closeThread();
    workspace.setActiveChannel(id);
  },
  { immediate: true },
);

function openThread(message) {
  panel.value = null;
  messages.openThread(message).catch((e) => (error.value = e.message));
}

function togglePanel(name) {
  messages.closeThread();
  panel.value = panel.value === name ? null : name;
}

async function join() {
  try {
    await workspace.joinChannel(channelId.value);
    workspace.markRead(channelId.value, 0);
  } catch (e) {
    error.value = e.message;
  }
}

async function leave() {
  if (!window.confirm(`Leave #${channel.value.name}?`)) return;
  try {
    await workspace.leaveChannel(channelId.value);
    router.push(`/workspaces/${workspace.current.id}`);
  } catch (e) {
    error.value = e.message;
  }
}
</script>

<template>
  <div v-if="!channel" class="missing">
    <button class="icon-btn menu-btn" type="button" aria-label="Open sidebar" @click="emit('toggle-sidebar')">
      <AppIcon name="menu" />
    </button>
    <p class="muted">This channel does not exist or you do not have access to it.</p>
  </div>

  <div v-else class="channel" :class="{ 'has-panel': sidePanel }">
    <section class="channel__main">
      <header class="channel__header">
        <button class="icon-btn menu-btn" type="button" aria-label="Open sidebar" @click="emit('toggle-sidebar')">
          <AppIcon name="menu" />
        </button>
        <div class="channel__title">
          <h1>
            <AppIcon :name="channel.is_private ? 'lock' : 'hash'" :size="18" />
            {{ channel.name }}
          </h1>
          <p v-if="channel.description" class="muted">{{ channel.description }}</p>
        </div>
        <button
          class="btn channel__members"
          type="button"
          :aria-pressed="panel === 'members'"
          :aria-label="`${channel.member_count} members`"
          @click="togglePanel('members')"
        >
          <AppIcon name="users" :size="16" /> {{ channel.member_count }}
        </button>
        <button class="icon-btn" type="button" aria-label="Search in channel" :aria-pressed="panel === 'search'" @click="togglePanel('search')">
          <AppIcon name="search" />
        </button>
        <button v-if="channel.is_member" class="btn channel__leave" type="button" title="Leave channel" @click="leave">Leave</button>
      </header>

      <p v-if="error" class="alert channel__error" role="alert">{{ error }}</p>

      <MessageList :key="channel.id" :channel-id="channel.id" :channel-name="channel.name" @open-thread="openThread" />

      <div class="channel__typing" aria-live="polite">{{ typing }}</div>

      <MessageComposer v-if="channel.is_member" :key="`composer-${channel.id}`" :channel-id="channel.id" :placeholder="`Message #${channel.name}`" />
      <div v-else class="channel__join">
        <span>You are viewing <strong>#{{ channel.name }}</strong>.</span>
        <button class="btn btn--primary" type="button" @click="join">Join channel</button>
      </div>
    </section>

    <div v-if="sidePanel" class="channel__panel">
      <ThreadPanel v-if="sidePanel === 'thread'" :channel-name="channel.name" />
      <MembersPanel v-else-if="sidePanel === 'members'" :channel="channel" @close="panel = null" />
      <SearchPanel v-else-if="sidePanel === 'search'" :channel="channel" @close="panel = null" />
    </div>
  </div>
</template>

<style scoped>
.channel {
  display: grid;
  grid-template-columns: 1fr;
  height: 100%;
}

.channel.has-panel {
  grid-template-columns: 1fr minmax(320px, 380px);
}

.channel__main {
  display: flex;
  flex-direction: column;
  min-width: 0;
  min-height: 0;
}

.channel__header {
  display: flex;
  align-items: center;
  gap: 6px;
  min-height: 57px;
  padding: 8px 12px 8px 20px;
  border-bottom: 1px solid var(--border);
}

.channel__title {
  flex: 1;
  min-width: 0;
}

.channel__title h1 {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 17px;
}

.channel__title p {
  margin: 0;
  font-size: 13px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.channel__members,
.channel__leave {
  min-height: var(--tap);
  padding: 0 10px;
  font-weight: 500;
}

.channel__error {
  margin: 8px 20px 0;
}

.channel__typing {
  min-height: 20px;
  padding: 0 20px 2px 22px;
  font-size: 12px;
  color: var(--text-muted);
}

.channel__join {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: center;
  gap: 12px;
  margin: 0 20px 16px;
  padding: 14px;
  background: var(--surface-muted);
  border-radius: var(--radius-lg);
}

.channel__panel {
  min-height: 0;
}

.menu-btn {
  display: none;
}

.missing {
  padding: 20px;
}

@media (max-width: 1000px) {
  .channel.has-panel {
    grid-template-columns: 1fr;
  }

  .channel__panel {
    position: fixed;
    inset: 0;
    z-index: 35;
  }
}

@media (max-width: 760px) {
  .menu-btn {
    display: inline-grid;
  }

  .channel__header {
    padding-left: 8px;
  }
}
</style>
