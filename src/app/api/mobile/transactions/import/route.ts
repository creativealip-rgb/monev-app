import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { createBulkTransactions, getCategories } from "@/backend/db/operations";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";

const importItemSchema = z.object({
    amount: z.union([z.number(), z.string()]),
    description: z.string().max(500).optional(),
    category: z.string().max(100).optional(),
    type: z.enum(["expense", "income", "transfer"]).optional(),
    date: z.union([z.string(), z.number()]).optional(),
    accountId: z.number().int().positive().optional(),
});

const importPayloadSchema = z.object({
    transactions: z.array(importItemSchema).min(1).max(500),
});

export async function POST(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 10, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const parsed = importPayloadSchema.safeParse(await req.json());
        if (!parsed.success) {
            return NextResponse.json(
                {
                    success: false,
                    code: "VALIDATION_ERROR",
                    error: "Payload import tidak valid",
                    details: parsed.error.issues.map((issue) => ({
                        path: issue.path.join("."),
                        message: issue.message,
                    })),
                },
                { status: 422 }
            );
        }

        const allCategories = await getCategories();
        if (allCategories.length === 0) {
            return NextResponse.json(
                { success: false, code: "SERVER_ERROR", error: "Kategori default tidak tersedia" },
                { status: 500 }
            );
        }

        const defaultCategory = allCategories.find((c) => c.name === "Lainnya") || allCategories[0];
        let failed = 0;
        const preparedTransactions = parsed.data.transactions.flatMap((row) => {
            const amount = typeof row.amount === "number" ? row.amount : Number(row.amount);
            if (!Number.isFinite(amount) || amount === 0) {
                failed += 1;
                return [];
            }

            let categoryId = defaultCategory.id;
            if (row.category) {
                const match = allCategories.find(
                    (c) => c.name.toLowerCase() === row.category!.toLowerCase()
                );
                if (match) categoryId = match.id;
            }

            return [{
                amount,
                description: row.description || "Imported Transaction",
                categoryId,
                type: row.type,
                date: row.date,
                accountId: row.accountId,
            }];
        });

        if (preparedTransactions.length === 0) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Tidak ada data valid untuk diimpor" },
                { status: 400 }
            );
        }

        await createBulkTransactions(auth.context.userId, preparedTransactions);

        return NextResponse.json({
            success: true,
            data: {
                total: parsed.data.transactions.length,
                imported: preparedTransactions.length,
                failed,
            },
        });
    } catch (error) {
        console.error("Mobile transactions import POST API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal import transaksi" },
            { status: 500 }
        );
    }
}

