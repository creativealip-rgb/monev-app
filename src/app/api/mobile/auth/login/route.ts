import { NextRequest, NextResponse } from "next/server";
import bcrypt from "bcryptjs";
import { eq } from "drizzle-orm";
import { getDb } from "@/backend/db";
import { users } from "@/backend/db/schema";
import { createMobileRefreshTokenRecord } from "@/backend/db/operations";
import { rateLimit } from "@/lib/rate-limit";
import { createLogger } from "@/lib/logger";
import type { UserTier } from "@/lib/tier-gate";
import {
    createMobileAccessToken,
    generateMobileRefreshToken,
    getMobileAccessTokenExpiresInSeconds,
    getMobileRefreshTokenExpiresAt,
    hashMobileRefreshToken,
} from "@/lib/mobile-auth";

const log = createLogger("mobile-auth-login");

function getClientIp(req: NextRequest): string {
    return req.headers.get("x-forwarded-for")?.split(",")[0]?.trim()
        || req.headers.get("x-real-ip")
        || "unknown";
}

function maskEmail(email: string): string {
    const [local, domain] = email.split("@");
    if (!local || !domain) return "unknown";
    const safeLocal = local.length <= 2 ? `${local[0] || "*"}*` : `${local.slice(0, 2)}***`;
    return `${safeLocal}@${domain}`;
}

export async function POST(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 10, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const body = await req.json();
        const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
        const password = typeof body.password === "string" ? body.password : "";

        if (!email || !password) {
            log.warn("login rejected: missing credentials", { ip: getClientIp(req) });
            return NextResponse.json(
                { success: false, error: "Email dan password wajib diisi" },
                { status: 400 }
            );
        }

        const db = getDb();
        const user = await db.select().from(users).where(eq(users.email, email)).get();

        if (!user?.password) {
            log.warn("login rejected: user not found or no password", { email: maskEmail(email), ip: getClientIp(req) });
            return NextResponse.json(
                { success: false, error: "Email atau password salah" },
                { status: 401 }
            );
        }

        if (!user.isActive) {
            log.warn("login rejected: inactive user", { userId: user.id, email: maskEmail(email) });
            return NextResponse.json(
                { success: false, error: "Akun nonaktif. Hubungi admin." },
                { status: 403 }
            );
        }

        const passwordMatches = await bcrypt.compare(password, user.password);
        if (!passwordMatches) {
            log.warn("login rejected: wrong password", { userId: user.id, email: maskEmail(email), ip: getClientIp(req) });
            return NextResponse.json(
                { success: false, error: "Email atau password salah" },
                { status: 401 }
            );
        }

        const accessToken = await createMobileAccessToken({
            userId: user.id,
            tier: (user.tier as UserTier) || "starter",
            email: user.email ?? null,
            name: user.name ?? null,
        });

        const refreshToken = generateMobileRefreshToken();
        const refreshTokenHash = hashMobileRefreshToken(refreshToken);
        await createMobileRefreshTokenRecord({
            userId: user.id,
            tokenHash: refreshTokenHash,
            expiresAt: getMobileRefreshTokenExpiresAt(),
            deviceInfo: req.headers.get("user-agent"),
            ipAddress: getClientIp(req),
        });
        log.info("login success", { userId: user.id, tier: user.tier || "starter", ip: getClientIp(req) });

        return NextResponse.json({
            success: true,
            data: {
                accessToken,
                refreshToken,
                tokenType: "Bearer",
                expiresIn: getMobileAccessTokenExpiresInSeconds(),
                user: {
                    id: user.id,
                    email: user.email,
                    name: user.name,
                    tier: user.tier || "starter",
                },
            },
        });
    } catch (error) {
        log.error("login failed", error);
        return NextResponse.json(
            { success: false, error: "Gagal login. Coba lagi." },
            { status: 500 }
        );
    }
}

