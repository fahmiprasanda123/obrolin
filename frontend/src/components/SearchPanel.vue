<script setup>
import { onBeforeUnmount, ref, watch } from "vue";
import { useMessagesStore } from "../stores/messages";
import { formatTime, renderMessageBody } from "../utils/format";
import AppIcon from "./AppIcon.vue";

const props = defineProps({ channel: { type: Object, required: true } });
const emit = defineEmits(["close"]);
const messages = useMessagesStore();
const query = ref("");
const results = ref(null);
const loading = ref(false);
const error = ref("");
let timer = null;

async function run(q) {
  if (q.trim().length < 2) {
    results.value = null;
    return;
  }
  loading.value = true;
  error.value = "";
  try {
    const data = await messages.search(props.channel.id, q.trim());
    if (q === query.value) results.value = data.messages;
  } catch (e) {
    error.value = e.message;
  } finally {
    loading.value = false;
  }
}

watch(query, (q) => {
  clearTimeout(timer);
  timer = setTimeout(() => run(q), 300);
});
watch(() => props.channel.id, () => {
  query.value = "";
  results.value = null;
});
onBeforeUnmount(() => clearTimeout(timer));
</script>

<template>
  <aside class="panel" aria-label="Search messages">
    <header class="panel__header">
      <div>
        <h2>Search</h2>
        <span class="muted">in #{{ channel.name }}</span>
      </div>
      <button class="icon-btn" type="button" aria-label="Close search" @click="emit('close')">
        <AppIcon name="x" />
      </button>
    </header>
    <div class="panel__body search">
      <input v-model="query" type="search" placeholder="Search words, e.g. deploy" aria-label="Search messages" autofocus />
      <p class="muted search__hint">Uses MongoDB's text index: matches whole words and their stems.</p>
      <p v-if="error" class="alert" role="alert">{{ error }}</p>
      <p v-else-if="loading" class="muted">Searching…</p>
      <p v-else-if="results && results.length === 0" class="muted">No messages match "{{ query }}".</p>
      <ul v-if="results?.length">
        <li v-for="m in results" :key="m.id">
          <div class="search__meta">
            <strong>{{ m.user?.display_name }}</strong>
            <span class="muted">{{ new Date(m.created_at).toLocaleDateString() }} {{ formatTime(m.created_at) }}</span>
          </div>
          <div class="search__body" v-html="renderMessageBody(m.body)" />
        </li>
      </ul>
    </div>
  </aside>
</template>

<style scoped>
.search {
  padding: 12px 16px;
}

.search__hint {
  font-size: 12px;
  margin: 6px 0 12px;
}

.search ul {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 12px;
}

.search li {
  padding-bottom: 10px;
  border-bottom: 1px solid var(--border);
  font-size: 14px;
}

.search__meta {
  display: flex;
  gap: 8px;
  align-items: baseline;
}

.search__meta .muted {
  font-size: 12px;
}

.search__body {
  white-space: pre-wrap;
  overflow-wrap: anywhere;
}
</style>
