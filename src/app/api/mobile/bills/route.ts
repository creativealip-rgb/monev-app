import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { createBill, getBills } from "@/backend/db/operations";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";
import { billSchema } from "@/lib/validations";

const createMobileBillSchema = billSchema.extend({
    dueDate: z.number().int().min(1).max(31).optional(),
});

export async function GET(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 60, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const allBills = await getBills(auth.context.userId);
        return NextResponse.json({ success: true, data: allBills });
    } catch (error) {
        console.error("Mobile bills GET API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengambil tagihan" },
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

        const parsed = createMobileBillSchema.safeParse(await req.json());
        if (!parsed.success) {
            return NextResponse.json(
                {
                    success: false,
                    code: "VALIDATION_ERROR",
                    error: "Data tagihan tidak valid",
                    details: parsed.error.issues.map((issue) => ({
                        path: issue.path.join("."),
                        message: issue.message,
                    })),
                },
                { status: 422 }
            );
        }

        const body = parsed.data;
        const bill = await createBill(auth.context.userId, {
            name: body.name,
            amount: body.amount,
            categoryId: body.categoryId,
            dueDate: body.dueDate,
            frequency: body.frequency,
            icon: body.icon || "Receipt",
            color: body.color || "#6366f1",
            notes: body.notes,
        });

        return NextResponse.json({ success: true, data: bill }, { status: 201 });
    } catch (error) {
        console.error("Mobile bills POST API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal membuat tagihan" },
            { status: 500 }
        );
    }
}

