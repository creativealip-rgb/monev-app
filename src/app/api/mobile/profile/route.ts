import { NextRequest, NextResponse } from "next/server";
import { getDb } from "@/backend/db";
import { userSettings } from "@/backend/db/schema";
import { getUserById, getUserSettings, updateUser, updateUserSettings } from "@/backend/db/operations";
import { requireMobileAuth } from "@/lib/mobile-auth-guard";
import { rateLimit } from "@/lib/rate-limit";

export async function GET(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 60, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const userId = auth.context.userId;
        const user = await getUserById(userId);
        if (!user || !user.isActive) {
            return NextResponse.json(
                { success: false, code: "NOT_FOUND", error: "User not found" },
                { status: 404 }
            );
        }

        let settings = await getUserSettings(userId);
        if (!settings) {
            const db = getDb();
            settings = await db.insert(userSettings).values({
                userId,
                hourlyRate: 50000,
                hideBalance: false,
                hasCompletedOnboarding: false,
            }).returning().get();
        }

        return NextResponse.json({
            success: true,
            data: {
                user: {
                    id: user.id,
                    email: user.email,
                    name: user.name,
                    firstName: user.firstName,
                    lastName: user.lastName,
                    username: user.username,
                    image: user.image,
                    whatsappId: user.whatsappId,
                    tier: user.tier || "starter",
                    isAdmin: user.isAdmin,
                },
                settings: {
                    id: settings?.id,
                    userId: settings?.userId,
                    hourlyRate: settings?.hourlyRate,
                    primaryGoalId: settings?.primaryGoalId,
                    isAppLockEnabled: settings?.isAppLockEnabled,
                    isBiometricEnabled: settings?.isBiometricEnabled,
                    hideBalance: settings?.hideBalance,
                    notificationsEnabled: settings?.notificationsEnabled,
                    hasCompletedOnboarding: settings?.hasCompletedOnboarding,
                    autoLockTimeout: settings?.autoLockTimeout,
                    reportLocale: settings?.reportLocale,
                    updatedAt: settings?.updatedAt,
                },
            },
        });
    } catch (error) {
        console.error("Mobile profile GET API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal mengambil profile mobile" },
            { status: 500 }
        );
    }
}

export async function PATCH(req: NextRequest) {
    const limited = rateLimit(req, { maxRequests: 30, windowMs: 60 * 1000 });
    if (limited) return limited;

    try {
        const auth = await requireMobileAuth(req);
        if (!auth.ok) return auth.response;

        const userId = auth.context.userId;
        const body = await req.json();

        const userUpdate: {
            firstName?: string;
            lastName?: string;
            username?: string;
            whatsappId?: string;
            name?: string;
            image?: string;
        } = {};

        if (typeof body.firstName === "string") userUpdate.firstName = body.firstName;
        if (typeof body.lastName === "string") userUpdate.lastName = body.lastName;
        if (typeof body.username === "string") userUpdate.username = body.username;
        if (typeof body.whatsappId === "string") userUpdate.whatsappId = body.whatsappId;
        if (typeof body.name === "string") userUpdate.name = body.name;
        if (typeof body.image === "string") userUpdate.image = body.image;

        const settingsUpdate: {
            hourlyRate?: number;
            primaryGoalId?: number | null;
            isAppLockEnabled?: boolean;
            isBiometricEnabled?: boolean;
            hideBalance?: boolean;
            notificationsEnabled?: boolean;
            hasCompletedOnboarding?: boolean;
            autoLockTimeout?: number;
            reportLocale?: "auto" | "id" | "en";
        } = {};

        if (typeof body.hourlyRate === "number") settingsUpdate.hourlyRate = body.hourlyRate;
        if (typeof body.primaryGoalId === "number" || body.primaryGoalId === null) settingsUpdate.primaryGoalId = body.primaryGoalId;
        if (typeof body.isAppLockEnabled === "boolean") settingsUpdate.isAppLockEnabled = body.isAppLockEnabled;
        if (typeof body.isBiometricEnabled === "boolean") settingsUpdate.isBiometricEnabled = body.isBiometricEnabled;
        if (typeof body.hideBalance === "boolean") settingsUpdate.hideBalance = body.hideBalance;
        if (typeof body.notificationsEnabled === "boolean") settingsUpdate.notificationsEnabled = body.notificationsEnabled;
        if (typeof body.hasCompletedOnboarding === "boolean") settingsUpdate.hasCompletedOnboarding = body.hasCompletedOnboarding;
        if (typeof body.autoLockTimeout === "number") settingsUpdate.autoLockTimeout = body.autoLockTimeout;
        if (body.reportLocale === "auto" || body.reportLocale === "id" || body.reportLocale === "en") settingsUpdate.reportLocale = body.reportLocale;

        if (Object.keys(userUpdate).length > 0) {
            await updateUser(userId, userUpdate);
        }

        if (Object.keys(settingsUpdate).length > 0) {
            let current = await getUserSettings(userId);
            if (!current) {
                const db = getDb();
                current = await db.insert(userSettings).values({
                    userId,
                    hourlyRate: 50000,
                    hideBalance: false,
                    hasCompletedOnboarding: false,
                }).returning().get();
            }
            await updateUserSettings(userId, settingsUpdate);
        }

        return NextResponse.json({ success: true });
    } catch (error) {
        console.error("Mobile profile PATCH API error:", error);
        return NextResponse.json(
            { success: false, code: "SERVER_ERROR", error: "Gagal update profile mobile" },
            { status: 500 }
        );
    }
}

