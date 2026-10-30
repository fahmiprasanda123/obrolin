<script setup>
// Small hand-picked stroke icon set; only the glyphs the UI actually uses.
const PATHS = {
  hash: "M5 9h14M5 15h14M10 3 8 21M16 3l-2 18",
  lock: "M6 11h12v9H6zM8 11V8a4 4 0 0 1 8 0v3",
  search: "M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14zM20 20l-4-4",
  users: "M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM2.5 20a6.5 6.5 0 0 1 13 0M16 4.5a3.5 3.5 0 0 1 0 6.5M18 14a6 6 0 0 1 3.5 6",
  x: "M6 6l12 12M18 6 6 18",
  smile: "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM8.5 14.5a4 4 0 0 0 7 0M9 9.5h.01M15 9.5h.01",
  reply: "M4 5h16v11H9l-5 4z",
  pencil: "M4 20h4L19 9l-4-4L4 16z",
  trash: "M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13",
  plus: "M12 5v14M5 12h14",
  menu: "M4 7h16M4 12h16M4 17h16",
  logout: "M15 4h4v16h-4M10 8l-4 4 4 4M6 12h10",
  send: "M4 12l16-8-6 16-2-6z",
  mail: "M4 6h16v12H4zM4 7l8 6 8-6",
};

defineProps({
  name: { type: String, required: true },
  size: { type: Number, default: 18 },
});
</script>

<template>
  <svg
    :width="size"
    :height="size"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-width="1.8"
    stroke-linecap="round"
    stroke-linejoin="round"
    aria-hidden="true"
  >
    <path :d="PATHS[name]" />
  </svg>
</template>
