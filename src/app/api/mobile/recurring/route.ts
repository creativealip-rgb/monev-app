import { NextRequest, NextResponse } from "next/server";
import { eq } from "drizzle-orm";
import { z } from "zod";
import { getDb } from "@/backend/db";
import { recurringTransactions } from "@/backend/db/schema";
import { getCategories } from "@/backend/db/operations";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";

const createMobileRecurringSchema = z.object({
    amount: z.number().positive(),
    description: z.string().min(1).max(500),
    categoryId: z.number().int().positive().optional(),
    type: z.enum(["expense", "income"]).optional(),
    frequency: z.enum(["daily", "weekly", "monthly"]),
    nextRunAt: z.union([z.string(), z.number(), z.date()]).optional(),
    isActive: z.boolean().optional(),
});

function calculateNextRunAt(frequency: "daily" | "weekly" | "monthly") {
    const now = new Date();
    if (frequency === "daily") return new Date(now.getTime() + 24 * 60 * 60 * 1000);
    if (frequency === "weekly") return new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
    return new Date(now.getFullYear(), now.getMonth() + 1, now.getDate());
}

export async function GET(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 60, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const db = getDb();
        const data = db.select().from(recurringTransactions)
            .where(eq(recurringTransactions.userId, auth.context.userId))
            .all();

        return NextResponse.json({ success: true, data });
    } catch (error) {
        console.error("Mobile recurring GET API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengambil recurring transactions" },
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

        const parsed = createMobileRecurringSchema.safeParse(await req.json());
        if (!parsed.success) {
            return NextResponse.json(
                {
                    success: false,
                    code: "VALIDATION_ERROR",
                    error: "Data recurring transaction tidak valid",
                    details: parsed.error.issues.map((issue) => ({
                        path: issue.path.join("."),
                        message: issue.message,
                    })),
                },
                { status: 422 }
            );
        }

        const body = parsed.data;
        const allCategories = await getCategories();
        const fallbackCategoryId = allCategories.find((c) => c.name === "Lainnya")?.id || allCategories[0]?.id || null;

        const db = getDb();
        const item = db.insert(recurringTransactions).values({
            userId: auth.context.userId,
            amount: body.amount,
            description: body.description,
            categoryId: body.categoryId || fallbackCategoryId,
            type: body.type || "expense",
            frequency: body.frequency,
            nextRunAt: body.nextRunAt ? new Date(body.nextRunAt) : calculateNextRunAt(body.frequency),
            isActive: body.isActive ?? true,
        }).returning().get();

        return NextResponse.json({ success: true, data: item }, { status: 201 });
    } catch (error) {
        console.error("Mobile recurring POST API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal membuat recurring transaction" },
            { status: 500 }
        );
    }
}

