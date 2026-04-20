import { NextRequest, NextResponse } from "next/server";
import { and, eq } from "drizzle-orm";
import { z } from "zod";
import { getDb } from "@/backend/db";
import { recurringTransactions } from "@/backend/db/schema";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";

const updateMobileRecurringSchema = z.object({
    amount: z.number().positive().optional(),
    description: z.string().min(1).max(500).optional(),
    categoryId: z.number().int().positive().nullable().optional(),
    type: z.enum(["expense", "income"]).optional(),
    frequency: z.enum(["daily", "weekly", "monthly"]).optional(),
    nextRunAt: z.union([z.string(), z.number(), z.date()]).optional(),
    isActive: z.boolean().optional(),
});

function parseRecurringId(idParam: string): number | null {
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
        const id = parseRecurringId(idParam);
        if (!id) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Recurring ID tidak valid" },
                { status: 400 }
            );
        }

        const db = getDb();
        const item = db.select().from(recurringTransactions)
            .where(and(eq(recurringTransactions.id, id), eq(recurringTransactions.userId, auth.context.userId)))
            .get();

        if (!item) {
            return NextResponse.json(
                { success: false, code: "NOT_FOUND", error: "Recurring transaction tidak ditemukan" },
                { status: 404 }
            );
        }

        return NextResponse.json({ success: true, data: item });
    } catch (error) {
        console.error("Mobile recurring GET detail API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengambil recurring transaction" },
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
        const id = parseRecurringId(idParam);
        if (!id) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Recurring ID tidak valid" },
                { status: 400 }
            );
        }

        const parsed = updateMobileRecurringSchema.safeParse(await req.json());
        if (!parsed.success) {
            return NextResponse.json(
                {
                    success: false,
                    code: "VALIDATION_ERROR",
                    error: "Data update recurring transaction tidak valid",
                    details: parsed.error.issues.map((issue) => ({
                        path: issue.path.join("."),
                        message: issue.message,
                    })),
                },
                { status: 422 }
            );
        }

        const updates = {
            ...parsed.data,
            nextRunAt: parsed.data.nextRunAt ? new Date(parsed.data.nextRunAt) : undefined,
        };
        if (Object.keys(updates).length === 0) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Tidak ada data yang diupdate" },
                { status: 400 }
            );
        }

        const db = getDb();
        const updated = db.update(recurringTransactions)
            .set(updates)
            .where(and(eq(recurringTransactions.id, id), eq(recurringTransactions.userId, auth.context.userId)))
            .returning()
            .get();

        if (!updated) {
            return NextResponse.json(
                { success: false, code: "NOT_FOUND", error: "Recurring transaction tidak ditemukan" },
                { status: 404 }
            );
        }

        return NextResponse.json({ success: true, data: updated });
    } catch (error) {
        console.error("Mobile recurring PATCH API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengupdate recurring transaction" },
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
        const id = parseRecurringId(idParam);
        if (!id) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Recurring ID tidak valid" },
                { status: 400 }
            );
        }

        const db = getDb();
        const existing = db.select().from(recurringTransactions)
            .where(and(eq(recurringTransactions.id, id), eq(recurringTransactions.userId, auth.context.userId)))
            .get();
        if (!existing) {
            return NextResponse.json(
                { success: false, code: "NOT_FOUND", error: "Recurring transaction tidak ditemukan" },
                { status: 404 }
            );
        }

        db.delete(recurringTransactions)
            .where(and(eq(recurringTransactions.id, id), eq(recurringTransactions.userId, auth.context.userId)))
            .run();

        return NextResponse.json({ success: true });
    } catch (error) {
        console.error("Mobile recurring DELETE API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal menghapus recurring transaction" },
            { status: 500 }
        );
    }
}

