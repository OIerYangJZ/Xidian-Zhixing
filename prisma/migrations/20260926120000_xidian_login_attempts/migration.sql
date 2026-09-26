CREATE TYPE "XidianLoginStatus" AS ENUM ('PENDING', 'APPROVED', 'FAILED');

CREATE TABLE "XidianLoginAttempt" (
  "id" TEXT NOT NULL,
  "state" TEXT NOT NULL,
  "callbackUrl" TEXT NOT NULL DEFAULT '/feed',
  "status" "XidianLoginStatus" NOT NULL DEFAULT 'PENDING',
  "userId" TEXT,
  "expiresAt" TIMESTAMP(3) NOT NULL,
  "consumedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "XidianLoginAttempt_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "XidianLoginAttempt_state_key" ON "XidianLoginAttempt"("state");
CREATE INDEX "XidianLoginAttempt_status_expiresAt_idx" ON "XidianLoginAttempt"("status", "expiresAt");
CREATE INDEX "XidianLoginAttempt_userId_createdAt_idx" ON "XidianLoginAttempt"("userId", "createdAt");
ALTER TABLE "XidianLoginAttempt" ADD CONSTRAINT "XidianLoginAttempt_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
