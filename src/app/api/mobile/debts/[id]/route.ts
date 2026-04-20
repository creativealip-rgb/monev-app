import { NextRequest, NextResponse } from "next/server";
import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { getDb } from "@/backend/db";
import { debts } from "@/backend/db/schema";
import { updateDebtStatus } from "@/backend/db/operations";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";

const updateMobileDebtSchema = z.object({
    debtorName: z.string().min(1).max(100).optional(),
    amount: z.number().positive().optional(),
    description: z.string().max(500).optional(),
    dueDate: z.union([z.string(), z.number(), z.date(), z.null()]).optional(),
    direction: z.enum(["owe", "owed"]).optional(),
    status: z.enum(["paid", "unpaid"]).optional(),
});

function parseDebtId(idParam: string): number | null {
    const id = Number(idParam);
    if (Number.isNaN(id) || id <= 0) return null;
    return id;
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
        const debtId = parseDebtId(idParam);
        if (!debtId) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Debt ID tidak valid" },
                { status: 400 }
            );
        }

        const parsed = updateMobileDebtSchema.safeParse(await req.json());
        if (!parsed.success) {
            return NextResponse.json(
                {
                    success: false,
                    code: "VALIDATION_ERROR",
                    error: "Data update hutang/piutang tidak valid",
                    details: parsed.error.issues.map((issue) => ({
                        path: issue.path.join("."),
                        message: issue.message,
                    })),
                },
                { status: 422 }
            );
        }

        const body = parsed.data;
        if (Object.keys(body).length === 0) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Tidak ada data yang diupdate" },
                { status: 400 }
            );
        }

        if (body.status && Object.keys(body).length === 1) {
            const updated = await updateDebtStatus(auth.context.userId, debtId, body.status);
            if (!updated) {
                return NextResponse.json(
                    { success: false, code: "NOT_FOUND", error: "Data hutang/piutang tidak ditemukan" },
                    { status: 404 }
                );
            }
            return NextResponse.json({ success: true, data: updated });
        }

        const db = getDb();
        const updateData: Partial<typeof debts.$inferInsert> = {};
        if (body.debtorName !== undefined) updateData.debtorName = body.debtorName;
        if (body.amount !== undefined) updateData.amount = body.amount;
        if (body.status !== undefined) updateData.status = body.status;
        if (body.dueDate !== undefined) {
            updateData.dueDate = body.dueDate === null ? null : new Date(body.dueDate);
        }
        if (body.description !== undefined || body.direction !== undefined) {
            const prefix = (body.direction || "owe") === "owed" ? "[OWED] " : "[OWE] ";
            updateData.description = `${prefix}${body.description || ""}`;
        }

        const updated = db.update(debts)
            .set(updateData)
            .where(and(eq(debts.id, debtId), eq(debts.userId, auth.context.userId)))
            .returning()
            .get();

        if (!updated) {
            return NextResponse.json(
                { success: false, code: "NOT_FOUND", error: "Data hutang/piutang tidak ditemukan" },
                { status: 404 }
            );
        }

        return NextResponse.json({ success: true, data: updated });
    } catch (error) {
        console.error("Mobile debt PATCH API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengupdate hutang/piutang" },
            { status: 500 }
        );
    }
}

export async function DELETE(
    req: NextRequest,
    { params }: { params: Promise<{ id: string }> }
) {
    const limited = rateLimit(req, { maxRequests: 20, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const { id: idParam } = await params;
        const debtId = parseDebtId(idParam);
        if (!debtId) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Debt ID tidak valid" },
                { status: 400 }
            );
        }

        const db = getDb();
        const existing = db.select().from(debts)
            .where(and(eq(debts.id, debtId), eq(debts.userId, auth.context.userId)))
            .get();
        if (!existing) {
            return NextResponse.json(
                { success: false, code: "NOT_FOUND", error: "Data hutang/piutang tidak ditemukan" },
                { status: 404 }
            );
        }

        db.delete(debts)
            .where(and(eq(debts.id, debtId), eq(debts.userId, auth.context.userId)))
            .run();

        return NextResponse.json({ success: true });
    } catch (error) {
        console.error("Mobile debt DELETE API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal menghapus hutang/piutang" },
            { status: 500 }
        );
    }
}

