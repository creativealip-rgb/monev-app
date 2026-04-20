import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { deleteTransaction, getTransactionById, updateTransaction } from "@/backend/db/operations";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";

const updateMobileTransactionSchema = z.object({
    amount: z.number().positive("Jumlah harus positif").max(100000000000).optional(),
    description: z.string().min(1).max(500).optional(),
    merchantName: z.string().max(200).optional(),
    categoryId: z.number().int().positive().optional(),
    type: z.enum(["expense", "income", "transfer"]).optional(),
    paymentMethod: z.string().max(50).optional(),
    accountId: z.number().int().positive().optional(),
    targetAccountId: z.number().int().positive().optional(),
    date: z.union([z.string(), z.number(), z.date()]).optional(),
});

function parseTransactionId(idParam: string): number | null {
    const id = Number(idParam);
    if (Number.isNaN(id) || id <= 0) return null;
    return id;
}

export async function GET(
    req: NextRequest,
    { params }: { params: Promise<{ id: string }> }
) {
    const limited = rateLimit(req, { maxRequests: 60, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const { id: idParam } = await params;
        const id = parseTransactionId(idParam);
        if (!id) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Transaction ID tidak valid" },
                { status: 400 }
            );
        }

        const tx = await getTransactionById(auth.context.userId, id);
        if (!tx) {
            return NextResponse.json(
                { success: false, code: "NOT_FOUND", error: "Transaction tidak ditemukan" },
                { status: 404 }
            );
        }

        return NextResponse.json({ success: true, data: tx });
    } catch (error) {
        console.error("Mobile transaction detail GET API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengambil detail transaksi" },
            { status: 500 }
        );
    }
}

export async function PATCH(
    req: NextRequest,
    { params }: { params: Promise<{ id: string }> }
) {
    const limited = rateLimit(req, { maxRequests: 30, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const { id: idParam } = await params;
        const id = parseTransactionId(idParam);
        if (!id) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Transaction ID tidak valid" },
                { status: 400 }
            );
        }

        const parsed = updateMobileTransactionSchema.safeParse(await req.json());
        if (!parsed.success) {
            return NextResponse.json(
                {
                    success: false,
                    code: "VALIDATION_ERROR",
                    error: "Data update transaksi tidak valid",
                    details: parsed.error.issues.map((issue) => ({
                        path: issue.path.join("."),
                        message: issue.message,
                    })),
                },
                { status: 422 }
            );
        }

        const updates = parsed.data;
        if (Object.keys(updates).length === 0) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Tidak ada data yang diupdate" },
                { status: 400 }
            );
        }

        const updated = await updateTransaction(auth.context.userId, id, {
            ...updates,
            date: updates.date ? new Date(updates.date) : undefined,
        });

        if (!updated) {
            return NextResponse.json(
                { success: false, code: "NOT_FOUND", error: "Transaction tidak ditemukan" },
                { status: 404 }
            );
        }

        return NextResponse.json({ success: true, data: updated });
    } catch (error) {
        console.error("Mobile transaction PATCH API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengupdate transaksi" },
            { status: 500 }
        );
    }
}

export async function DELETE(
    req: NextRequest,
    { params }: { params: Promise<{ id: string }> }
) {
    const limited = rateLimit(req, { maxRequests: 30, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const { id: idParam } = await params;
        const id = parseTransactionId(idParam);
        if (!id) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Transaction ID tidak valid" },
                { status: 400 }
            );
        }

        const existing = await getTransactionById(auth.context.userId, id);
        if (!existing) {
            return NextResponse.json(
                { success: false, code: "NOT_FOUND", error: "Transaction tidak ditemukan" },
                { status: 404 }
            );
        }

        await deleteTransaction(auth.context.userId, id);
        return NextResponse.json({ success: true });
    } catch (error) {
        console.error("Mobile transaction DELETE API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal menghapus transaksi" },
            { status: 500 }
        );
    }
}

