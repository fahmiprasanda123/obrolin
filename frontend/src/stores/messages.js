import { defineStore } from "pinia";
import { reactive, ref } from "vue";
import { api } from "../api/client";

const TYPING_TIMEOUT_MS = 4000;

function createBucket() {
  // messages are kept oldest -> newest for rendering.
  return { messages: [], nextCursor: null, loaded: false, loadingOlder: false };
}

// A deleted top-level message stays visible (as a placeholder) only while it
// has replies, mirroring the API.
function shouldHide(message) {
  return Boolean(message.deleted_at) && !(message.reply_count > 0 && !message.parent_message_id);
}

function upsertInto(list, message) {
  const index = list.findIndex((m) => m.id === message.id);
  if (shouldHide(message)) {
    if (index !== -1) list.splice(index, 1);
    return;
  }
  if (index !== -1) {
    list[index] = message;
    return;
  }
  // Usually the newest; walk back in case events arrive out of order.
  let position = list.length;
  while (position > 0 && list[position - 1].created_at > message.created_at) position -= 1;
  list.splice(position, 0, message);
}

export const useMessagesStore = defineStore("messages", () => {
  const byChannel = reactive({});
  const typing = reactive({}); // channelId -> { userId: { user, timer } }
  const thread = ref(null); // { parent, replies, loading }

  function bucket(channelId) {
    if (!byChannel[channelId]) byChannel[channelId] = createBucket();
    return byChannel[channelId];
  }

  async function loadInitial(channelId) {
    const b = bucket(channelId);
    if (b.loaded) return;
    const data = await api(`/channels/${channelId}/messages`);
    b.messages = data.messages.slice().reverse();
    b.nextCursor = data.next_cursor;
    b.loaded = true;
  }

  // Cursor pagination: ask for messages older than the oldest we have.
  // Returns the number of messages prepended.
  async function loadOlder(channelId) {
    const b = bucket(channelId);
    if (!b.nextCursor || b.loadingOlder) return 0;
    b.loadingOlder = true;
    try {
      const data = await api(`/channels/${channelId}/messages`, { params: { before: b.nextCursor } });
      const known = new Set(b.messages.map((m) => m.id));
      const older = data.messages.slice().reverse().filter((m) => !known.has(m.id));
      b.messages = [...older, ...b.messages];
      b.nextCursor = data.next_cursor;
      return older.length;
    } finally {
      b.loadingOlder = false;
    }
  }

  // Applies a message from an HTTP response or a WebSocket event. Both can
  // arrive for the same message in any order, so this must be idempotent.
  function upsert(message) {
    if (message.parent_message_id) {
      if (thread.value?.parent.id === message.parent_message_id) upsertInto(thread.value.replies, message);
      return;
    }
    if (thread.value?.parent.id === message.id) thread.value.parent = message;
    const b = byChannel[message.channel_id];
    if (b?.loaded) upsertInto(b.messages, message);
    if (!message.deleted_at && message.user) clearTyping(message.channel_id, message.user.id);
  }

  function updateThreadMeta({ channel_id, message_id, reply_count, last_reply_at }) {
    const target = byChannel[channel_id]?.messages.find((m) => m.id === message_id);
    if (target) Object.assign(target, { reply_count, last_reply_at });
    if (thread.value?.parent.id === message_id) Object.assign(thread.value.parent, { reply_count, last_reply_at });
  }

  async function send(channelId, body, parentMessageId = null) {
    const message = await api(`/channels/${channelId}/messages`, {
      method: "POST",
      body: { message: { body, parent_message_id: parentMessageId } },
    });
    upsert(message);
    return message;
  }

  async function edit(messageId, body) {
    upsert(await api(`/messages/${messageId}`, { method: "PATCH", body: { message: { body } } }));
  }

  async function remove(message) {
    await api(`/messages/${message.id}`, { method: "DELETE" });
    upsert({ ...message, deleted_at: new Date().toISOString(), body: null });
  }

  async function react(messageId, emoji) {
    upsert(await api(`/messages/${messageId}/reactions`, { method: "POST", body: { emoji } }));
  }

  async function openThread(message) {
    thread.value = { parent: message, replies: [], loading: true };
    const data = await api(`/messages/${message.id}/replies`);
    if (thread.value?.parent.id !== message.id) return;
    thread.value = { parent: data.parent, replies: data.replies, loading: false };
  }

  function closeThread() {
    thread.value = null;
  }

  function search(channelId, query) {
    return api(`/channels/${channelId}/messages/search`, { params: { q: query } });
  }

  function setTyping(channelId, user) {
    const forChannel = (typing[channelId] ??= {});
    clearTimeout(forChannel[user.id]?.timer);
    forChannel[user.id] = {
      user,
      timer: setTimeout(() => clearTyping(channelId, user.id), TYPING_TIMEOUT_MS),
    };
  }

  function clearTyping(channelId, userId) {
    const forChannel = typing[channelId];
    if (!forChannel?.[userId]) return;
    clearTimeout(forChannel[userId].timer);
    delete forChannel[userId];
  }

  function typingUsers(channelId) {
    return Object.values(typing[channelId] ?? {}).map((entry) => entry.user);
  }

  function reset() {
    for (const key of Object.keys(byChannel)) delete byChannel[key];
    for (const key of Object.keys(typing)) delete typing[key];
    thread.value = null;
  }

  return {
    byChannel,
    thread,
    bucket,
    loadInitial,
    loadOlder,
    upsert,
    updateThreadMeta,
    send,
    edit,
    remove,
    react,
    openThread,
    closeThread,
    search,
    setTyping,
    typingUsers,
    reset,
  };
});
