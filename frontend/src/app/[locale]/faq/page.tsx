import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { FaqPage } from "@/components/faq-page";
import { getBaseUrl, getSiteCopy, isLocale } from "@/lib/i18n";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  if (!isLocale(locale)) return {};

  const copy = getSiteCopy(locale);
  const baseUrl = getBaseUrl();

  return {
    title: copy.faq.heading,
    description: copy.faq.items[0]?.answer,
    alternates: {
      canonical: `${baseUrl}/${locale}/faq`,
    },
  };
}

export default async function LocaleFaqPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;

  if (!isLocale(locale)) {
    notFound();
  }

  return <FaqPage copy={getSiteCopy(locale)} locale={locale} />;
}
