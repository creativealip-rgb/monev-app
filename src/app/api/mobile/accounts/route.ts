import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { createAccount, getAccounts } from "@/backend/db/account-operations";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";

const createMobileAccountSchema = z.object({
    name: z.string().min(1).max(100),
    type: z.enum(["bank", "emoney", "cash", "credit_card", "investment_wallet"]).optional(),
    balance: z.number().min(0).optional(),
    color: z.string().max(20).optional(),
    icon: z.string().max(50).optional(),
    isActive: z.boolean().optional(),
});

export async function GET(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 60, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const accounts = await getAccounts(auth.context.userId);
        return NextResponse.json({ success: true, data: accounts });
    } catch (error) {
        console.error("Mobile accounts GET API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengambil daftar akun" },
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

        const parsed = createMobileAccountSchema.safeParse(await req.json());
        if (!parsed.success) {
            return NextResponse.json(
                {
                    success: false,
                    code: "VALIDATION_ERROR",
                    error: "Data akun tidak valid",
                    details: parsed.error.issues.map((issue) => ({
                        path: issue.path.join("."),
                        message: issue.message,
                    })),
                },
                { status: 422 }
            );
        }

        const body = parsed.data;
        const account = await createAccount(auth.context.userId, {
            name: body.name,
            type: body.type || "bank",
            balance: body.balance ?? 0,
            color: body.color || "#3b82f6",
            icon: body.icon || "Wallet",
            isActive: body.isActive ?? true,
        });

        return NextResponse.json({ success: true, data: account }, { status: 201 });
    } catch (error) {
        console.error("Mobile accounts POST API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal membuat akun" },
            { status: 500 }
        );
    }
}

