import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { deleteBill, getBillById, toggleBillPaid, updateBill } from "@/backend/db/operations";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";

const updateMobileBillSchema = z.object({
    name: z.string().min(1).max(100).optional(),
    amount: z.number().positive().optional(),
    categoryId: z.number().int().positive().nullable().optional(),
    dueDate: z.number().int().min(1).max(31).optional(),
    frequency: z.enum(["monthly", "weekly", "yearly"]).optional(),
    icon: z.string().max(50).optional(),
    color: z.string().max(20).optional(),
    notes: z.string().max(500).optional(),
    isActive: z.boolean().optional(),
    action: z.literal("toggle").optional(),
});

function parseBillId(idParam: string): number | null {
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
        const id = parseBillId(idParam);
        if (!id) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Bill ID tidak valid" },
                { status: 400 }
            );
        }

        const bill = await getBillById(auth.context.userId, id);
        if (!bill) {
            return NextResponse.json(
                { success: false, code: "NOT_FOUND", error: "Tagihan tidak ditemukan" },
                { status: 404 }
            );
        }

        return NextResponse.json({ success: true, data: bill });
    } catch (error) {
        console.error("Mobile bill detail GET API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengambil detail tagihan" },
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
        const id = parseBillId(idParam);
        if (!id) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Bill ID tidak valid" },
                { status: 400 }
            );
        }

        const parsed = updateMobileBillSchema.safeParse(await req.json());
        if (!parsed.success) {
            return NextResponse.json(
                {
                    success: false,
                    code: "VALIDATION_ERROR",
                    error: "Data update tagihan tidak valid",
                    details: parsed.error.issues.map((issue) => ({
                        path: issue.path.join("."),
                        message: issue.message,
                    })),
                },
                { status: 422 }
            );
        }

        if (parsed.data.action === "toggle") {
            const toggled = await toggleBillPaid(auth.context.userId, id);
            if (!toggled) {
                return NextResponse.json(
                    { success: false, code: "NOT_FOUND", error: "Tagihan tidak ditemukan" },
                    { status: 404 }
                );
            }
            return NextResponse.json({ success: true, data: toggled });
        }

        const { action: _action, ...updates } = parsed.data;
        if (Object.keys(updates).length === 0) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Tidak ada data yang diupdate" },
                { status: 400 }
            );
        }

        const updated = await updateBill(auth.context.userId, id, updates);
        if (!updated) {
            return NextResponse.json(
                { success: false, code: "NOT_FOUND", error: "Tagihan tidak ditemukan" },
                { status: 404 }
            );
        }

        return NextResponse.json({ success: true, data: updated });
    } catch (error) {
        console.error("Mobile bill PATCH API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengupdate tagihan" },
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
        const id = parseBillId(idParam);
        if (!id) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Bill ID tidak valid" },
                { status: 400 }
            );
        }

        const existing = await getBillById(auth.context.userId, id);
        if (!existing) {
            return NextResponse.json(
                { success: false, code: "NOT_FOUND", error: "Tagihan tidak ditemukan" },
                { status: 404 }
            );
        }

        await deleteBill(auth.context.userId, id);
        return NextResponse.json({ success: true });
    } catch (error) {
        console.error("Mobile bill DELETE API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal menghapus tagihan" },
            { status: 500 }
        );
    }
}

