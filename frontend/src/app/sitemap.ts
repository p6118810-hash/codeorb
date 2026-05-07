import type { MetadataRoute } from "next";
import { LOCALES, getBaseUrl } from "@/lib/i18n";

const BASE_URL = getBaseUrl();
const INNER_ROUTES = ["", "/download", "/changelog", "/faq", "/compare", "/privacy", "/terms"];

export default function sitemap(): MetadataRoute.Sitemap {
  const now = new Date();

  return LOCALES.flatMap((locale) =>
    INNER_ROUTES.map((route) => ({
      url: `${BASE_URL}/${locale}${route}`,
      lastModified: now,
      changeFrequency: route === "" ? "weekly" : "monthly",
      priority: route === "" ? 1 : 0.7,
    })),
  );
}
