-- CreateEnum: PaymentMethod
DO $$ BEGIN
    CREATE TYPE "PaymentMethod" AS ENUM ('QRIS', 'VIRTUAL_ACCOUNT');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- CreateEnum: PaymentIntentStatus
DO $$ BEGIN
    CREATE TYPE "PaymentIntentStatus" AS ENUM ('PENDING', 'PAID', 'EXPIRED', 'FAILED');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- CreateTable: payment_intents
CREATE TABLE IF NOT EXISTS "payment_intents" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "provider" TEXT NOT NULL,
    "reference_id" TEXT NOT NULL,
    "provider_ref" TEXT,
    "amount" BIGINT NOT NULL,
    "method" "PaymentMethod" NOT NULL,
    "status" "PaymentIntentStatus" NOT NULL DEFAULT 'PENDING',
    "qr_string" TEXT,
    "va_number" TEXT,
    "bank_code" TEXT,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "paid_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "payment_intents_pkey" PRIMARY KEY ("id")
);

-- CreateTable: webhook_events
CREATE TABLE IF NOT EXISTS "webhook_events" (
    "id" TEXT NOT NULL,
    "provider" TEXT NOT NULL,
    "event_id" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "status" TEXT NOT NULL,
    "processed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "webhook_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX IF NOT EXISTS "payment_intents_reference_id_key" ON "payment_intents"("reference_id");
CREATE INDEX IF NOT EXISTS "payment_intents_user_id_created_at_idx" ON "payment_intents"("user_id", "created_at");
CREATE INDEX IF NOT EXISTS "payment_intents_status_expires_at_idx" ON "payment_intents"("status", "expires_at");

-- CreateIndex
CREATE UNIQUE INDEX IF NOT EXISTS "webhook_events_event_id_key" ON "webhook_events"("event_id");
CREATE INDEX IF NOT EXISTS "webhook_events_provider_event_id_idx" ON "webhook_events"("provider", "event_id");

-- AddForeignKey
DO $$ BEGIN
    ALTER TABLE "payment_intents" ADD CONSTRAINT "payment_intents_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Add Check Constraint for positive amount on payment_intents
DO $$ BEGIN
    ALTER TABLE "payment_intents" ADD CONSTRAINT "check_payment_intents_amount_positive" CHECK (amount > 0);
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;
