import { createApp } from "vue";
import { createPinia } from "pinia";
import App from "./App.vue";
import { router } from "./router";
import { applyTheme, storedTheme } from "./utils/theme";
import "./styles.css";

applyTheme(storedTheme());

createApp(App).use(createPinia()).use(router).mount("#app");
