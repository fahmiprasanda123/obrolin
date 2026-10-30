<script setup>
import { reactive, ref } from "vue";
import { useWorkspaceStore } from "../stores/workspace";
import ModalDialog from "./ModalDialog.vue";

const emit = defineEmits(["close", "created"]);
const workspace = useWorkspaceStore();
const form = reactive({ name: "", description: "", is_private: false });
const selected = ref([]);
const error = ref("");
const saving = ref(false);

async function submit() {
  saving.value = true;
  error.value = "";
  try {
    const channel = await workspace.createChannel({ ...form }, form.is_private ? selected.value : []);
    emit("created", channel);
  } catch (e) {
    error.value = e.message;
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <ModalDialog title="Create a channel" @close="emit('close')">
    <form class="stack" @submit.prevent="submit">
      <p v-if="error" class="alert" role="alert">{{ error }}</p>
      <div class="field">
        <label for="channel-name">Name</label>
        <input id="channel-name" v-model="form.name" type="text" required maxlength="80" placeholder="e.g. plan-budget" />
        <span class="hint">Lowercase, no spaces. Spaces become dashes.</span>
      </div>
      <div class="field">
        <label for="channel-description">Description <span class="muted">(optional)</span></label>
        <input id="channel-description" v-model="form.description" type="text" maxlength="250" placeholder="What is this channel about?" />
      </div>
      <label class="check">
        <input v-model="form.is_private" type="checkbox" />
        <span>
          <strong>Make private</strong>
          <span class="muted">Only invited members can see and join it.</span>
        </span>
      </label>
      <fieldset v-if="form.is_private" class="field members">
        <legend>Add members</legend>
        <label v-for="member in workspace.sortedMembers" :key="member.id" class="check">
          <input v-model="selected" type="checkbox" :value="member.id" />
          <span>{{ member.display_name }} <span class="muted">@{{ member.username }}</span></span>
        </label>
      </fieldset>
      <button class="btn btn--primary" type="submit" :disabled="saving || !form.name.trim()">
        {{ saving ? "Creating…" : "Create channel" }}
      </button>
    </form>
  </ModalDialog>
</template>

<style scoped>
.check {
  display: flex;
  gap: 10px;
  align-items: flex-start;
  font-size: 14px;
}

.check {
  min-height: var(--tap);
  cursor: pointer;
}

.check input {
  flex: none;
  width: 18px;
  height: 18px;
  margin: 1px 0 0;
  accent-color: var(--link);
}

.check > span {
  display: grid;
}

.members {
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 10px 12px;
  max-height: 200px;
  overflow: auto;
  margin: 0;
}

.members legend {
  font-size: 13px;
  font-weight: 600;
  padding: 0 4px;
}
</style>
