import { NextRequest, NextResponse } from "next/server";
import { createInvestment, getInvestmentsSummary } from "@/backend/db/operations";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";
import { investmentSchema } from "@/lib/validations";

export async function GET(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 60, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const summary = await getInvestmentsSummary(auth.context.userId);
        return NextResponse.json({ success: true, data: summary });
    } catch (error) {
        console.error("Mobile investments GET API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengambil investasi" },
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

        const parsed = investmentSchema.safeParse(await req.json());
        if (!parsed.success) {
            return NextResponse.json(
                {
                    success: false,
                    code: "VALIDATION_ERROR",
                    error: "Data investasi tidak valid",
                    details: parsed.error.issues.map((issue) => ({
                        path: issue.path.join("."),
                        message: issue.message,
                    })),
                },
                { status: 422 }
            );
        }

        const body = parsed.data;
        const investment = await createInvestment(auth.context.userId, {
            name: body.name,
            type: body.type,
            quantity: body.quantity,
            avgBuyPrice: body.avgBuyPrice,
            currentPrice: body.currentPrice,
            platform: body.platform,
            icon: body.icon,
            color: body.color,
            notes: body.notes,
        });

        return NextResponse.json({ success: true, data: investment }, { status: 201 });
    } catch (error) {
        console.error("Mobile investments POST API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal membuat investasi" },
            { status: 500 }
        );
    }
}

