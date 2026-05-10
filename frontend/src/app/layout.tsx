import type { Metadata } from "next";
import { headers } from "next/headers";
import Script from "next/script";
import { DEFAULT_LOCALE, SITE_COPY, getHtmlLang, isLocale } from "@/lib/i18n";
import "./globals.css";

export const metadata: Metadata = {
  title: SITE_COPY[DEFAULT_LOCALE].metadata.title,
  description: SITE_COPY[DEFAULT_LOCALE].metadata.description,
  icons: {
    icon: "/code-orb-icon.svg",
  },
};

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const headerStore = await headers();
  const localeHeader = headerStore.get("x-code-orb-locale");
  const locale = localeHeader && isLocale(localeHeader) ? localeHeader : DEFAULT_LOCALE;

  return (
    <html lang={getHtmlLang(locale)}>
      <body className="antialiased">
        <Script src="https://www.googletagmanager.com/gtag/js?id=G-DKLXFJNBQB" strategy="afterInteractive" />
        <Script id="google-analytics" strategy="afterInteractive">
          {`
            window.dataLayer = window.dataLayer || [];
            function gtag(){window.dataLayer.push(arguments);}
            gtag('js', new Date());
            gtag('config', 'G-DKLXFJNBQB');
          `}
        </Script>
        {children}
        <div className="grain-overlay" />
      </body>
    </html>
  );
}
