import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { createCategory, deleteCategory, getCategories } from "@/backend/db/operations";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";

const createMobileCategorySchema = z.object({
    name: z.string().min(1, "Nama kategori wajib diisi").max(100),
    icon: z.string().min(1, "Icon wajib dipilih").max(100),
    color: z.string().min(1, "Warna wajib dipilih").max(20),
    type: z.enum(["expense", "income"]),
});

export async function GET(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 60, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const categories = await getCategories(auth.context.userId);
        return NextResponse.json({ success: true, data: categories });
    } catch (error) {
        console.error("Mobile categories GET API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengambil kategori" },
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

        const parsed = createMobileCategorySchema.safeParse(await req.json());
        if (!parsed.success) {
            return NextResponse.json(
                {
                    success: false,
                    code: "VALIDATION_ERROR",
                    error: "Data kategori tidak valid",
                    details: parsed.error.issues.map((issue) => ({
                        path: issue.path.join("."),
                        message: issue.message,
                    })),
                },
                { status: 422 }
            );
        }

        const category = await createCategory({
            ...parsed.data,
            userId: auth.context.userId,
        });
        return NextResponse.json({ success: true, data: category }, { status: 201 });
    } catch (error) {
        console.error("Mobile categories POST API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal membuat kategori" },
            { status: 500 }
        );
    }
}

export async function DELETE(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 20, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const { searchParams } = new URL(req.url);
        const id = Number(searchParams.get("id"));
        if (Number.isNaN(id) || id <= 0) {
            return NextResponse.json(
                { success: false, code: "INVALID_INPUT", error: "Category ID tidak valid" },
                { status: 400 }
            );
        }

        await deleteCategory(auth.context.userId, id);
        return NextResponse.json({ success: true });
    } catch (error: unknown) {
        console.error("Mobile categories DELETE API error:", error);
        const errorMessage = error instanceof Error ? error.message : "Gagal menghapus kategori";
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: errorMessage },
            { status: 500 }
        );
    }
}

