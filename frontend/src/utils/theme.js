import { storage } from "./storage";

const THEME_KEY = "obrolin.theme";
export const THEMES = ["system", "light", "dark"];

export function storedTheme() {
  const value = storage.get(THEME_KEY);
  return THEMES.includes(value) ? value : "system";
}

// "system" removes the attribute so styles.css falls back to
// prefers-color-scheme; "light"/"dark" pin the palette.
export function applyTheme(theme) {
  const root = document.documentElement;
  if (theme === "light" || theme === "dark") root.dataset.theme = theme;
  else delete root.dataset.theme;
}

export function setTheme(theme) {
  storage.set(THEME_KEY, theme);
  applyTheme(theme);
}
