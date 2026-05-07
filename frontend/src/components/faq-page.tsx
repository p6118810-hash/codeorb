"use client";

import { useEffect, useState } from "react";
import type { Locale, SiteCopy } from "@/lib/i18n";
import { SiteFooter, SiteHeader } from "@/components/site-shell";

export function FaqPage({ copy, locale }: { copy: SiteCopy; locale: Locale }) {
  const [openIndex, setOpenIndex] = useState(0);

  useEffect(() => {
    setOpenIndex(0);
  }, [copy]);

  return (
    <main className="vi-page">
      <SiteHeader copy={copy} locale={locale} />

      <section className="vi-inner-hero">
        <div className="vi-inner-shell">
          <p className="vi-inner-eyebrow">{copy.footer.faq}</p>
          <h1>{copy.faq.heading}</h1>
          <p className="vi-inner-intro">
            {locale === "zh"
              ? "关于 Code Orb 的核心问题、产品定位、兼容性与本地优先体验，都可以在这里快速查看。"
              : "Browse the most important questions about Code Orb, including compatibility, approvals, workflow, and local-first behavior."}
          </p>
        </div>
      </section>

      <section className="vi-section vi-faq">
        <div className="vi-inner-shell">
          <div className="vi-faq-list">
            {copy.faq.items.map((faq, index) => {
              const isOpen = openIndex === index;
              return (
                <article key={faq.question} className={`vi-faq-item ${isOpen ? "is-open" : ""}`}>
                  <button type="button" onClick={() => setOpenIndex(isOpen ? -1 : index)}>
                    <span>{faq.question}</span>
                    <span>{isOpen ? "-" : "+"}</span>
                  </button>
                  <div className="vi-faq-answer"><div><p>{faq.answer}</p></div></div>
                </article>
              );
            })}
          </div>
        </div>
      </section>

      <SiteFooter copy={copy} locale={locale} />
    </main>
  );
}
