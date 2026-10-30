<script setup>
import { computed } from "vue";
import { avatarHue, initials } from "../utils/format";

const props = defineProps({
  user: { type: Object, default: null },
  size: { type: Number, default: 36 },
  online: { type: Boolean, default: null },
});

const style = computed(() => ({
  width: `${props.size}px`,
  height: `${props.size}px`,
  fontSize: `${Math.round(props.size * 0.38)}px`,
  "--hue": avatarHue(props.user?.id ?? 0),
}));
</script>

<template>
  <span class="avatar" :style="style" aria-hidden="true">
    {{ initials(user?.display_name) }}
    <span v-if="online !== null" class="avatar__presence" :class="{ 'is-online': online }" />
  </span>
</template>

<style scoped>
.avatar {
  position: relative;
  flex: none;
  display: inline-grid;
  place-items: center;
  border-radius: var(--radius);
  font-weight: 700;
  color: hsl(var(--hue) var(--avatar-fg));
  background: hsl(var(--hue) var(--avatar-bg));
}

/* Online is a filled dot, offline a hollow ring: the shape carries the
   state, so it does not depend on telling two colors apart. */
.avatar__presence {
  position: absolute;
  right: -3px;
  bottom: -3px;
  width: 13px;
  height: 13px;
  border-radius: 50%;
  border: 2px solid var(--presence-ring, var(--surface));
  background: var(--presence-ring, var(--surface));
  box-shadow: inset 0 0 0 2px var(--presence-offline, var(--text-muted));
}

.avatar__presence.is-online {
  background: var(--presence-online, var(--online));
  box-shadow: none;
}
</style>
