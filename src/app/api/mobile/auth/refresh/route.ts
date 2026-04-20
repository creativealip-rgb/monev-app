import { NextRequest, NextResponse } from "next/server";
import { eq } from "drizzle-orm";
import { getDb } from "@/backend/db";
import { users } from "@/backend/db/schema";
import {
    createMobileRefreshTokenRecord,
    getActiveMobileRefreshTokenByHash,
    revokeMobileRefreshTokenByHash,
} from "@/backend/db/operations";
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

const log = createLogger("mobile-auth-refresh");

function getClientIp(req: NextRequest): string {
    return req.headers.get("x-forwarded-for")?.split(",")[0]?.trim()
        || req.headers.get("x-real-ip")
        || "unknown";
}

export async function POST(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 20, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const body = await req.json();
        const refreshToken = typeof body.refreshToken === "string" ? body.refreshToken : "";

        if (!refreshToken) {
            log.warn("refresh rejected: missing token", { ip: getClientIp(req) });
            return NextResponse.json(
                { success: false, error: "Refresh token wajib diisi" },
                { status: 400 }
            );
        }

        const oldTokenHash = hashMobileRefreshToken(refreshToken);
        const tokenRecord = await getActiveMobileRefreshTokenByHash(oldTokenHash);

        if (!tokenRecord) {
            log.warn("refresh rejected: invalid/expired token", { ip: getClientIp(req) });
            return NextResponse.json(
                { success: false, error: "Refresh token tidak valid atau sudah kedaluwarsa" },
                { status: 401 }
            );
        }

        const db = getDb();
        const user = await db.select().from(users).where(eq(users.id, tokenRecord.userId)).get();
        if (!user || !user.isActive) {
            await revokeMobileRefreshTokenByHash(oldTokenHash);
            log.warn("refresh rejected: invalid user", { userId: tokenRecord.userId });
            return NextResponse.json(
                { success: false, error: "User tidak valid" },
                { status: 401 }
            );
        }

        const accessToken = await createMobileAccessToken({
            userId: user.id,
            tier: (user.tier as UserTier) || "starter",
            email: user.email ?? null,
            name: user.name ?? null,
        });

        const newRefreshToken = generateMobileRefreshToken();
        const newRefreshTokenHash = hashMobileRefreshToken(newRefreshToken);

        await createMobileRefreshTokenRecord({
            userId: user.id,
            tokenHash: newRefreshTokenHash,
            expiresAt: getMobileRefreshTokenExpiresAt(),
            deviceInfo: req.headers.get("user-agent"),
            ipAddress: getClientIp(req),
        });

        await revokeMobileRefreshTokenByHash(oldTokenHash, newRefreshTokenHash);
        log.info("refresh success", { userId: user.id, ip: getClientIp(req) });

        return NextResponse.json({
            success: true,
            data: {
                accessToken,
                refreshToken: newRefreshToken,
                tokenType: "Bearer",
                expiresIn: getMobileAccessTokenExpiresInSeconds(),
            },
        });
    } catch (error) {
        log.error("refresh failed", error);
        return NextResponse.json(
            { success: false, error: "Gagal refresh token. Coba login ulang." },
            { status: 500 }
        );
    }
}

