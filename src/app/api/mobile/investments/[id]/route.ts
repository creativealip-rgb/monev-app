import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { deleteInvestment, getInvestmentById, updateInvestment } from "@/backend/db/operations";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";

const updateMobileInvestmentSchema = z.object({
    name: z.string().min(1).max(100).optional(),
    type: z.enum(["stock", "crypto", "mutual_fund", "gold", "bond", "other"]).optional(),
    quantity: z.number().positive().optional(),
    avgBuyPrice: z.number().positive().optional(),
    currentPrice: z.number().positive().optional(),
    platform: z.string().max(100).optional(),
    icon: z.string().max(50).optional(),
    color: z.string().max(7).optional(),
    notes: z.string().max(1000).optional(),
});

function parseInvestmentId(idParam: string): number | null {
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
        const id = parseInvestmentId(idParam);
        if (!id) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Investment ID tidak valid" },
                { status: 400 }
            );
        }

        const item = await getInvestmentById(auth.context.userId, id);
        if (!item) {
            return NextResponse.json(
                { success: false, code: "NOT_FOUND", error: "Investasi tidak ditemukan" },
                { status: 404 }
            );
        }

        return NextResponse.json({ success: true, data: item });
    } catch (error) {
        console.error("Mobile investment GET detail API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengambil detail investasi" },
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
        const id = parseInvestmentId(idParam);
        if (!id) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Investment ID tidak valid" },
                { status: 400 }
            );
        }

        const parsed = updateMobileInvestmentSchema.safeParse(await req.json());
        if (!parsed.success) {
            return NextResponse.json(
                {
                    success: false,
                    code: "VALIDATION_ERROR",
                    error: "Data update investasi tidak valid",
                    details: parsed.error.issues.map((issue) => ({
                        path: issue.path.join("."),
                        message: issue.message,
                    })),
                },
                { status: 422 }
            );
        }

        if (Object.keys(parsed.data).length === 0) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Tidak ada data yang diupdate" },
                { status: 400 }
            );
        }

        const updated = await updateInvestment(auth.context.userId, id, parsed.data);
        if (!updated) {
            return NextResponse.json(
                { success: false, code: "NOT_FOUND", error: "Investasi tidak ditemukan" },
                { status: 404 }
            );
        }

        return NextResponse.json({ success: true, data: updated });
    } catch (error) {
        console.error("Mobile investment PATCH API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengupdate investasi" },
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
        const id = parseInvestmentId(idParam);
        if (!id) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Investment ID tidak valid" },
                { status: 400 }
            );
        }

        const existing = await getInvestmentById(auth.context.userId, id);
        if (!existing) {
            return NextResponse.json(
                { success: false, code: "NOT_FOUND", error: "Investasi tidak ditemukan" },
                { status: 404 }
            );
        }

        await deleteInvestment(auth.context.userId, id);
        return NextResponse.json({ success: true });
    } catch (error) {
        console.error("Mobile investment DELETE API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal menghapus investasi" },
            { status: 500 }
        );
    }
}

