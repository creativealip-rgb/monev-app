import { NextRequest, NextResponse } from "next/server";
import { getChatHistory } from "@/backend/db/operations";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";

export async function GET(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 60, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const { searchParams } = new URL(req.url);
        const limit = Number(searchParams.get("limit") || "50");
        if (Number.isNaN(limit) || limit < 1 || limit > 200) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Parameter limit tidak valid" },
                { status: 400 }
            );
        }

        const messages = await getChatHistory(auth.context.userId, limit);
        return NextResponse.json({ success: true, data: messages });
    } catch (error) {
        console.error("Mobile AI history GET API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengambil riwayat chat AI" },
            { status: 500 }
        );
    }
}

