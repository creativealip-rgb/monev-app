import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { createDebt, getDebts } from "@/backend/db/operations";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";

const createMobileDebtSchema = z.object({
    debtorName: z.string().min(1).max(100),
    amount: z.number().positive(),
    description: z.string().max(500).optional(),
    dueDate: z.union([z.string(), z.number(), z.date()]).optional(),
    direction: z.enum(["owe", "owed"]).optional(),
});

function mapDebtDirection(description?: string | null) {
    const isOwed = description?.startsWith("[OWED]") === true;
    return {
        direction: isOwed ? "owed" : "owe",
        description: (description || "").replace(/^\[(OWE|OWED)\]\s*/, ""),
    };
}

export async function GET(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 60, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const status = req.nextUrl.searchParams.get("status");
        const statuses: Array<"paid" | "unpaid"> =
            status === "paid" || status === "unpaid" ? [status] : ["unpaid", "paid"];
        const lists = await Promise.all(statuses.map((s) => getDebts(auth.context.userId, s)));
        const all = lists.flat();

        const data = all.map((d) => {
            const parsed = mapDebtDirection(d.description);
            return {
                ...d,
                direction: parsed.direction,
                description: parsed.description,
            };
        });

        return NextResponse.json({ success: true, data });
    } catch (error) {
        console.error("Mobile debts GET API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengambil daftar hutang/piutang" },
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

        const parsed = createMobileDebtSchema.safeParse(await req.json());
        if (!parsed.success) {
            return NextResponse.json(
                {
                    success: false,
                    code: "VALIDATION_ERROR",
                    error: "Data hutang/piutang tidak valid",
                    details: parsed.error.issues.map((issue) => ({
                        path: issue.path.join("."),
                        message: issue.message,
                    })),
                },
                { status: 422 }
            );
        }

        const body = parsed.data;
        const prefix = body.direction === "owed" ? "[OWED] " : "[OWE] ";
        const debt = await createDebt({
            userId: auth.context.userId,
            debtorName: body.debtorName,
            amount: body.amount,
            description: `${prefix}${body.description || ""}`,
            dueDate: body.dueDate ? new Date(body.dueDate) : undefined,
        });

        return NextResponse.json({ success: true, data: debt }, { status: 201 });
    } catch (error) {
        console.error("Mobile debts POST API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal membuat hutang/piutang" },
            { status: 500 }
        );
    }
}

