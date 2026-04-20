import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { createTransaction, getTransactions, getTransactionsCount } from "@/backend/db/operations";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";
import { transactionSchema } from "@/lib/validations";

const createMobileTransactionSchema = transactionSchema.extend({
    accountId: z.number().int().positive().optional(),
    targetAccountId: z.number().int().positive().optional(),
    date: z.union([z.string(), z.number(), z.date()]).optional(),
});

export async function GET(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 60, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const { searchParams } = new URL(req.url);
        const limit = Number(searchParams.get("limit") || "20");
        const offset = Number(searchParams.get("offset") || "0");
        const search = searchParams.get("search") || undefined;

        if (Number.isNaN(limit) || Number.isNaN(offset) || limit < 1 || offset < 0) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Parameter limit/offset tidak valid" },
                { status: 400 }
            );
        }

        const userId = auth.context.userId;
        const transactions = await getTransactions(userId, limit, offset, search);
        const total = await getTransactionsCount(userId, search);

        return NextResponse.json({
            success: true,
            data: transactions,
            pagination: {
                total,
                limit,
                offset,
                hasMore: offset + transactions.length < total,
            },
        });
    } catch (error) {
        console.error("Mobile transactions GET API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengambil daftar transaksi" },
            { status: 500 }
        );
    }
}

export async function POST(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 30, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const parsed = createMobileTransactionSchema.safeParse(await req.json());
        if (!parsed.success) {
            return NextResponse.json(
                {
                    success: false,
                    code: "VALIDATION_ERROR",
                    error: "Data transaksi tidak valid",
                    details: parsed.error.issues.map((issue) => ({
                        path: issue.path.join("."),
                        message: issue.message,
                    })),
                },
                { status: 422 }
            );
        }

        const body = parsed.data;
        const transaction = await createTransaction(auth.context.userId, {
            amount: body.amount,
            description: body.description,
            merchantName: body.merchantName,
            categoryId: body.categoryId,
            type: body.type,
            paymentMethod: body.paymentMethod || "cash",
            accountId: body.accountId,
            targetAccountId: body.targetAccountId,
            date: body.date ? new Date(body.date) : new Date(),
        });

        return NextResponse.json({ success: true, data: transaction }, { status: 201 });
    } catch (error) {
        console.error("Mobile transactions POST API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal membuat transaksi" },
            { status: 500 }
        );
    }
}

