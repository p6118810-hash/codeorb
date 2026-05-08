"use client";

import { usePathname, useRouter } from "next/navigation";
import { LOCALE_COOKIE_NAME, LOCALES, type Locale, type SiteCopy } from "@/lib/i18n";
import { CodeOrbIcon } from "@/components/code-orb-icon";

export function SiteHeader({
  copy,
  locale,
}: {
  copy: SiteCopy;
  locale: Locale;
}) {
  const router = useRouter();
  const pathname = usePathname();

  const handleLocaleChange = (nextLocale: Locale) => {
    if (nextLocale === locale) return;

    document.cookie = `${LOCALE_COOKIE_NAME}=${nextLocale}; path=/; max-age=31536000; samesite=lax`;

    const segments = pathname.split("/");
    if (LOCALES.includes(segments[1] as Locale)) {
      segments[1] = nextLocale;
    } else {
      segments.splice(1, 0, nextLocale);
    }

    const nextPath = segments.join("/") || `/${nextLocale}`;
    router.push(nextPath);
  };

  return (
    <header className="vi-header">
      <div className="vi-nav-shell">
        <a href={`/${locale}`} className="vi-brand">
          <CodeOrbIcon className="vi-brand-icon" />
          <span className="vi-brand-text">CODE ORB</span>
        </a>

        <nav className="vi-nav-links" aria-label={copy.nav.primaryLabel}>
          <a href={`/${locale}/changelog`}>{copy.nav.changelog}</a>
          <div className="vi-language-switcher" aria-label={copy.nav.languageLabel} role="group">
            {LOCALES.map((option) => (
              <button
                key={option}
                type="button"
                className={`vi-language-button ${locale === option ? "is-active" : ""}`}
                aria-pressed={locale === option}
                aria-label={`${copy.nav.languageLabel}: ${copy.nav.locales[option]}`}
                onClick={() => handleLocaleChange(option)}
              >
                {copy.nav.locales[option]}
              </button>
            ))}
          </div>
          <a className="vi-download-link" href={`/${locale}/download`}>
            {copy.nav.download}
          </a>
        </nav>
      </div>
    </header>
  );
}

export function SiteFooter({
  copy,
  locale,
}: {
  copy: SiteCopy;
  locale: Locale;
}) {
  return (
    <footer className="vi-footer">
      <div className="vi-footer-inner">
        <p>© 2026 Code Orb</p>
        <div className="vi-footer-links">
          <a href={`/${locale}/faq`}>{copy.footer.faq}</a>
          <a href={`/${locale}/compare`}>{copy.footer.compare}</a>
          <a href={`/${locale}/privacy`}>{copy.footer.privacy}</a>
          <a href={`/${locale}/terms`}>{copy.footer.terms}</a>
        </div>
      </div>
    </footer>
  );
}
