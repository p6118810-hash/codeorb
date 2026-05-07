import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { DownloadPage } from "@/components/download-page";
import { getSiteCopy, isLocale } from "@/lib/i18n";
import { getInnerPageContent, getInnerPageHref } from "@/lib/site-pages";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  if (!isLocale(locale)) return {};
  const content = getInnerPageContent(locale, "download");
  return {
    title: content.title,
    description: content.description,
    alternates: {
      canonical: getInnerPageHref(locale, "download"),
    },
  };
}

export default async function LocaleDownloadPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();

  return <DownloadPage copy={getSiteCopy(locale)} locale={locale} content={getInnerPageContent(locale, "download")} />;
}
