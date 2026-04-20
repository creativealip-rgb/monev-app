import { NextRequest, NextResponse } from "next/server";
import { and, eq } from "drizzle-orm";
import { getDb } from "@/backend/db";
import { users } from "@/backend/db/schema";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";
import { createLogger } from "@/lib/logger";

const log = createLogger("mobile-auth-me");

export async function GET(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 60, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;
        const userId = auth.context.userId;

        const db = getDb();
        const user = await db.select()
            .from(users)
            .where(and(eq(users.id, userId), eq(users.isActive, true)))
            .get();

        if (!user) {
            log.warn("me rejected: user not found/disabled", { userId });
            return NextResponse.json(
                { success: false, code: "NOT_FOUND", error: "User not found" },
                { status: 404 }
            );
        }

        return NextResponse.json({
            success: true,
            data: {
                id: user.id,
                email: user.email,
                name: user.name,
                firstName: user.firstName,
                lastName: user.lastName,
                username: user.username,
                image: user.image,
                tier: user.tier || "starter",
                isAdmin: user.isAdmin,
            },
        });
    } catch (error) {
        log.error("me failed", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengambil profil user" },
            { status: 500 }
        );
    }
}

