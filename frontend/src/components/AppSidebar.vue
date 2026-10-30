<script setup>
import { ref } from "vue";
import { useRouter } from "vue-router";
import { useAuthStore } from "../stores/auth";
import { useWorkspaceStore } from "../stores/workspace";
import AppIcon from "./AppIcon.vue";
import UserAvatar from "./UserAvatar.vue";
import CreateChannelDialog from "./CreateChannelDialog.vue";
import BrowseChannelsDialog from "./BrowseChannelsDialog.vue";
import InviteDialog from "./InviteDialog.vue";
import ProfileDialog from "./ProfileDialog.vue";

const emit = defineEmits(["navigate"]);
const auth = useAuthStore();
const workspace = useWorkspaceStore();
const router = useRouter();
const dialog = ref(null); // "create" | "browse" | "invite" | "profile"

function channelLink(channel) {
  return `/workspaces/${workspace.current.id}/channels/${channel.id}`;
}

async function logout() {
  workspace.resetSession();
  await auth.logout();
  router.push("/login");
}

function onChannelCreated(channel) {
  dialog.value = null;
  router.push(channelLink(channel));
  emit("navigate");
}
</script>

<template>
  <nav class="sidebar" aria-label="Workspace navigation">
    <header class="sidebar__header">
      <RouterLink to="/" class="sidebar__workspace" title="Switch workspace">
        {{ workspace.current?.name }}
      </RouterLink>
      <button
        v-if="workspace.isManager"
        class="sidebar__icon"
        type="button"
        title="Invite people"
        aria-label="Invite people"
        @click="dialog = 'invite'"
      >
        <AppIcon name="mail" />
      </button>
    </header>

    <div class="sidebar__scroll">
      <section>
        <div class="sidebar__section-title">
          <span>Channels</span>
          <button class="sidebar__icon" type="button" aria-label="Create channel" title="Create channel" @click="dialog = 'create'">
            <AppIcon name="plus" :size="16" />
          </button>
        </div>
        <ul class="sidebar__list">
          <li v-for="channel in workspace.joinedChannels" :key="channel.id">
            <RouterLink
              :to="channelLink(channel)"
              class="sidebar__item"
              :class="{ 'is-unread': channel.unread_count > 0 }"
              @click="emit('navigate')"
            >
              <AppIcon :name="channel.is_private ? 'lock' : 'hash'" :size="15" />
              <span class="sidebar__label">{{ channel.name }}</span>
              <span v-if="channel.unread_count > 0" class="sidebar__badge" :aria-label="`${channel.unread_count} unread`">
                {{ channel.unread_count > 99 ? "99+" : channel.unread_count }}
              </span>
            </RouterLink>
          </li>
        </ul>
        <button class="sidebar__item sidebar__item--action" type="button" @click="dialog = 'browse'">
          <AppIcon name="search" :size="15" />
          <span>Browse channels</span>
        </button>
      </section>

      <section>
        <div class="sidebar__section-title"><span>Members</span></div>
        <ul class="sidebar__list">
          <li v-for="member in workspace.sortedMembers" :key="member.id" class="sidebar__member">
            <UserAvatar :user="member" :size="22" :online="member.online" />
            <span class="sidebar__label">{{ member.display_name }}</span>
            <span class="visually-hidden">{{ member.online ? "online" : "offline" }}</span>
          </li>
        </ul>
      </section>
    </div>

    <footer class="sidebar__footer">
      <button class="sidebar__profile" type="button" title="Edit your profile" @click="dialog = 'profile'">
        <UserAvatar :user="auth.user" :size="30" />
        <span class="sidebar__me">
          <strong>{{ auth.user?.display_name }}</strong>
          <span v-if="workspace.cableServer" class="sidebar__cable" title="ActionCable server handling this tab's WebSocket">
            cable: {{ workspace.cableServer }}
          </span>
        </span>
      </button>
      <button class="sidebar__icon" type="button" aria-label="Sign out" title="Sign out" @click="logout">
        <AppIcon name="logout" />
      </button>
    </footer>

    <CreateChannelDialog v-if="dialog === 'create'" @close="dialog = null" @created="onChannelCreated" />
    <BrowseChannelsDialog v-if="dialog === 'browse'" @close="dialog = null" @open="onChannelCreated" />
    <InviteDialog v-if="dialog === 'invite'" @close="dialog = null" />
    <ProfileDialog v-if="dialog === 'profile'" @close="dialog = null" />
  </nav>
