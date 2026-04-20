import { NextRequest, NextResponse } from "next/server";
import OpenAI from "openai";
import { getMonthlyStats } from "@/backend/db/operations";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";
import { createLogger } from "@/lib/logger";

const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY || "dummy",
});
const log = createLogger("mobile-ai-insight");

function fallbackInsight(expense: number, previousMonthExpense: number, dayOfMonth: number) {
    if (dayOfMonth <= 15 && previousMonthExpense > 0 && expense >= previousMonthExpense * 0.8) {
        return {
            insight: "Pengeluaran kamu sudah mendekati bulan lalu padahal bulan ini belum selesai. Coba tahan belanja non-prioritas beberapa hari ke depan.",
            type: "warning",
        };
    }
    if (expense < previousMonthExpense) {
        return {
            insight: "Good job, pengeluaranmu lebih terkontrol dibanding bulan lalu. Pertahankan ritme ini biar saldo tetap sehat.",
            type: "success",
        };
    }
    return {
        insight: "Pantau pengeluaran harian dan sisihkan dana tabungan sebelum belanja kebutuhan sekunder.",
        type: "info",
    };
}

export async function GET(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 20, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const now = new Date();
        const year = now.getFullYear();
        const month = now.getMonth() + 1;
        const prevMonth = month === 1 ? 12 : month - 1;
        const prevYear = month === 1 ? year - 1 : year;

        const current = await getMonthlyStats(auth.context.userId, year, month);
        const previous = await getMonthlyStats(auth.context.userId, prevYear, prevMonth);
        const fallback = fallbackInsight(current.expense, previous.expense, now.getDate());

        if (!process.env.OPENAI_API_KEY) {
            log.info("insight success", { userId: auth.context.userId, source: "fallback" });
            return NextResponse.json({
                success: true,
                data: { ...fallback, generatedAt: new Date().toISOString(), source: "fallback" },
            });
        }

        const prompt = `Berikan 1 insight finansial singkat (maks 2 kalimat) berdasarkan data:
income:${current.income}, expense:${current.expense}, balance:${current.balance}, prevExpense:${previous.expense}.
Format JSON: {"insight":"...","type":"success|warning|info"}`;

        try {
            const response = await openai.chat.completions.create({
                model: "gpt-4o-mini",
                messages: [
                    { role: "system", content: "Anda advisor finansial singkat, lugas, dalam bahasa Indonesia." },
                    { role: "user", content: prompt },
                ],
                response_format: { type: "json_object" },
            });
            const parsed = JSON.parse(response.choices[0]?.message?.content || "{}");
            log.info("insight success", { userId: auth.context.userId, source: "openai" });
            return NextResponse.json({
                success: true,
                data: {
                    insight: parsed.insight || fallback.insight,
                    type: parsed.type || fallback.type,
                    generatedAt: new Date().toISOString(),
                    source: "openai",
                },
            });
        } catch (aiError) {
            log.warn("insight fallback trigger", aiError);
            log.info("insight success", { userId: auth.context.userId, source: "fallback" });
            return NextResponse.json({
                success: true,
                data: { ...fallback, generatedAt: new Date().toISOString(), source: "fallback" },
            });
        }
    } catch (error) {
        log.error("insight failed", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengambil AI insight" },
            { status: 500 }
        );
    }
}

