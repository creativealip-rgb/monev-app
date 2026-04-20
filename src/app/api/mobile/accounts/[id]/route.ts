import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { deleteAccount, getAccountById, updateAccount } from "@/backend/db/account-operations";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";

const updateMobileAccountSchema = z.object({
    name: z.string().min(1).max(100).optional(),
    type: z.enum(["bank", "emoney", "cash", "credit_card", "investment_wallet"]).optional(),
    balance: z.number().min(0).optional(),
    color: z.string().max(20).optional(),
    icon: z.string().max(50).optional(),
    isActive: z.boolean().optional(),
});

function parseAccountId(idParam: string): number | null {
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
        const id = parseAccountId(idParam);
        if (!id) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Account ID tidak valid" },
                { status: 400 }
            );
        }

        const account = await getAccountById(auth.context.userId, id);
        if (!account) {
            return NextResponse.json(
                { success: false, code: "NOT_FOUND", error: "Akun tidak ditemukan" },
                { status: 404 }
            );
        }

        return NextResponse.json({ success: true, data: account });
    } catch (error) {
        console.error("Mobile account detail GET API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengambil detail akun" },
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
        const id = parseAccountId(idParam);
        if (!id) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Account ID tidak valid" },
                { status: 400 }
            );
        }

        const parsed = updateMobileAccountSchema.safeParse(await req.json());
        if (!parsed.success) {
            return NextResponse.json(
                {
                    success: false,
                    code: "VALIDATION_ERROR",
                    error: "Data update akun tidak valid",
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

        const updated = await updateAccount(auth.context.userId, id, parsed.data);
        if (!updated) {
            return NextResponse.json(
                { success: false, code: "NOT_FOUND", error: "Akun tidak ditemukan" },
                { status: 404 }
            );
        }

        return NextResponse.json({ success: true, data: updated });
    } catch (error) {
        console.error("Mobile account PATCH API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengupdate akun" },
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
        const id = parseAccountId(idParam);
        if (!id) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Account ID tidak valid" },
                { status: 400 }
            );
        }

        const existing = await getAccountById(auth.context.userId, id);
        if (!existing) {
            return NextResponse.json(
                { success: false, code: "NOT_FOUND", error: "Akun tidak ditemukan" },
                { status: 404 }
            );
        }

        await deleteAccount(auth.context.userId, id);
        return NextResponse.json({ success: true });
    } catch (error) {
        console.error("Mobile account DELETE API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal menghapus akun" },
            { status: 500 }
        );
    }
}

