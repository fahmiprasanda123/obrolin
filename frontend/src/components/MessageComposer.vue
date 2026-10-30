<script setup>
import { computed, nextTick, ref } from "vue";
import { useAuthStore } from "../stores/auth";
import { useMessagesStore } from "../stores/messages";
import { useWorkspaceStore } from "../stores/workspace";
import AppIcon from "./AppIcon.vue";
import UserAvatar from "./UserAvatar.vue";

const TYPING_THROTTLE_MS = 2500;

const props = defineProps({
  channelId: { type: Number, required: true },
  parentMessageId: { type: String, default: null },
  placeholder: { type: String, default: "Write a message" },
});
const emit = defineEmits(["sent"]);

const auth = useAuthStore();
const messages = useMessagesStore();
const workspace = useWorkspaceStore();

const text = ref("");
const textarea = ref(null);
const sending = ref(false);
const error = ref("");
const mentionQuery = ref(null);
const activeIndex = ref(0);
let lastTypingSentAt = 0;

const suggestions = computed(() => {
  if (mentionQuery.value === null) return [];
  const q = mentionQuery.value;
  return workspace.members
    .filter((m) => m.id !== auth.user?.id && (m.username.startsWith(q) || m.display_name.toLowerCase().includes(q)))
    .slice(0, 6);
});

function autosize() {
  const el = textarea.value;
  if (!el) return;
  el.style.height = "auto";
  el.style.height = `${Math.min(el.scrollHeight, 200)}px`;
}

function updateMentionQuery() {
  const el = textarea.value;
  const beforeCaret = text.value.slice(0, el.selectionStart);
  const match = beforeCaret.match(/(^|\s)@([a-z0-9_]*)$/i);
  mentionQuery.value = match ? match[2].toLowerCase() : null;
  activeIndex.value = 0;
}

// Typing events are broadcast to the channel, throttled so a fast typist
// sends at most one event every few seconds.
function onInput() {
  autosize();
  updateMentionQuery();
  const now = Date.now();
  if (!props.parentMessageId && text.value.trim() && now - lastTypingSentAt > TYPING_THROTTLE_MS) {
    lastTypingSentAt = now;
    workspace.sendTyping(props.channelId);
  }
}

function pickMention(member) {
  const el = textarea.value;
  const caret = el.selectionStart;
  const before = text.value.slice(0, caret).replace(/@([a-z0-9_]*)$/i, `@${member.username} `);
  text.value = before + text.value.slice(caret);
  mentionQuery.value = null;
  nextTick(() => {
    el.focus();
    el.setSelectionRange(before.length, before.length);
  });
}

function onKeydown(event) {
  if (suggestions.value.length) {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      const step = event.key === "ArrowDown" ? 1 : -1;
      activeIndex.value = (activeIndex.value + step + suggestions.value.length) % suggestions.value.length;
      return;
    }
    if (event.key === "Enter" || event.key === "Tab") {
      event.preventDefault();
      pickMention(suggestions.value[activeIndex.value]);
      return;
    }
    if (event.key === "Escape") {
      mentionQuery.value = null;
      return;
    }
  }
  if (event.key === "Enter" && !event.shiftKey && !event.isComposing) {
    event.preventDefault();
    submit();
  }
}

async function submit() {
  const body = text.value.trim();
  if (!body || sending.value) return;
  sending.value = true;
  error.value = "";
  try {
    await messages.send(props.channelId, body, props.parentMessageId);
    text.value = "";
    lastTypingSentAt = 0;
    emit("sent");
    await nextTick();
    autosize();
  } catch (e) {
    error.value = e.message;
  } finally {
    sending.value = false;
    textarea.value?.focus();
  }
}

defineExpose({ focus: () => textarea.value?.focus() });
</script>

<template>
  <form class="composer" @submit.prevent="submit">
    <p v-if="error" class="composer__error" role="alert">{{ error }}</p>
    <ul v-if="suggestions.length" class="composer__suggestions" role="listbox" aria-label="Mention suggestions">
      <li
        v-for="(member, index) in suggestions"
        :key="member.id"
        role="option"
        :aria-selected="index === activeIndex"
        :class="{ 'is-active': index === activeIndex }"
        @mousedown.prevent="pickMention(member)"
      >
        <UserAvatar :user="member" :size="22" />
        <strong>{{ member.display_name }}</strong>
        <span class="muted">@{{ member.username }}</span>
      </li>
    </ul>
    <div class="composer__box">
      <textarea
        ref="textarea"
        v-model="text"
        rows="1"
        :placeholder="placeholder"
        :aria-label="placeholder"
        maxlength="4000"
        @input="onInput"
        @keydown="onKeydown"
        @click="updateMentionQuery"
      />
      <button class="composer__send" type="submit" :disabled="sending || !text.trim()" aria-label="Send message">
        <AppIcon name="send" />
      </button>
    </div>
    <p class="composer__hint">Enter to send · Shift+Enter for a new line · @ to mention</p>
  </form>
</template>

<style scoped>
.composer {
  position: relative;
  padding: 0 20px 12px;
}

.composer__box {
  display: flex;
  align-items: flex-end;
  gap: 8px;
  padding: 6px 6px 6px 12px;
  background: var(--surface);
  border: 1px solid var(--border-control);
  border-radius: var(--radius-lg);
}

.composer__box:focus-within {
  border-color: var(--focus);
  outline: 2px solid var(--focus);
  outline-offset: 0;
}

.composer__box textarea {
  flex: 1;
  border: 0;
  padding: 6px 0;
  resize: none;
  background: transparent;
  max-height: 200px;
}

.composer__box textarea:focus-visible {
  outline: none;
}

.composer__send {
  display: grid;
  place-items: center;
  flex: none;
  width: max(36px, var(--tap));
  height: max(36px, var(--tap));
  border: 0;
  border-radius: var(--radius);
  background: var(--accent);
  color: var(--accent-text);
  cursor: pointer;
}

.composer__send:disabled {
  background: var(--surface-muted);
  color: var(--text-muted);
  cursor: default;
}

.composer__hint {
  margin: 4px 2px 0;
  font-size: 11px;
  color: var(--text-muted);
}

.composer__error {
  margin: 0 0 6px;
  font-size: 13px;
  color: var(--danger);
}

.composer__suggestions {
  position: absolute;
  left: 20px;
  right: 20px;
  bottom: calc(100% - 4px);
  z-index: 10;
  list-style: none;
  margin: 0;
  padding: 4px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  box-shadow: var(--shadow-pop);
}

.composer__suggestions li {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 8px;
  border-radius: var(--radius-sm);
  font-size: 14px;
  cursor: pointer;
}

.composer__suggestions li.is-active {
  background: var(--surface-muted);
}
</style>
