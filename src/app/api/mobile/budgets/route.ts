import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { createBudget, getBudgets } from "@/backend/db/operations";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";
import { budgetSchema } from "@/lib/validations";

const createMobileBudgetSchema = budgetSchema.extend({
    enableRollover: z.boolean().optional(),
});

export async function GET(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 60, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const { searchParams } = new URL(req.url);
        const month = Number(searchParams.get("month") || new Date().getMonth() + 1);
        const year = Number(searchParams.get("year") || new Date().getFullYear());

        if (Number.isNaN(month) || Number.isNaN(year) || month < 1 || month > 12 || year < 2000 || year > 2100) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Parameter month/year tidak valid" },
                { status: 400 }
            );
        }

        const budgets = await getBudgets(auth.context.userId, month, year);
        const mappedBudgets = budgets.map((b) => ({
            id: b.id,
            category: b.category.name,
            categoryId: b.categoryId,
            amount: b.amount,
            spent: b.spent,
            color: b.category.color,
            percentage: b.percentage,
            enableRollover: b.enableRollover,
            month: b.month,
            year: b.year,
        }));

        return NextResponse.json({ success: true, data: mappedBudgets });
    } catch (error) {
        console.error("Mobile budgets GET API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengambil budget" },
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

        const parsed = createMobileBudgetSchema.safeParse(await req.json());
        if (!parsed.success) {
            return NextResponse.json(
                {
                    success: false,
                    code: "VALIDATION_ERROR",
                    error: "Data budget tidak valid",
                    details: parsed.error.issues.map((issue) => ({
                        path: issue.path.join("."),
                        message: issue.message,
                    })),
                },
                { status: 422 }
            );
        }

        const budget = await createBudget(auth.context.userId, {
            categoryId: parsed.data.categoryId,
            amount: parsed.data.amount,
            month: parsed.data.month,
            year: parsed.data.year,
            enableRollover: parsed.data.enableRollover ?? false,
        });

        return NextResponse.json({ success: true, data: budget }, { status: 201 });
    } catch (error) {
        console.error("Mobile budgets POST API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal membuat budget" },
            { status: 500 }
        );
    }
}

