import { defineStore } from "pinia";
import { computed, ref } from "vue";
import { api } from "../api/client";
import { getConsumer } from "../api/cable";
import { useAuthStore } from "./auth";
import { useMessagesStore } from "./messages";

const HEARTBEAT_MS = 30000;
const MARK_READ_DELAY_MS = 600;

export const useWorkspaceStore = defineStore("workspace", () => {
  const auth = useAuthStore();
  const messages = useMessagesStore();

  const workspaces = ref([]);
  const current = ref(null);
  const channels = ref([]);
  const members = ref([]);
  const activeChannelId = ref(null);
  const cableServer = ref(null);
  const toasts = ref([]);

  const conversationSubs = new Map();
  const markReadTimers = new Map();
  let presenceSub = null;
  let notificationsSub = null;
  let heartbeatTimer = null;

  const joinedChannels = computed(() => channels.value.filter((c) => c.is_member));
  const activeChannel = computed(() => channels.value.find((c) => c.id === activeChannelId.value) ?? null);
  const isManager = computed(() => ["owner", "admin"].includes(current.value?.role));
  const usernames = computed(() => new Set(members.value.map((m) => m.username)));
  const sortedMembers = computed(() =>
    [...members.value].sort((a, b) => Number(b.online) - Number(a.online) || a.display_name.localeCompare(b.display_name)),
  );

  async function fetchWorkspaces() {
    workspaces.value = await api("/workspaces");
    return workspaces.value;
  }

  async function createWorkspace(name) {
    const workspace = await api("/workspaces", { method: "POST", body: { workspace: { name } } });
    workspaces.value.push(workspace);
    return workspace;
  }

  async function enterWorkspace(id) {
    if (current.value?.id === id) return;
    leaveWorkspace();
    const [workspace, channelList, memberList] = await Promise.all([
      api(`/workspaces/${id}`),
      api(`/workspaces/${id}/channels`),
      api(`/workspaces/${id}/members`),
    ]);
    current.value = workspace;
    channels.value = channelList;
    members.value = memberList;
    subscribeNotifications();
    subscribePresence(id);
    joinedChannels.value.forEach((c) => subscribeConversation(c.id));
  }

  function leaveWorkspace() {
    conversationSubs.forEach((sub) => sub.unsubscribe());
    conversationSubs.clear();
    presenceSub?.unsubscribe();
    presenceSub = null;
    clearInterval(heartbeatTimer);
    current.value = null;
    channels.value = [];
    members.value = [];
    activeChannelId.value = null;
    messages.reset();
  }

  // Called on logout: the cable connection itself is closed by the auth store.
  function resetSession() {
    leaveWorkspace();
    notificationsSub = null;
    workspaces.value = [];
    cableServer.value = null;
    toasts.value = [];
  }

  // ---- Real-time subscriptions -------------------------------------------

  function subscribeConversation(channelId) {
    const consumer = getConsumer();
    if (!consumer || conversationSubs.has(channelId)) return;
    const sub = consumer.subscriptions.create(
      { channel: "ConversationChannel", channel_id: channelId },
      { received: (data) => handleConversationEvent(channelId, data) },
    );
    conversationSubs.set(channelId, sub);
  }

  function unsubscribeConversation(channelId) {
    conversationSubs.get(channelId)?.unsubscribe();
    conversationSubs.delete(channelId);
  }

  function sendTyping(channelId) {
    conversationSubs.get(channelId)?.perform("typing");
  }

  function handleConversationEvent(channelId, data) {
    switch (data.type) {
      case "subscribed":
        cableServer.value = data.server;
        break;
      case "message.created": {
        messages.upsert(data.message);
        const mine = data.message.user?.id === auth.user?.id;
        if (data.message.parent_message_id || mine) break;
        if (channelId === activeChannelId.value && document.visibilityState === "visible") {
          markRead(channelId);
        } else {
          const channel = channels.value.find((c) => c.id === channelId);
          if (channel) channel.unread_count += 1;
        }
        break;
      }
      case "message.updated":
      case "message.deleted":
        messages.upsert(data.message);
        break;
      case "thread.updated":
        messages.updateThreadMeta(data);
        break;
      case "typing":
        if (data.user.id !== auth.user?.id) messages.setTyping(channelId, data.user);
        break;
      case "member.joined":
      case "member.left": {
        const channel = channels.value.find((c) => c.id === channelId);
        if (channel) channel.member_count += data.type === "member.joined" ? 1 : -1;
        break;
      }
      case "channel.updated":
        refreshChannel(channelId);
        break;
    }
  }

  function subscribePresence(workspaceId) {
    const consumer = getConsumer();
    if (!consumer) return;
    presenceSub = consumer.subscriptions.create(
      { channel: "PresenceChannel", workspace_id: workspaceId },
      {
        // Our own "came online" broadcast usually fires before this
        // subscription exists, and the member list may have been fetched
        // before the socket connected. Being subscribed means we are online.
        connected: () => {
          const me = members.value.find((m) => m.id === auth.user?.id);
          if (me) me.online = true;
        },
        received: (data) => {
          const member = members.value.find((m) => m.id === data.user_id);
          if (member) member.online = data.online;
        },
      },
    );
    // Keeps this connection's presence entry fresh in Redis (see Presence TTL).
    heartbeatTimer = setInterval(() => presenceSub?.perform("heartbeat"), HEARTBEAT_MS);
  }

  function subscribeNotifications() {
    const consumer = getConsumer();
    if (!consumer || notificationsSub) return;
    notificationsSub = consumer.subscriptions.create(
      { channel: "NotificationsChannel" },
      {
        received: (data) => {
          if (data.type !== "mention") return;
          if (data.channel.id === activeChannelId.value && document.visibilityState === "visible") return;
          pushToast({
            title: `${data.message.user?.display_name ?? "Someone"} mentioned you in #${data.channel.name}`,
            body: data.message.body,
            to: `/workspaces/${data.workspace_id}/channels/${data.channel.id}`,
          });
        },
      },
    );
  }

  // ---- Channels ----------------------------------------------------------

  function replaceChannel(updated) {
    const index = channels.value.findIndex((c) => c.id === updated.id);
    if (index === -1) channels.value.push(updated);
    else channels.value[index] = updated;
    channels.value.sort((a, b) => a.name.localeCompare(b.name));
  }

  async function refreshChannel(channelId) {
    replaceChannel(await api(`/channels/${channelId}`));
  }

  async function createChannel(fields, memberIds = []) {
    const channel = await api(`/workspaces/${current.value.id}/channels`, {
      method: "POST",
      body: { channel: fields, member_ids: memberIds },
    });
    replaceChannel(channel);
    subscribeConversation(channel.id);
    return channel;
  }

  async function joinChannel(channelId) {
    replaceChannel(await api(`/channels/${channelId}/join`, { method: "POST" }));
    subscribeConversation(channelId);
  }

  async function leaveChannel(channelId) {
    await api(`/channels/${channelId}/leave`, { method: "DELETE" });
    unsubscribeConversation(channelId);
    const channel = channels.value.find((c) => c.id === channelId);
    if (!channel) return;
    if (channel.is_private) channels.value = channels.value.filter((c) => c.id !== channelId);
    else Object.assign(channel, { is_member: false, unread_count: 0, member_count: channel.member_count - 1 });
  }

  function setActiveChannel(channelId) {
    activeChannelId.value = channelId;
    if (channelId && activeChannel.value?.is_member) markRead(channelId, 0);
  }

  // Debounced so a burst of incoming messages results in one request.
  function markRead(channelId, delay = MARK_READ_DELAY_MS) {
    const channel = channels.value.find((c) => c.id === channelId);
    if (!channel?.is_member) return;
    channel.unread_count = 0;
    clearTimeout(markReadTimers.get(channelId));
    markReadTimers.set(
      channelId,
      setTimeout(() => api(`/channels/${channelId}/read`, { method: "POST" }).catch(() => {}), delay),
    );
  }

  // ---- Members & invitations ---------------------------------------------

  function fetchChannelMembers(channelId) {
    return api(`/channels/${channelId}/members`);
  }

  async function addChannelMember(channelId, userId) {
    await api(`/channels/${channelId}/members`, { method: "POST", body: { user_id: userId } });
  }

  function fetchInvitations() {
    return api(`/workspaces/${current.value.id}/invitations`);
  }

  function invite(email) {
    return api(`/workspaces/${current.value.id}/invitations`, { method: "POST", body: { email } });
  }

  function revokeInvitation(id) {
    return api(`/workspaces/${current.value.id}/invitations/${id}`, { method: "DELETE" });
  }

  // ---- Toasts --------------------------------------------------------------

  let toastId = 0;
  function pushToast(toast) {
    const id = ++toastId;
    toasts.value.push({ id, ...toast });
    setTimeout(() => dismissToast(id), 8000);
  }

  function dismissToast(id) {
    toasts.value = toasts.value.filter((t) => t.id !== id);
  }

  return {
    workspaces,
    current,
    channels,
    members,
    sortedMembers,
    usernames,
    activeChannelId,
    activeChannel,
    joinedChannels,
    isManager,
    cableServer,
    toasts,
    fetchWorkspaces,
    createWorkspace,
    enterWorkspace,
    leaveWorkspace,
    resetSession,
    sendTyping,
    createChannel,
    joinChannel,
    leaveChannel,
    setActiveChannel,
    markRead,
    fetchChannelMembers,
    addChannelMember,
    fetchInvitations,
    invite,
    revokeInvitation,
    pushToast,
    dismissToast,
  };
});