</template>

<style scoped>
.sidebar {
  /* The sidebar is dark in both themes, so it brings its own focus and presence colors. */
  --focus: var(--sidebar-text-strong);
  --presence-ring: var(--sidebar-bg);
  --presence-online: #4cc184;
  --presence-offline: var(--sidebar-text);
  display: flex;
  flex-direction: column;
  height: 100%;
  background: var(--sidebar-bg);
  color: var(--sidebar-text);
}

.sidebar__header {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 14px 12px 12px 16px;
  border-bottom: 1px solid var(--sidebar-hover);
}

.sidebar__workspace {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--sidebar-text-strong);
  font-weight: 700;
  font-size: 17px;
  line-height: var(--tap);
  text-decoration: none;
}

.sidebar__icon {
  display: inline-grid;
  place-items: center;
  flex: none;
  width: var(--tap);
  height: var(--tap);
  border: 0;
  border-radius: var(--radius);
  background: transparent;
  color: var(--sidebar-text);
  cursor: pointer;
}

.sidebar__icon:hover {
  background: var(--sidebar-hover);
  color: var(--sidebar-text-strong);
}

.sidebar__scroll {
  flex: 1;
  overflow-y: auto;
  padding: 10px 8px;
  display: grid;
  align-content: start;
  gap: 18px;
}

.sidebar__section-title {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 4px 4px 8px;
  font-size: 13px;
  font-weight: 600;
}

.sidebar__list {
  list-style: none;
  margin: 0;
  padding: 0;
}

.sidebar__item {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
  min-height: var(--tap);
  padding: 4px 8px;
  border: 0;
  border-radius: var(--radius);
  background: none;
  color: inherit;
  font: inherit;
  font-size: 15px;
  text-decoration: none;
  cursor: pointer;
}

.sidebar__item:hover {
  background: var(--sidebar-hover);
}

.sidebar__item.router-link-active {
  background: var(--sidebar-active);
  color: var(--sidebar-text-strong);
}

.sidebar__item.is-unread {
  color: var(--sidebar-text-strong);
  font-weight: 700;
}

.sidebar__item--action {
  opacity: 0.85;
}

.sidebar__label {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  text-align: left;
}

.sidebar__badge {
  min-width: 20px;
  padding: 0 6px;
  border-radius: 10px;
  background: var(--accent);
  color: var(--accent-text);
  font-size: 12px;
  font-weight: 700;
  line-height: 20px;
  text-align: center;
}

.sidebar__member {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 4px 8px;
  font-size: 14px;
}

.sidebar__footer {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 10px 10px 10px 14px;
  border-top: 1px solid var(--sidebar-hover);
}

.sidebar__profile {
  flex: 1;
  min-width: 0;
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: var(--tap);
  padding: 4px;
  margin: -4px;
  border: 0;
  border-radius: var(--radius);
  background: none;
  color: inherit;
  font: inherit;
  text-align: left;
  cursor: pointer;
}

.sidebar__profile:hover {
  background: var(--sidebar-hover);
}

.sidebar__me {
  flex: 1;
  min-width: 0;
  display: grid;
  font-size: 14px;
  color: var(--sidebar-text-strong);
}

.sidebar__cable {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-family: var(--mono);
  font-size: 11px;
  color: var(--sidebar-text);
}
</style>
