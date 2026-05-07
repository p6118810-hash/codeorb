import { NextRequest, NextResponse } from "next/server";
import { DEFAULT_LOCALE, LOCALE_COOKIE_NAME, LOCALES, isLocale, type Locale } from "@/lib/i18n";

function getPreferredLocale(request: NextRequest): Locale {
  const storedLocale = request.cookies.get(LOCALE_COOKIE_NAME)?.value;
  if (storedLocale && isLocale(storedLocale)) {
    return storedLocale;
  }

  const acceptLanguage = request.headers.get("accept-language");
  if (!acceptLanguage) {
    return DEFAULT_LOCALE;
  }

  const languages = acceptLanguage
    .split(",")
    .map((part) => part.split(";")[0]?.trim().toLowerCase())
    .filter(Boolean);

  for (const language of languages) {
    if (language?.startsWith("zh")) {
      return "zh";
    }

    if (language?.startsWith("en")) {
      return "en";
    }
  }

  return DEFAULT_LOCALE;
}

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  if (
    pathname.startsWith("/_next") ||
    pathname.startsWith("/api") ||
    pathname.includes(".")
  ) {
    return NextResponse.next();
  }

  const pathnameHasLocale = LOCALES.some(
    (locale) => pathname === `/${locale}` || pathname.startsWith(`/${locale}/`),
  );

  if (pathnameHasLocale) {
    const activeLocale = pathname.split("/")[1];
    const requestHeaders = new Headers(request.headers);
    requestHeaders.set("x-code-orb-locale", activeLocale);
    return NextResponse.next({
      request: {
        headers: requestHeaders,
      },
    });
  }

  const locale = getPreferredLocale(request);
  const url = request.nextUrl.clone();
  url.pathname = `/${locale}${pathname}`;
  return NextResponse.redirect(url);
}

export const config = {
  matcher: ["/((?!api|_next/static|_next/image|favicon.ico|.*\\..*).*)"],
};
