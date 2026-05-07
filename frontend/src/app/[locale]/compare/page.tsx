import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { InnerPage } from "@/components/inner-page";
import { getSiteCopy, isLocale } from "@/lib/i18n";
import { getInnerPageContent, getInnerPageHref } from "@/lib/site-pages";

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  if (!isLocale(locale)) return {};
  const content = getInnerPageContent(locale, "compare");
  return {
    title: content.title,
    description: content.description,
    alternates: {
      canonical: getInnerPageHref(locale, "compare"),
    },
  };
}

export default async function ComparePage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();

  return <InnerPage copy={getSiteCopy(locale)} locale={locale} content={getInnerPageContent(locale, "compare")} />;
}
