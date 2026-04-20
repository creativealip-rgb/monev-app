import { NextResponse } from "next/server";
import { logger } from "@/lib/logger";

export function proxy(request: Request) {
    const { pathname } = new URL(request.url);
    const authorization = request.headers.get("authorization") || "";
    const isMobileBearerAuth = pathname.startsWith("/api/mobile/") && authorization.startsWith("Bearer ");
    const cookies = request.headers.get("cookie") || "";
    const sessionCookie = cookies
        .split(";")
        .find((c) => {
            const trimmed = c.trim();
            return trimmed.startsWith("next-auth.session-token=") || trimmed.startsWith("authjs.session-token=") || trimmed.startsWith("__Secure-next-auth.session-token=");
        })
        ?.split("=")[1];

    const isLoggedIn = !!sessionCookie;

    logger.debug(`[Middleware] Path: ${pathname}, isLoggedIn: ${isLoggedIn}`);

    // Public paths yang tidak perlu auth
    const isPublicPath =
        pathname === "/" ||
        pathname === "/login" ||
        pathname === "/register" ||
        pathname === "/forgot-password" ||
        pathname.startsWith("/api/auth/") ||
        pathname.startsWith("/api/mobile/auth/") ||
        pathname === "/manifest.json" ||
        pathname === "/icon.svg" ||
        pathname === "/sw.js" ||
        pathname.startsWith("/workbox-") ||
        pathname.startsWith("/_next/") ||
        pathname.endsWith(".png") ||
        pathname.endsWith(".jpg") ||
        pathname.endsWith(".svg") ||
        pathname.endsWith(".ico") ||
        pathname.endsWith(".css") ||
        pathname.endsWith(".js");

    // Handle CORS untuk API routes
    if (pathname.startsWith("/api")) {
        const response = isPublicPath
            ? NextResponse.next()
            : isLoggedIn || isMobileBearerAuth
                ? NextResponse.next()
                : NextResponse.json({ error: "Unauthorized" }, { status: 401 });

        // Set CORS headers
        response.headers.set("Access-Control-Allow-Origin", "*");
        response.headers.set(
            "Access-Control-Allow-Methods",
            "GET, POST, PUT, DELETE, OPTIONS"
        );
        response.headers.set(
            "Access-Control-Allow-Headers",
            "Content-Type, Authorization, x-requested-with"
        );

        if (request.method === "OPTIONS") {
            return new NextResponse(null, {
                status: 204,
                headers: response.headers,
            });
        }

        return response;
    }

    // Redirect logged in users dari login/register ke dashboard
    if (isLoggedIn && (pathname === "/login" || pathname === "/register")) {
        return NextResponse.redirect(new URL("/dashboard", request.url));
    }

    // Redirect unauthenticated users ke login
    if (!isLoggedIn && !isPublicPath) {
        logger.info(`[Middleware] Redirecting unauthenticated user from ${pathname} to /login`);
        return NextResponse.redirect(new URL("/login", request.url));
    }

    return NextResponse.next();
}

export const config = {
    matcher: [
        "/((?!_next/static|_next/image|favicon.ico|.*\\.png$|.*\\.jpg$|.*\\.svg$|.*\\.ico$).*)",
    ],
};
