import type { BaseLayoutProps } from "fumadocs-ui/layouts/shared";

import { appName } from "./shared";

export const baseOptions = (): BaseLayoutProps => ({
  links: [
    {
      active: "nested-url",
      text: "Docs",
      url: "/docs",
    },
    {
      active: "nested-url",
      text: "Examples",
      url: "/docs/examples",
    },
  ],
  nav: {
    // JSX supported
    title: appName,
  },
});
