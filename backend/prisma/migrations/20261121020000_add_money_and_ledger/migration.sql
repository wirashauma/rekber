-- AlterEnum: Add REFUNDED to TransactionStatus
ALTER TYPE "TransactionStatus" ADD VALUE IF NOT EXISTS 'REFUNDED';

-- CreateEnum: FeePayer
DO $$ BEGIN
    CREATE TYPE "FeePayer" AS ENUM ('BUYER', 'SELLER', 'SPLIT');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- CreateEnum: LedgerType
DO $$ BEGIN
    CREATE TYPE "LedgerType" AS ENUM ('TOPUP', 'ESCROW_HOLD', 'ESCROW_RELEASE', 'ESCROW_REFUND', 'PLATFORM_FEE', 'WITHDRAWAL_RESERVE', 'WITHDRAWAL_RELEASE', 'ADJUSTMENT');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- CreateEnum: LedgerDirection
DO $$ BEGIN
    CREATE TYPE "LedgerDirection" AS ENUM ('CREDIT', 'DEBIT');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- AlterTable users: Convert balance from Float to BigInt (rounded)
ALTER TABLE "users" ALTER COLUMN "balance" DROP DEFAULT;
ALTER TABLE "users" ALTER COLUMN "balance" TYPE BIGINT USING ROUND("balance")::BIGINT;
ALTER TABLE "users" ALTER COLUMN "balance" SET DEFAULT 0;

-- AlterTable transactions: Convert amount from Float to BigInt (rounded) and add new escrow fields
ALTER TABLE "transactions" ALTER COLUMN "amount" TYPE BIGINT USING ROUND("amount")::BIGINT;

ALTER TABLE "transactions" ADD COLUMN "code" TEXT;
ALTER TABLE "transactions" ADD COLUMN "buyer_fee" BIGINT NOT NULL DEFAULT 0;
ALTER TABLE "transactions" ADD COLUMN "seller_fee" BIGINT NOT NULL DEFAULT 0;
ALTER TABLE "transactions" ADD COLUMN "fee_payer" "FeePayer" NOT NULL DEFAULT 'SPLIT';
ALTER TABLE "transactions" ADD COLUMN "held_amount" BIGINT NOT NULL DEFAULT 0;
ALTER TABLE "transactions" ADD COLUMN "paid_at" TIMESTAMP(3);
ALTER TABLE "transactions" ADD COLUMN "shipped_at" TIMESTAMP(3);
ALTER TABLE "transactions" ADD COLUMN "completed_at" TIMESTAMP(3);
ALTER TABLE "transactions" ADD COLUMN "cancelled_at" TIMESTAMP(3);
ALTER TABLE "transactions" ADD COLUMN "cancel_reason" TEXT;
ALTER TABLE "transactions" ADD COLUMN "auto_release_at" TIMESTAMP(3);
ALTER TABLE "transactions" ADD COLUMN "expires_at" TIMESTAMP(3);
ALTER TABLE "transactions" ADD COLUMN "reminder_sent_at" TIMESTAMP(3);

-- Backfill unambiguous 8-char codes for any existing transactions
DO $$
DECLARE
  chars text := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  rec RECORD;
  new_code text;
  i int;
BEGIN
  FOR rec IN SELECT id FROM transactions WHERE code IS NULL LOOP
    LOOP
      new_code := '';
      FOR i IN 1..8 LOOP
        new_code := new_code || substr(chars, floor(random() * 32 + 1)::int, 1);
      END LOOP;
      EXIT WHEN NOT EXISTS (SELECT 1 FROM transactions WHERE code = new_code);
    END LOOP;
    UPDATE transactions SET code = new_code WHERE id = rec.id;
  END LOOP;
END $$;

-- Enforce NOT NULL and UNIQUE on transaction code
ALTER TABLE "transactions" ALTER COLUMN "code" SET NOT NULL;
CREATE UNIQUE INDEX "transactions_code_key" ON "transactions"("code");

-- CreateTable: ledger_entries
CREATE TABLE "ledger_entries" (
    "id" TEXT NOT NULL,
    "user_id" TEXT,
    "transaction_id" TEXT,
    "type" "LedgerType" NOT NULL,
    "direction" "LedgerDirection" NOT NULL,
    "amount" BIGINT NOT NULL,
    "balance_after" BIGINT NOT NULL,
    "idempotency_key" TEXT NOT NULL,
    "reference_type" TEXT,
    "reference_id" TEXT,
    "metadata" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ledger_entries_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "ledger_entries_idempotency_key_key" ON "ledger_entries"("idempotency_key");
CREATE INDEX "ledger_entries_user_id_created_at_idx" ON "ledger_entries"("user_id", "created_at");
CREATE INDEX "ledger_entries_transaction_id_idx" ON "ledger_entries"("transaction_id");

ALTER TABLE "ledger_entries" ADD CONSTRAINT "ledger_entries_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "ledger_entries" ADD CONSTRAINT "ledger_entries_transaction_id_fkey" FOREIGN KEY ("transaction_id") REFERENCES "transactions"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- CreateTable: platform_settings
CREATE TABLE "platform_settings" (
    "key" TEXT NOT NULL,
    "value" TEXT NOT NULL,
    "updated_by_id" TEXT,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "platform_settings_pkey" PRIMARY KEY ("key")
);

-- Integrity Constraints (CHECK constraints)
ALTER TABLE "users" ADD CONSTRAINT "check_users_balance_non_negative" CHECK ("balance" >= 0);
ALTER TABLE "transactions" ADD CONSTRAINT "check_transactions_held_amount_non_negative" CHECK ("held_amount" >= 0);
ALTER TABLE "ledger_entries" ADD CONSTRAINT "check_ledger_entries_amount_positive" CHECK ("amount" > 0);
ALTER TABLE "transactions" ADD CONSTRAINT "check_transactions_buyer_not_seller" CHECK ("buyer_id" <> "seller_id");
