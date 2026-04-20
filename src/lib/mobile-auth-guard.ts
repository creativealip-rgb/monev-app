import { NextRequest, NextResponse } from "next/server";
import { getBearerTokenFromAuthHeader, verifyMobileAccessToken } from "@/lib/mobile-auth";

export interface MobileAuthContext {
    userId: number;
    token: string;
}

export async function requireMobileAuth(
    req: NextRequest
): Promise<{ ok: true; context: MobileAuthContext } | { ok: false; response: NextResponse }> {
    const token = getBearerTokenFromAuthHeader(req.headers.get("authorization"));
    if (!token) {
        return {
            ok: false,
            response: NextResponse.json(
                { success: false, code: "UNAUTHORIZED", error: "Missing bearer token" },
                { status: 401 }
            ),
        };
    }

    const payload = await verifyMobileAccessToken(token);
    if (!payload?.sub) {
        return {
            ok: false,
            response: NextResponse.json(
                { success: false, code: "UNAUTHORIZED", error: "Invalid access token" },
                { status: 401 }
            ),
        };
    }

    const userId = Number(payload.sub);
    if (Number.isNaN(userId) || userId <= 0) {
        return {
            ok: false,
            response: NextResponse.json(
                { success: false, code: "UNAUTHORIZED", error: "Invalid token subject" },
                { status: 401 }
            ),
        };
    }

    return {
        ok: true,
        context: { userId, token },
    };
}

