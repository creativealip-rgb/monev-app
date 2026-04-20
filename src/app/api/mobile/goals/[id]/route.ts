import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { getGoalById, removeGoal, updateGoal } from "@/backend/db/operations";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";

const updateMobileGoalSchema = z.object({
    name: z.string().min(1).max(100).optional(),
    targetAmount: z.number().positive().max(1000000000000).optional(),
    currentAmount: z.number().min(0).optional(),
    deadline: z.union([z.string(), z.number(), z.date(), z.null()]).optional(),
    icon: z.string().max(50).optional(),
    color: z.string().max(20).optional(),
});

function parseGoalId(idParam: string): number | null {
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
        const id = parseGoalId(idParam);
        if (!id) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Goal ID tidak valid" },
                { status: 400 }
            );
        }

        const goal = await getGoalById(auth.context.userId, id);
        if (!goal) {
            return NextResponse.json(
                { success: false, code: "NOT_FOUND", error: "Goal tidak ditemukan" },
                { status: 404 }
            );
        }

        return NextResponse.json({ success: true, data: goal });
    } catch (error) {
        console.error("Mobile goals detail GET API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengambil detail goal" },
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
        const id = parseGoalId(idParam);
        if (!id) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Goal ID tidak valid" },
                { status: 400 }
            );
        }

        const parsed = updateMobileGoalSchema.safeParse(await req.json());
        if (!parsed.success) {
            return NextResponse.json(
                {
                    success: false,
                    code: "VALIDATION_ERROR",
                    error: "Data update goal tidak valid",
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

        const updated = await updateGoal(auth.context.userId, id, {
            ...parsed.data,
            deadline: parsed.data.deadline === null ? null : parsed.data.deadline ? new Date(parsed.data.deadline) : undefined,
        });

        if (!updated) {
            return NextResponse.json(
                { success: false, code: "NOT_FOUND", error: "Goal tidak ditemukan" },
                { status: 404 }
            );
        }

        return NextResponse.json({ success: true, data: updated });
    } catch (error) {
        console.error("Mobile goals PATCH API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengupdate goal" },
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
        const id = parseGoalId(idParam);
        if (!id) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Goal ID tidak valid" },
                { status: 400 }
            );
        }

        const existing = await getGoalById(auth.context.userId, id);
        if (!existing) {
            return NextResponse.json(
                { success: false, code: "NOT_FOUND", error: "Goal tidak ditemukan" },
                { status: 404 }
            );
        }

        await removeGoal(auth.context.userId, id);
        return NextResponse.json({ success: true });
    } catch (error) {
        console.error("Mobile goals DELETE API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal menghapus goal" },
            { status: 500 }
        );
    }
}

