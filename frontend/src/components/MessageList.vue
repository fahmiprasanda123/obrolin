<script setup>
import { computed, nextTick, ref, watch } from "vue";
import { useAuthStore } from "../stores/auth";
import { useMessagesStore } from "../stores/messages";
import { decorateMessages } from "../utils/format";
import MessageItem from "./MessageItem.vue";

const props = defineProps({
  channelId: { type: Number, required: true },
  channelName: { type: String, default: "" },
});
const emit = defineEmits(["open-thread"]);

const auth = useAuthStore();
const messages = useMessagesStore();
const scroller = ref(null);
const error = ref("");
let stickToBottom = true;

const bucket = computed(() => messages.byChannel[props.channelId]);
const items = computed(() => decorateMessages(bucket.value?.messages ?? []));

function scrollToBottom() {
  const el = scroller.value;
  if (el) el.scrollTop = el.scrollHeight;
}

// Infinite scroll upward: prepend older messages, then restore the scroll
// offset so the message the user was reading does not jump.
async function loadOlder() {
  const el = scroller.value;
  if (!el || !bucket.value?.nextCursor || bucket.value.loadingOlder) return;
  const previousHeight = el.scrollHeight;
  const previousTop = el.scrollTop;
  try {
    const added = await messages.loadOlder(props.channelId);
    if (!added) return;
    await nextTick();
    el.scrollTop = el.scrollHeight - previousHeight + previousTop;
  } catch (e) {
    error.value = e.message;
  }
}

// If the first page is too short to scroll, keep loading until it can.
async function fillViewport() {
  const el = scroller.value;
  while (el && bucket.value?.nextCursor && el.scrollHeight <= el.clientHeight) {
    const before = bucket.value.messages.length;
    await loadOlder();
    if (bucket.value.messages.length === before) break;
  }
}

function onScroll() {
  const el = scroller.value;
  stickToBottom = el.scrollHeight - el.scrollTop - el.clientHeight < 80;
  if (el.scrollTop < 150) loadOlder();
}

watch(
  () => props.channelId,
  async (channelId) => {
    error.value = "";
    stickToBottom = true;
    try {
      await messages.loadInitial(channelId);
    } catch (e) {
      error.value = e.message;
      return;
    }
    await nextTick();
    scrollToBottom();
    await fillViewport();
    scrollToBottom();
  },
  { immediate: true },
);

// Follow new messages when the user is at the bottom or just sent one.
watch(
  () => bucket.value?.messages.at(-1)?.id,
  async () => {
    const last = bucket.value?.messages.at(-1);
    if (stickToBottom || last?.user?.id === auth.user?.id) {
      await nextTick();
      scrollToBottom();
    }
  },
);
</script>

<template>
  <div ref="scroller" class="list" role="log" aria-label="Messages" @scroll.passive="onScroll">
    <p v-if="error" class="alert list__error" role="alert">{{ error }}</p>
    <template v-else-if="bucket?.loaded">
      <div v-if="bucket.loadingOlder" class="list__status">Loading older messages…</div>
      <div v-else-if="!bucket.nextCursor" class="list__intro">
        <h2>#{{ channelName }}</h2>
        <p class="muted">This is the very beginning of the <strong>#{{ channelName }}</strong> channel.</p>
      </div>
      <template v-for="item in items" :key="item.message.id">
        <div v-if="item.dayLabel" class="list__day"><span>{{ item.dayLabel }}</span></div>
        <MessageItem :message="item.message" :compact="item.compact" @open-thread="emit('open-thread', $event)" />
      </template>
    </template>
    <div v-else class="list__status">Loading messages…</div>
  </div>
</template>

<style scoped>
.list {
  flex: 1;
  overflow-y: auto;
  padding: 12px 0 8px;
}

.list__status {
  padding: 12px 20px;
  font-size: 13px;
  color: var(--text-muted);
  text-align: center;
}

.list__error {
  margin: 16px 20px;
}

.list__intro {
  padding: 24px 20px 12px;
}

.list__intro h2 {
  font-size: 22px;
  margin-bottom: 4px;
}

.list__intro p {
  margin: 0;
}

.list__day {
  position: relative;
  margin: 14px 0 6px;
  text-align: center;
  font-size: 12px;
  font-weight: 600;
  color: var(--text-muted);
}

.list__day::before {
  content: "";
  position: absolute;
  left: 0;
  right: 0;
  top: 50%;
  border-top: 1px solid var(--border);
}

.list__day span {
  position: relative;
  padding: 2px 12px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 12px;
}
</style>
