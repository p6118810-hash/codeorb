import type { Locale, SiteCopy } from "@/lib/i18n";
import type { InnerPageContent } from "@/lib/site-pages";
import { SiteFooter, SiteHeader } from "@/components/site-shell";
import { APPCAST_URL, DOWNLOAD_URL, RELEASE_NOTES_URL } from "@/lib/download-links";

export function DownloadPage({
  copy,
  locale,
  content,
}: {
  copy: SiteCopy;
  locale: Locale;
  content: InnerPageContent;
}) {
  const helperText =
    locale === "zh"
      ? "先下载，再查看更新日志和发布说明。"
      : "Download first, then review the appcast and release notes.";

  const secondaryCta = locale === "zh" ? "查看更新说明" : "View release notes";
  const tertiaryCta = locale === "zh" ? "查看订阅源" : "View appcast";

  return (
    <main className="vi-page">
      <SiteHeader copy={copy} locale={locale} />

      <section className="vi-inner-hero">
        <div className="vi-inner-shell">
          <p className="vi-inner-eyebrow">{content.eyebrow}</p>
          <h1>{content.title}</h1>
          <p className="vi-inner-intro">{content.intro}</p>
          <div className="vi-inner-updated">{content.updatedAt}</div>
          <div className="vi-hero-actions vi-download-actions">
            <a className="vi-cta-primary" href={DOWNLOAD_URL}>
              {copy.hero.primaryCta}
            </a>
            <a className="vi-cta-secondary" href={RELEASE_NOTES_URL}>
              {secondaryCta}
            </a>
          </div>
          <a className="vi-download-helper-link" href={APPCAST_URL}>
            {tertiaryCta}
          </a>
          <p className="vi-download-helper">{helperText}</p>
        </div>
      </section>

      <section className="vi-section vi-inner-section">
        <div className="vi-inner-shell vi-inner-stack">
          {content.sections.map((section) => (
            <article key={section.heading} className="vi-inner-card">
              <h2>{section.heading}</h2>
              {section.paragraphs?.map((paragraph) => (
                <p key={paragraph}>{paragraph}</p>
              ))}
              {section.bullets && (
                <ul className="vi-inner-list">
                  {section.bullets.map((bullet) => (
                    <li key={bullet}>{bullet}</li>
                  ))}
                </ul>
              )}
            </article>
          ))}
        </div>
      </section>

      <SiteFooter copy={copy} locale={locale} />
    </main>
  );
}
