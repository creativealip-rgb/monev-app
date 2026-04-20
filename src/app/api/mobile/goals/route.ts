import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { createGoal, getGoals, getUserById } from "@/backend/db/operations";
import { canCreateGoal, type UserTier } from "@/lib/tier-gate";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";
import { goalSchema } from "@/lib/validations";

const createMobileGoalSchema = goalSchema.extend({
    deadline: z.union([z.string(), z.number(), z.date()]).optional(),
});

export async function GET(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 60, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const goals = await getGoals(auth.context.userId);
        const mappedGoals = goals.map((g) => ({
            id: g.id,
            name: g.name,
            targetAmount: g.targetAmount,
            currentAmount: g.currentAmount,
            percentage: g.targetAmount > 0 ? Math.min((g.currentAmount / g.targetAmount) * 100, 100) : 0,
            deadline: g.deadline,
            icon: g.icon,
            color: g.color,
            createdAt: g.createdAt,
        }));

        return NextResponse.json({ success: true, data: mappedGoals });
    } catch (error) {
        console.error("Mobile goals GET API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengambil goals" },
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

        const parsed = createMobileGoalSchema.safeParse(await req.json());
        if (!parsed.success) {
            return NextResponse.json(
                {
                    success: false,
                    code: "VALIDATION_ERROR",
                    error: "Data goal tidak valid",
                    details: parsed.error.issues.map((issue) => ({
                        path: issue.path.join("."),
                        message: issue.message,
                    })),
                },
                { status: 422 }
            );
        }

        const user = await getUserById(auth.context.userId);
        const tier = (user?.tier as UserTier) || "starter";
        const currentGoals = await getGoals(auth.context.userId);
        if (!canCreateGoal(currentGoals.length, tier)) {
            return NextResponse.json(
                { success: false, code: "FORBIDDEN", error: "Batas goal untuk tier saat ini sudah tercapai" },
                { status: 403 }
            );
        }

        const body = parsed.data;
        const goal = await createGoal(auth.context.userId, {
            name: body.name,
            targetAmount: body.targetAmount,
            currentAmount: body.currentAmount || 0,
            deadline: body.deadline ? new Date(body.deadline) : undefined,
            icon: body.icon || "Target",
            color: body.color || "#3b82f6",
        });

        return NextResponse.json({ success: true, data: goal }, { status: 201 });
    } catch (error) {
        console.error("Mobile goals POST API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal membuat goal" },
            { status: 500 }
        );
    }
}

