import { NextRequest, NextResponse } from "next/server";
import { getBudgets, getGoals, getMonthlyStats, getTransactions, getAssetsValue } from "@/backend/db/operations";
import { getAccounts } from "@/backend/db/account-operations";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";

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

        const userId = auth.context.userId;
        const [stats, assets, accounts, goals, budgets, recentTransactions] = await Promise.all([
            getMonthlyStats(userId, year, month),
            getAssetsValue(userId),
            getAccounts(userId),
            getGoals(userId),
            getBudgets(userId, month, year),
            getTransactions(userId, 5, 0),
        ]);

        const totalAccounts = accounts.reduce((sum, acc) => {
            if (acc.type === "credit_card") return sum - acc.balance;
            return sum + acc.balance;
        }, 0);

        const budgetSummary = budgets.reduce(
            (acc, b) => {
                acc.totalBudget += b.amount;
                acc.totalSpent += b.spent;
                if (b.spent > b.amount) acc.overBudgetCount += 1;
                return acc;
            },
            { totalBudget: 0, totalSpent: 0, overBudgetCount: 0 }
        );

        const goalsSummary = goals.reduce(
            (acc, g) => {
                acc.totalTarget += g.targetAmount;
                acc.totalSaved += g.currentAmount;
                if (g.currentAmount >= g.targetAmount) acc.completedCount += 1;
                return acc;
            },
            { totalTarget: 0, totalSaved: 0, completedCount: 0 }
        );

        return NextResponse.json({
            success: true,
            data: {
                period: { month, year },
                stats,
                assets,
                totals: {
                    liquidBalance: totalAccounts,
                    accountCount: accounts.length,
                    netWorthApprox: totalAccounts + assets.totalGoals + assets.totalInvestments,
                },
                budgets: {
                    ...budgetSummary,
                    count: budgets.length,
                },
                goals: {
                    ...goalsSummary,
                    count: goals.length,
                },
                recentTransactions,
            },
        });
    } catch (error) {
        console.error("Mobile dashboard summary API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengambil ringkasan dashboard" },
            { status: 500 }
        );
    }
}

