import { NextRequest, NextResponse } from "next/server";
import { desc, eq } from "drizzle-orm";
import { getDb } from "@/backend/db";
import { scheduledReports } from "@/backend/db/schema";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";

export async function GET(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 60, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const db = getDb();
        const rows = db.select().from(scheduledReports)
            .where(eq(scheduledReports.userId, auth.context.userId))
            .orderBy(desc(scheduledReports.createdAt))
            .all();

        const data = rows.map((r) => ({
            id: r.id,
            type: "Laporan Bulanan",
            period: `${String(r.reportMonth).padStart(2, "0")}/${r.reportYear}`,
            status: r.status,
            createdAt: r.createdAt,
            hasFile: !!r.pdfData,
        }));

        return NextResponse.json({ success: true, data });
    } catch (error) {
        console.error("Mobile report history GET API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengambil riwayat laporan" },
            { status: 500 }
        );
    }
}

