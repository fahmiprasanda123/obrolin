import { createRouter, createWebHistory } from "vue-router";
import { useAuthStore } from "../stores/auth";

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: "/login", component: () => import("../views/LoginView.vue"), meta: { guest: true } },
    { path: "/register", component: () => import("../views/RegisterView.vue"), meta: { guest: true } },
    { path: "/invite/:token", component: () => import("../views/InviteView.vue"), meta: { public: true } },
    { path: "/", component: () => import("../views/WorkspacesView.vue") },
    {
      path: "/workspaces/:workspaceId",
      component: () => import("../views/WorkspaceView.vue"),
      children: [
        { path: "", component: () => import("../views/WorkspaceHomeView.vue") },
        { path: "channels/:channelId", component: () => import("../views/ChannelView.vue") },
      ],
    },
    { path: "/:pathMatch(.*)*", redirect: "/" },
  ],
});

router.beforeEach(async (to) => {
  const auth = useAuthStore();
  const signedIn = await auth.restore();

  if (to.meta.public) return true;
  if (to.meta.guest) return signedIn ? to.query.redirect || "/" : true;
  if (!signedIn) return { path: "/login", query: { redirect: to.fullPath } };
  return true;
});
