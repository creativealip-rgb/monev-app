import { randomBytes, createHash } from "crypto";
import { SignJWT, jwtVerify, type JWTPayload } from "jose";
import type { UserTier } from "@/lib/tier-gate";

const ACCESS_TOKEN_EXPIRES_IN = 60 * 15; // 15 menit
const REFRESH_TOKEN_EXPIRES_DAYS = 30; // 30 hari

export interface MobileAccessTokenPayload extends JWTPayload {
    sub: string;
    tier: UserTier;
    email?: string | null;
    name?: string | null;
    tokenType: "mobile-access";
}

function getMobileAuthSecret(): Uint8Array {
    const secret = process.env.AUTH_SECRET;
    if (!secret) {
        throw new Error("AUTH_SECRET is required for mobile auth.");
    }
    return new TextEncoder().encode(secret);
}

export async function createMobileAccessToken(input: {
    userId: number;
    tier: UserTier;
    email?: string | null;
    name?: string | null;
}): Promise<string> {
    return new SignJWT({
        tier: input.tier,
        email: input.email ?? null,
        name: input.name ?? null,
        tokenType: "mobile-access",
    })
        .setProtectedHeader({ alg: "HS256" })
        .setSubject(String(input.userId))
        .setIssuedAt()
        .setExpirationTime(`${ACCESS_TOKEN_EXPIRES_IN}s`)
        .sign(getMobileAuthSecret());
}

export async function verifyMobileAccessToken(token: string): Promise<MobileAccessTokenPayload | null> {
    try {
        const { payload } = await jwtVerify(token, getMobileAuthSecret());
        if (payload.tokenType !== "mobile-access" || !payload.sub || !payload.tier) {
            return null;
        }
        return payload as MobileAccessTokenPayload;
    } catch {
        return null;
    }
}

export function generateMobileRefreshToken(): string {
    return randomBytes(48).toString("base64url");
}

export function hashMobileRefreshToken(token: string): string {
    return createHash("sha256").update(token).digest("hex");
}

export function getMobileAccessTokenExpiresInSeconds(): number {
    return ACCESS_TOKEN_EXPIRES_IN;
}

export function getMobileRefreshTokenExpiresAt(): Date {
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + REFRESH_TOKEN_EXPIRES_DAYS);
    return expiresAt;
}

export function getBearerTokenFromAuthHeader(authorizationHeader: string | null): string | null {
    if (!authorizationHeader) return null;
    const [scheme, token] = authorizationHeader.split(" ");
    if (scheme !== "Bearer" || !token) return null;
    return token;
}

