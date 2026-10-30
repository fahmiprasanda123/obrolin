<script setup>
import { computed, nextTick, ref } from "vue";
import { useAuthStore } from "../stores/auth";
import { useMessagesStore } from "../stores/messages";
import { useWorkspaceStore } from "../stores/workspace";
import { formatTime, renderMessageBody } from "../utils/format";
import AppIcon from "./AppIcon.vue";
import UserAvatar from "./UserAvatar.vue";

const QUICK_REACTIONS = ["👍", "❤️", "😂", "🎉", "👀", "🙏"];

const props = defineProps({
  message: { type: Object, required: true },
  compact: { type: Boolean, default: false },
  inThread: { type: Boolean, default: false },
});
const emit = defineEmits(["open-thread"]);

const auth = useAuthStore();
const workspace = useWorkspaceStore();
const messages = useMessagesStore();

const editing = ref(false);
const draft = ref("");
const editor = ref(null);
const pickerOpen = ref(false);
const pickerButton = ref(null);
const picker = ref(null);
const error = ref("");

const isMine = computed(() => props.message.user?.id === auth.user?.id);
const canDelete = computed(() => isMine.value || workspace.isManager);
const mentionsMe = computed(() => props.message.mentions?.includes(auth.user?.id));
const html = computed(() =>
  renderMessageBody(props.message.body, {
    currentUsername: auth.user?.username,
    knownUsernames: workspace.usernames,
  }),
);
const time = computed(() => formatTime(props.message.created_at));
const fullTime = computed(() => new Date(props.message.created_at).toLocaleString());

function namesFor(reaction) {
  const byId = Object.fromEntries(workspace.members.map((m) => [m.id, m.display_name]));
  return reaction.user_ids.map((id) => (id === auth.user?.id ? "You" : byId[id] ?? "Someone")).join(", ");
}

async function run(action) {
  error.value = "";
  try {
    await action();
  } catch (e) {
    error.value = e.message;
  }
}

async function startEdit() {
  draft.value = props.message.body;
  editing.value = true;
  await nextTick();
  editor.value?.focus();
}

function saveEdit() {
  const body = draft.value.trim();
  if (!body) return;
  run(async () => {
    if (body !== props.message.body) await messages.edit(props.message.id, body);
    editing.value = false;
  });
}

function remove() {
  if (window.confirm("Delete this message? This cannot be undone.")) run(() => messages.remove(props.message));
}

async function togglePicker() {
  pickerOpen.value = !pickerOpen.value;
  if (pickerOpen.value) {
    await nextTick();
    picker.value?.querySelector("button")?.focus();
  }
}

function closePicker({ restoreFocus = true } = {}) {
  if (!pickerOpen.value) return;
  pickerOpen.value = false;
  if (restoreFocus) pickerButton.value?.focus();
}

// Close when focus moves somewhere outside the picker and its button.
function onPickerFocusOut(event) {
  if (!event.currentTarget.contains(event.relatedTarget)) closePicker({ restoreFocus: false });
}

function react(emoji) {
  closePicker();
  run(() => messages.react(props.message.id, emoji));
}
</script>

<template>
  <!-- tabindex -1: tapping a message on a touch screen focuses it, which reveals its actions. -->
  <article class="msg" :class="{ 'msg--compact': compact, 'msg--mention': mentionsMe }" tabindex="-1">
    <div class="msg__gutter">
      <UserAvatar v-if="!compact" :user="message.user" />
      <time v-else class="msg__side-time" :datetime="message.created_at" :title="fullTime">{{ time }}</time>
    </div>

    <div class="msg__content">
      <header v-if="!compact" class="msg__meta">
        <strong>{{ message.user?.display_name ?? "Unknown user" }}</strong>
        <time :datetime="message.created_at" :title="fullTime">{{ time }}</time>
      </header>

      <p v-if="message.deleted_at" class="msg__deleted">This message was deleted.</p>

      <form v-else-if="editing" class="msg__edit" @submit.prevent="saveEdit">
        <textarea
          ref="editor"
          v-model="draft"
          rows="2"
          aria-label="Edit message"
          @keydown.enter.exact.prevent="saveEdit"
          @keydown.esc="editing = false"
        />
        <div class="msg__edit-actions">
          <button class="btn" type="button" @click="editing = false">Cancel</button>
          <button class="btn btn--primary" type="submit">Save</button>
          <span class="muted">Enter to save · Esc to cancel</span>
        </div>
      </form>

      <div v-else class="msg__body">
        <span v-html="html" />
        <span v-if="message.edited_at" class="msg__edited" :title="new Date(message.edited_at).toLocaleString()"> (edited)</span>
      </div>

      <p v-if="error" class="msg__error" role="alert">{{ error }}</p>

      <div v-if="message.reactions?.length" class="msg__reactions">
        <button
          v-for="reaction in message.reactions"
          :key="reaction.emoji"
          type="button"
          class="reaction"
          :class="{ 'is-mine': reaction.user_ids.includes(auth.user?.id) }"
          :title="namesFor(reaction)"
          :aria-pressed="reaction.user_ids.includes(auth.user?.id)"
          @click="react(reaction.emoji)"
        >
          <span>{{ reaction.emoji }}</span> <span>{{ reaction.count }}</span>
        </button>
      </div>

      <button v-if="!inThread && message.reply_count > 0" type="button" class="msg__thread-link" @click="emit('open-thread', message)">
        {{ message.reply_count }} {{ message.reply_count === 1 ? "reply" : "replies" }}
        <span class="muted">· View thread</span>
      </button>
    </div>

    <div v-if="!message.deleted_at && !editing" class="msg__actions">
      <div class="msg__picker-wrap" @keydown.esc.stop="closePicker()" @focusout="onPickerFocusOut">
        <button
          ref="pickerButton"
          class="icon-btn"
          type="button"
          aria-label="Add reaction"
          title="Add reaction"
          :aria-expanded="pickerOpen"
          @click="togglePicker"
        >
          <AppIcon name="smile" />
        </button>
        <div v-if="pickerOpen" ref="picker" class="msg__picker" role="group" aria-label="Pick a reaction">
          <button v-for="emoji in QUICK_REACTIONS" :key="emoji" type="button" :aria-label="`React with ${emoji}`" @click="react(emoji)">
            {{ emoji }}
          </button>
        </div>
      </div>
      <button
        v-if="!inThread && !message.parent_message_id"
        class="icon-btn"
        type="button"
        aria-label="Reply in thread"
        title="Reply in thread"
        @click="emit('open-thread', message)"
      >
        <AppIcon name="reply" />
      </button>
      <button v-if="isMine" class="icon-btn" type="button" aria-label="Edit message" title="Edit" @click="startEdit">
        <AppIcon name="pencil" />
      </button>
      <button v-if="canDelete" class="icon-btn" type="button" aria-label="Delete message" title="Delete" @click="remove">
        <AppIcon name="trash" />
      </button>
    </div>
  </article>
