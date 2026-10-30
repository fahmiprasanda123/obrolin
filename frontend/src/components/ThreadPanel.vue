<script setup>
import { nextTick, ref, watch } from "vue";
import { useMessagesStore } from "../stores/messages";
import AppIcon from "./AppIcon.vue";
import MessageComposer from "./MessageComposer.vue";
import MessageItem from "./MessageItem.vue";

defineProps({ channelName: { type: String, default: "" } });
const messages = useMessagesStore();
const body = ref(null);

watch(
  () => messages.thread?.replies.length,
  async () => {
    await nextTick();
    if (body.value) body.value.scrollTop = body.value.scrollHeight;
  },
);
</script>

<template>
  <aside v-if="messages.thread" class="panel" aria-label="Thread">
    <header class="panel__header">
      <div>
        <h2>Thread</h2>
        <span class="muted">#{{ channelName }}</span>
      </div>
      <button class="icon-btn" type="button" aria-label="Close thread" @click="messages.closeThread()">
        <AppIcon name="x" />
      </button>
    </header>
    <div ref="body" class="panel__body">
      <MessageItem :message="messages.thread.parent" in-thread />
      <div class="thread__divider">
        {{ messages.thread.parent.reply_count }} {{ messages.thread.parent.reply_count === 1 ? "reply" : "replies" }}
      </div>
      <p v-if="messages.thread.loading" class="muted thread__status">Loading replies…</p>
      <MessageItem v-for="reply in messages.thread.replies" :key="reply.id" :message="reply" in-thread />
    </div>
    <MessageComposer
      v-if="!messages.thread.parent.deleted_at"
      :key="messages.thread.parent.id"
      :channel-id="messages.thread.parent.channel_id"
      :parent-message-id="messages.thread.parent.id"
      placeholder="Reply in thread"
    />
  </aside>
</template>

<style scoped>
.thread__divider {
  margin: 8px 16px;
  padding-bottom: 4px;
  border-bottom: 1px solid var(--border);
  font-size: 12px;
  font-weight: 600;
  color: var(--text-muted);
}

.thread__status {
  padding: 0 20px;
}
</style>
