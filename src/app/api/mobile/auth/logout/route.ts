import { NextRequest, NextResponse } from "next/server";
import {
    getBearerTokenFromAuthHeader,
    hashMobileRefreshToken,
    verifyMobileAccessToken,
} from "@/lib/mobile-auth";
import {
    revokeAllMobileRefreshTokensByUserId,
    revokeMobileRefreshTokenByHash,
} from "@/backend/db/operations";
import { rateLimit } from "@/lib/rate-limit";
import { createLogger } from "@/lib/logger";

const log = createLogger("mobile-auth-logout");

export async function POST(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 30, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        let revoked = false;
        const body = await req.json().catch(() => ({}));
        const refreshToken = typeof body.refreshToken === "string" ? body.refreshToken : null;
        const allSessions = body.allSessions === true;

        if (refreshToken) {
            await revokeMobileRefreshTokenByHash(hashMobileRefreshToken(refreshToken));
            log.info("logout current session success");
            revoked = true;
        }

        if (allSessions) {
            const bearerToken = getBearerTokenFromAuthHeader(req.headers.get("authorization"));
            if (!bearerToken) {
                log.warn("logout-all rejected: missing bearer token");
                return NextResponse.json(
                    { success: false, code: "UNAUTHORIZED", error: "Missing bearer token" },
                    { status: 401 }
                );
            }
            const payload = await verifyMobileAccessToken(bearerToken);
            const userId = payload?.sub ? Number(payload.sub) : NaN;
            if (Number.isNaN(userId) || userId <= 0) {
                log.warn("logout-all rejected: invalid bearer token");
                return NextResponse.json(
                    { success: false, code: "UNAUTHORIZED", error: "Invalid access token" },
                    { status: 401 }
                );
            }
            await revokeAllMobileRefreshTokensByUserId(userId);
            log.info("logout all sessions success", { userId });
            revoked = true;
        }

        if (!revoked) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Token tidak ditemukan untuk logout" },
                { status: 400 }
            );
        }

        return NextResponse.json({ success: true });
    } catch (error) {
        log.error("logout failed", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal logout" },
            { status: 500 }
        );
    }
}

