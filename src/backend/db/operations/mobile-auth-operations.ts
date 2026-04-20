import { getDb } from "../index";
import { mobileRefreshTokens, type MobileRefreshToken } from "../schema";
import { and, eq, gt, isNull } from "drizzle-orm";

interface CreateMobileRefreshTokenInput {
    userId: number;
    tokenHash: string;
    expiresAt: Date;
    deviceInfo?: string | null;
    ipAddress?: string | null;
}

export async function createMobileRefreshTokenRecord(
    data: CreateMobileRefreshTokenInput
): Promise<MobileRefreshToken> {
    const db = getDb();
    return db.insert(mobileRefreshTokens).values({
        userId: data.userId,
        tokenHash: data.tokenHash,
        expiresAt: data.expiresAt,
        deviceInfo: data.deviceInfo ?? null,
        ipAddress: data.ipAddress ?? null,
    }).returning().get();
}

export async function getActiveMobileRefreshTokenByHash(tokenHash: string): Promise<MobileRefreshToken | undefined> {
    const db = getDb();
    return db.select()
        .from(mobileRefreshTokens)
        .where(and(
            eq(mobileRefreshTokens.tokenHash, tokenHash),
            isNull(mobileRefreshTokens.revokedAt),
            gt(mobileRefreshTokens.expiresAt, new Date())
        ))
        .get();
}

export async function revokeMobileRefreshTokenByHash(tokenHash: string, replacedByTokenHash?: string): Promise<void> {
    const db = getDb();
    await db.update(mobileRefreshTokens)
        .set({
            revokedAt: new Date(),
            replacedByTokenHash: replacedByTokenHash ?? null,
        })
        .where(eq(mobileRefreshTokens.tokenHash, tokenHash))
        .run();
}

export async function revokeAllMobileRefreshTokensByUserId(userId: number): Promise<void> {
    const db = getDb();
    await db.update(mobileRefreshTokens)
        .set({ revokedAt: new Date() })
        .where(and(
            eq(mobileRefreshTokens.userId, userId),
            isNull(mobileRefreshTokens.revokedAt)
        ))
        .run();
}