</template>

<style scoped>
.msg {
  position: relative;
  display: grid;
  grid-template-columns: 44px 1fr;
  gap: 10px;
  padding: 6px 20px 6px 16px;
}

.msg--compact {
  padding-top: 1px;
  padding-bottom: 1px;
}

.msg:hover,
.msg:focus-within {
  background: var(--surface-muted);
}

.msg--mention {
  background: color-mix(in srgb, var(--accent-soft) 55%, transparent);
}

.msg__gutter {
  display: flex;
  justify-content: center;
  padding-top: 2px;
}

.msg__side-time {
  visibility: hidden;
  font-size: 11px;
  color: var(--text-muted);
  padding-top: 3px;
}

.msg:hover .msg__side-time,
.msg:focus-within .msg__side-time {
  visibility: visible;
}

.msg__content {
  min-width: 0;
}

.msg__meta {
  display: flex;
  align-items: baseline;
  gap: 8px;
}

.msg__meta time {
  font-size: 12px;
  color: var(--text-muted);
}

.msg__body {
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}

.msg__edited,
.msg__deleted {
  color: var(--text-muted);
  font-size: 13px;
}

.msg__deleted {
  margin: 0;
  font-style: italic;
}

.msg__error {
  margin: 4px 0 0;
  font-size: 13px;
  color: var(--danger);
}

.msg__edit {
  display: grid;
  gap: 6px;
  margin-top: 2px;
}

.msg__edit-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12px;
}

.msg__reactions {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  margin-top: 4px;
}

.reaction {
  display: inline-flex;
  gap: 4px;
  align-items: center;
  padding: 1px 8px;
  border: 1px solid var(--border-control);
  border-radius: 12px;
  background: var(--surface);
  color: var(--text);
  font: inherit;
  font-size: 13px;
  cursor: pointer;
}

.reaction.is-mine {
  border-color: var(--accent);
  background: var(--accent-soft);
}

.msg__thread-link {
  margin-top: 4px;
  padding: 0;
  border: 0;
  background: none;
  font: inherit;
  font-size: 13px;
  font-weight: 600;
  color: var(--link);
  cursor: pointer;
}

/* Hidden with opacity, not display: none, so the buttons stay in the tab
   order and appear as soon as keyboard focus reaches them. */
.msg__actions {
  position: absolute;
  top: -14px;
  right: 16px;
  display: flex;
  opacity: 0;
  pointer-events: none;
  gap: 2px;
  padding: 2px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
}

.msg:hover .msg__actions,
.msg:focus-within .msg__actions {
  opacity: 1;
  pointer-events: auto;
}

.msg:focus {
  outline: none;
}

/* Touch: hover never happens, so actions show only for the tapped (focused)
   message, and the picker anchors to the toolbar's right edge to stay on
   screen. */
@media (hover: none) {
  .msg:hover:not(:focus-within) .msg__actions {
    opacity: 0;
    pointer-events: none;
  }

  .msg__picker-wrap {
    position: static;
  }
}

@media (pointer: coarse) {
  .reaction,
  .msg__thread-link {
    min-height: var(--tap);
  }

  .reaction {
    padding: 0 12px;
  }
}

.msg__picker-wrap {
  position: relative;
}

.msg__picker {
  position: absolute;
  right: 0;
  top: calc(var(--tap) + 4px);
  z-index: 5;
  display: flex;
  gap: 2px;
  padding: 4px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  box-shadow: var(--shadow-pop);
}

.msg__picker button {
  width: max(34px, var(--tap));
  height: max(34px, var(--tap));
  border: 0;
  border-radius: var(--radius-sm);
  background: none;
  font-size: 18px;
  cursor: pointer;
}

.msg__picker button:hover {
  background: var(--surface-muted);
}
</style>
