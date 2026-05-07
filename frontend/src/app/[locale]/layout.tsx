import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { DEFAULT_LOCALE, LOCALES, getBaseUrl, getSiteCopy, isLocale } from "@/lib/i18n";

const BASE_URL = getBaseUrl();

export function generateStaticParams() {
  return LOCALES.map((locale) => ({ locale }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const activeLocale = isLocale(locale) ? locale : DEFAULT_LOCALE;
  const copy = getSiteCopy(activeLocale);

  return {
    title: copy.metadata.title,
    description: copy.metadata.description,
    alternates: {
      canonical: `${BASE_URL}/${activeLocale}`,
      languages: Object.fromEntries(LOCALES.map((lng) => [lng, `${BASE_URL}/${lng}`])),
    },
    openGraph: {
      title: copy.metadata.title,
      description: copy.metadata.description,
      url: `${BASE_URL}/${activeLocale}`,
      siteName: "Code Orb",
      locale: activeLocale,
      type: "website",
    },
    twitter: {
      card: "summary_large_image",
      title: copy.metadata.title,
      description: copy.metadata.description,
    },
  };
}

export default async function LocaleLayout({
  children,
  params,
}: Readonly<{
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}>) {
  const { locale } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  return children;
}
