import { NextRequest, NextResponse } from "next/server";
import OpenAI from "openai";
import { z } from "zod";
import {
    getBills,
    getBudgets,
    getDailyAICount,
    getGoals,
    getMonthlyStats,
    getTransactions,
    getUserById,
    logAIChat,
} from "@/backend/db/operations";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { canUseAI, type UserTier } from "@/lib/tier-gate";
import { rateLimit } from "@/lib/rate-limit";
import { createLogger } from "@/lib/logger";

const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY || "dummy",
});
const log = createLogger("mobile-ai-chat");

const historyItemSchema = z.object({
    role: z.enum(["user", "assistant"]),
    content: z.string().min(1).max(3000),
});

const mobileChatSchema = z.object({
    message: z.string().trim().min(1).max(2000),
    history: z.array(historyItemSchema).max(30).optional(),
});

function fallbackReply(message: string, context: {
    income: number;
    expense: number;
    balance: number;
}) {
    const lowerMessage = message.toLowerCase();
    if (lowerMessage.includes("saldo") || lowerMessage.includes("uang")) {
        return `Saldo bulan ini Rp ${context.balance.toLocaleString("id-ID")} (pemasukan Rp ${context.income.toLocaleString("id-ID")}, pengeluaran Rp ${context.expense.toLocaleString("id-ID")}).`;
    }
    if (context.expense > context.income) {
        return "Pengeluaran bulan ini lebih besar dari pemasukan. Fokus dulu ke kebutuhan prioritas dan tunda belanja sekunder.";
    }
    return "Kondisi keuangan kamu masih aman. Jaga konsistensi budget harian supaya target bulanan tetap tercapai.";
}

export async function POST(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 20, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const parsed = mobileChatSchema.safeParse(await req.json());
        if (!parsed.success) {
            return NextResponse.json(
                {
                    success: false,
                    code: "VALIDATION_ERROR",
                    error: "Payload chat tidak valid",
                    details: parsed.error.issues.map((issue) => ({
                        path: issue.path.join("."),
                        message: issue.message,
                    })),
                },
                { status: 422 }
            );
        }

        const user = await getUserById(auth.context.userId);
        const userTier = (user?.tier || "starter") as UserTier;
        const usageToday = await getDailyAICount(auth.context.userId);
        if (!canUseAI(usageToday, userTier)) {
            log.warn("chat rejected: ai limit reached", { userId: auth.context.userId, userTier, usageToday });
            return NextResponse.json(
                {
                    success: false,
                    code: "AI_LIMIT_REACHED",
                    error: "Limit AI harian sudah habis",
                    limitReached: true,
                },
                { status: 403 }
            );
        }

        const now = new Date();
        const [stats, goals, budgets, transactions, bills] = await Promise.all([
            getMonthlyStats(auth.context.userId, now.getFullYear(), now.getMonth() + 1),
            getGoals(auth.context.userId),
            getBudgets(auth.context.userId, now.getMonth() + 1, now.getFullYear()),
            getTransactions(auth.context.userId, 20),
            getBills(auth.context.userId),
        ]);

        await logAIChat(auth.context.userId, "user", parsed.data.message);

        let reply = fallbackReply(parsed.data.message, stats);
        let source: "openai" | "fallback" = "fallback";

        if (process.env.OPENAI_API_KEY) {
            try {
                const response = await openai.chat.completions.create({
                    model: "gpt-4o-mini",
                    messages: [
                        {
                            role: "system",
                            content: `Kamu asisten keuangan pribadi yang ringkas, suportif, dan selalu jawab dalam bahasa Indonesia.
Data finansial user saat ini:
- Pemasukan bulan ini: Rp ${stats.income.toLocaleString("id-ID")}
- Pengeluaran bulan ini: Rp ${stats.expense.toLocaleString("id-ID")}
- Saldo bulan ini: Rp ${stats.balance.toLocaleString("id-ID")}
- Jumlah goal aktif: ${goals.length}
- Jumlah budget aktif: ${budgets.length}
- Jumlah tagihan: ${bills.length}
- Transaksi terakhir tersedia: ${transactions.length}
Aturan:
1) Jawaban maksimal 4 kalimat.
2) Hindari markdown.
3) Jika user menanyakan hal di luar keuangan, arahkan balik ke pengelolaan keuangan.`,
                        },
                        ...(parsed.data.history || []).map((item) => ({
                            role: item.role,
                            content: item.content,
                        })),
                        { role: "user", content: parsed.data.message },
                    ],
                });
                reply = response.choices[0]?.message?.content?.trim() || reply;
                source = "openai";
            } catch (aiError) {
                log.warn("chat fallback trigger", aiError);
            }
        }

        await logAIChat(auth.context.userId, "assistant", reply);
        log.info("chat success", { userId: auth.context.userId, source, usageToday: usageToday + 1 });

        return NextResponse.json({
            success: true,
            data: {
                reply,
                source,
                usageToday: usageToday + 1,
                generatedAt: new Date().toISOString(),
            },
        });
    } catch (error) {
        log.error("chat failed", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal memproses chat AI" },
            { status: 500 }
        );
    }
}

