<script setup>
import { reactive, ref } from "vue";
import { useAuthStore } from "../stores/auth";
import { useWorkspaceStore } from "../stores/workspace";
import { setTheme, storedTheme } from "../utils/theme";
import ModalDialog from "./ModalDialog.vue";

const emit = defineEmits(["close"]);
const auth = useAuthStore();
const workspace = useWorkspaceStore();

const displayName = ref(auth.user?.display_name ?? "");
const nameStatus = ref("");
const nameErrors = ref({});
const savingName = ref(false);

const passwords = reactive({ current_password: "", password: "" });
const passwordStatus = ref("");
const passwordErrors = ref({});
const savingPassword = ref(false);

const THEME_OPTIONS = [
  { value: "system", label: "Match my device" },
  { value: "light", label: "Light" },
  { value: "dark", label: "Dark" },
];
const theme = ref(storedTheme());

function chooseTheme(value) {
  theme.value = value;
  setTheme(value);
}

function errorsFrom(e) {
  return Object.keys(e.fieldErrors ?? {}).length ? e.fieldErrors : { base: [e.message] };
}

async function saveName() {
  savingName.value = true;
  nameStatus.value = "";
  nameErrors.value = {};
  try {
    const user = await auth.updateProfile({ display_name: displayName.value.trim() });
    // Keep the sidebar member list in sync without refetching.
    const member = workspace.members.find((m) => m.id === user.id);
    if (member) member.display_name = user.display_name;
    nameStatus.value = "Name updated.";
  } catch (e) {
    nameErrors.value = errorsFrom(e);
  } finally {
    savingName.value = false;
  }
}

async function savePassword() {
  savingPassword.value = true;
  passwordStatus.value = "";
  passwordErrors.value = {};
  try {
    await auth.updateProfile({ ...passwords });
    passwords.current_password = "";
    passwords.password = "";
    passwordStatus.value = "Password changed. Other sessions keep working until their token expires.";
  } catch (e) {
    passwordErrors.value = errorsFrom(e);
  } finally {
    savingPassword.value = false;
  }
}
</script>

<template>
  <ModalDialog title="Your profile" @close="emit('close')">
    <dl class="identity">
      <div>
        <dt>Username</dt>
        <dd>@{{ auth.user?.username }}</dd>
      </div>
      <div>
        <dt>Email</dt>
        <dd>{{ auth.user?.email }}</dd>
      </div>
    </dl>

    <form class="stack" @submit.prevent="saveName">
      <div class="field">
        <label for="profile-name">Display name</label>
        <input id="profile-name" v-model="displayName" type="text" required maxlength="50" autocomplete="name" />
        <span v-for="msg in nameErrors.display_name ?? nameErrors.base" :key="msg" class="error">{{ msg }}</span>
      </div>
      <div class="row">
        <button
          class="btn btn--primary"
          type="submit"
          :disabled="savingName || !displayName.trim() || displayName.trim() === auth.user?.display_name"
        >
          {{ savingName ? "Saving…" : "Save name" }}
        </button>
        <span v-if="nameStatus" class="muted" role="status">{{ nameStatus }}</span>
      </div>
    </form>

    <form class="stack password" @submit.prevent="savePassword">
      <h3>Change password</h3>
      <div class="field">
        <label for="profile-current">Current password</label>
        <input id="profile-current" v-model="passwords.current_password" type="password" required autocomplete="current-password" />
        <span v-for="msg in passwordErrors.current_password" :key="msg" class="error">{{ msg }}</span>
      </div>
      <div class="field">
        <label for="profile-new">New password</label>
        <input id="profile-new" v-model="passwords.password" type="password" required minlength="8" autocomplete="new-password" />
        <span class="hint">At least 8 characters.</span>
        <span v-for="msg in passwordErrors.password ?? passwordErrors.base" :key="msg" class="error">{{ msg }}</span>
      </div>
      <div class="row">
        <button
          class="btn"
          type="submit"
          :disabled="savingPassword || !passwords.current_password || passwords.password.length < 8"
        >
          {{ savingPassword ? "Changing…" : "Change password" }}
        </button>
        <span v-if="passwordStatus" class="muted" role="status">{{ passwordStatus }}</span>
      </div>
    </form>

    <fieldset class="appearance">
      <legend>Appearance</legend>
      <label v-for="option in THEME_OPTIONS" :key="option.value" class="appearance__option">
        <input type="radio" name="theme" :value="option.value" :checked="theme === option.value" @change="chooseTheme(option.value)" />
        <span>{{ option.label }}</span>
      </label>
      <span class="hint">Saved in this browser only.</span>
    </fieldset>
  </ModalDialog>
</template>

<style scoped>
.identity {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
  margin: 0 0 18px;
  font-size: 14px;
}

.identity dt {
  font-size: 12px;
  font-weight: 600;
  color: var(--text-muted);
}

.identity dd {
  margin: 0;
  overflow-wrap: anywhere;
}

.row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 10px;
  font-size: 13px;
}

.password {
  margin-top: 22px;
  padding-top: 18px;
  border-top: 1px solid var(--border);
}

.password h3 {
  font-size: 15px;
}

.appearance {
  display: grid;
  gap: 2px;
  margin: 22px 0 0;
  padding: 18px 0 0;
  border: 0;
  border-top: 1px solid var(--border);
  font-size: 14px;
}

.appearance legend {
  float: left;
  margin-bottom: 6px;
  font-size: 15px;
  font-weight: 700;
}

.appearance__option {
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: var(--tap);
  cursor: pointer;
}

.appearance__option input {
  width: 18px;
  height: 18px;
  margin: 0;
  accent-color: var(--link);
}

.appearance .hint {
  font-size: 12px;
  color: var(--text-muted);
}
</style>
