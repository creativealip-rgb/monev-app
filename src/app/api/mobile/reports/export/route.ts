import { NextRequest, NextResponse } from "next/server";
import { desc, eq } from "drizzle-orm";
import { getDb } from "@/backend/db";
import { transactions } from "@/backend/db/schema";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";

export async function GET(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 30, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const format = req.nextUrl.searchParams.get("format") || "json";
        const db = getDb();
        const userTransactions = db.select()
            .from(transactions)
            .where(eq(transactions.userId, auth.context.userId))
            .orderBy(desc(transactions.date))
            .all();

        if (format === "csv") {
            const headers = ["ID", "Tanggal", "Tipe", "Nominal", "Deskripsi", "Merchant"];
            const rows = [
                headers.join(","),
                ...userTransactions.map((t) =>
                    [
                        t.id,
                        t.date ? new Date(t.date).toISOString().split("T")[0] : "",
                        t.type,
                        t.amount,
                        `"${(t.description || "").replace(/"/g, "\"\"")}"`,
                        `"${(t.merchantName || "").replace(/"/g, "\"\"")}"`,
                    ].join(",")
                ),
            ];

            return new NextResponse(rows.join("\n"), {
                headers: { "Content-Type": "text/csv; charset=utf-8" },
            });
        }

        return NextResponse.json({
            success: true,
            data: {
                exportedAt: new Date().toISOString(),
                transactions: userTransactions,
            },
        });
    } catch (error) {
        console.error("Mobile report export GET API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal export laporan" },
            { status: 500 }
        );
    }
}

