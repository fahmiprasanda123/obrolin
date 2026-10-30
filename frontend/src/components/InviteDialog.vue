<script setup>
import { onMounted, ref } from "vue";
import { useWorkspaceStore } from "../stores/workspace";
import ModalDialog from "./ModalDialog.vue";

const emit = defineEmits(["close"]);
const workspace = useWorkspaceStore();
const email = ref("");
const error = ref("");
const sending = ref(false);
const lastInvite = ref(null);
const pending = ref([]);
const pendingLoading = ref(true);
const pendingError = ref("");
const copiedId = ref(null);

async function loadPending() {
  pendingError.value = "";
  try {
    pending.value = await workspace.fetchInvitations();
  } catch (e) {
    pendingError.value = e.message;
  } finally {
    pendingLoading.value = false;
  }
}

async function submit() {
  sending.value = true;
  error.value = "";
  try {
    lastInvite.value = await workspace.invite(email.value);
    email.value = "";
    await loadPending();
  } catch (e) {
    error.value = e.message;
  } finally {
    sending.value = false;
  }
}

async function copy(invitation) {
  try {
    await navigator.clipboard.writeText(invitation.url);
    copiedId.value = invitation.id;
  } catch {
    window.prompt("Copy the invite link", invitation.url);
  }
}

async function revoke(invitation) {
  try {
    await workspace.revokeInvitation(invitation.id);
    await loadPending();
  } catch (e) {
    pendingError.value = e.message;
  }
}

onMounted(loadPending);
</script>

<template>
  <ModalDialog :title="`Invite people to ${workspace.current?.name}`" @close="emit('close')">
    <form class="stack" @submit.prevent="submit">
      <p v-if="error" class="alert" role="alert">{{ error }}</p>
      <div class="field">
        <label for="invite-email">Email address</label>
        <input id="invite-email" v-model="email" type="email" required placeholder="name@example.com" />
        <span class="hint">An email with a join link is sent in the background (Sidekiq). In development, open it at /letter_opener.</span>
      </div>
      <button class="btn btn--primary" type="submit" :disabled="sending">{{ sending ? "Sending…" : "Send invitation" }}</button>
      <p v-if="lastInvite" class="muted" role="status">Invitation sent to {{ lastInvite.email }}.</p>
    </form>

    <section class="pending" aria-labelledby="pending-title">
      <h3 id="pending-title">Pending invitations</h3>
      <p v-if="pendingError" class="alert" role="alert">
        Could not load invitations: {{ pendingError }}
        <button class="btn pending__retry" type="button" @click="loadPending">Try again</button>
      </p>
      <p v-else-if="pendingLoading" class="muted" role="status">Loading invitations…</p>
      <p v-else-if="!pending.length" class="muted">No pending invitations.</p>
      <ul v-if="pending.length">
        <li v-for="invitation in pending" :key="invitation.id">
          <span class="pending__email">{{ invitation.email }}</span>
          <button class="btn" type="button" @click="copy(invitation)">{{ copiedId === invitation.id ? "Copied" : "Copy link" }}</button>
          <button class="btn btn--danger" type="button" @click="revoke(invitation)">Revoke</button>
        </li>
      </ul>
    </section>
  </ModalDialog>
</template>

<style scoped>
.pending {
  margin-top: 22px;
}

.pending h3 {
  font-size: 14px;
  margin-bottom: 8px;
}

.pending ul {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 6px;
}

.pending li {
  display: flex;
  align-items: center;
  gap: 8px;
}

.pending > p {
  margin: 0;
  font-size: 14px;
}

.pending__retry {
  display: flex;
  margin-top: 8px;
}

.pending__email {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 14px;
}
</style>
