<script setup>
import { nextTick, onBeforeUnmount, onMounted, ref } from "vue";
import AppIcon from "./AppIcon.vue";

defineProps({ title: { type: String, required: true } });
const emit = defineEmits(["close"]);
const panel = ref(null);
let previouslyFocused = null;

const FOCUSABLE = 'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

// Escape closes; Tab and Shift+Tab wrap around inside the dialog so focus
// never lands on the page behind the backdrop.
function onKeydown(event) {
  if (event.key === "Escape") {
    emit("close");
    return;
  }
  if (event.key !== "Tab" || !panel.value) return;
  const items = [...panel.value.querySelectorAll(FOCUSABLE)];
  if (!items.length) return;
  const first = items[0];
  const last = items[items.length - 1];
  const inside = panel.value.contains(document.activeElement);
  if (event.shiftKey && (document.activeElement === first || !inside)) {
    event.preventDefault();
    last.focus();
  } else if (!event.shiftKey && (document.activeElement === last || !inside)) {
    event.preventDefault();
    first.focus();
  }
}

onMounted(async () => {
  previouslyFocused = document.activeElement;
  document.addEventListener("keydown", onKeydown);
  await nextTick();
  panel.value?.querySelector("input, textarea, button:not(.modal__close)")?.focus();
});

onBeforeUnmount(() => {
  document.removeEventListener("keydown", onKeydown);
  previouslyFocused?.focus?.();
});
</script>

<template>
  <!-- Rendered at <body> so dialogs opened from the sidebar do not inherit its colors. -->
  <Teleport to="body">
    <div class="modal" @mousedown.self="emit('close')">
      <section ref="panel" class="modal__panel" role="dialog" aria-modal="true" :aria-label="title">
        <header class="modal__header">
          <h2>{{ title }}</h2>
          <button class="icon-btn modal__close" type="button" aria-label="Close" @click="emit('close')">
            <AppIcon name="x" />
          </button>
        </header>
        <div class="modal__body"><slot /></div>
      </section>
    </div>
  </Teleport>
</template>

<style scoped>
.modal {
  position: fixed;
  inset: 0;
  z-index: 50;
  display: grid;
  place-items: start center;
  padding: 10vh 16px 16px;
  background: rgb(10 16 15 / 0.45);
}

.modal__panel {
  width: 100%;
  max-width: 480px;
  max-height: 80vh;
  overflow: auto;
  background: var(--surface);
  color: var(--text);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-pop);
}

.modal__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 16px 0 20px;
}

.modal__header h2 {
  font-size: 18px;
}

.modal__body {
  padding: 16px 20px 20px;
}
</style>
