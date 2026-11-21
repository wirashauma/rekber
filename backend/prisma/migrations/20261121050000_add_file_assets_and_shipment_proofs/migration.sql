-- CreateEnum
CREATE TYPE "FilePurpose" AS ENUM ('SHIPMENT_PROOF', 'DISPUTE_EVIDENCE', 'KYC_ID', 'KYC_SELFIE', 'CHAT_IMAGE');

-- CreateTable
CREATE TABLE "file_assets" (
    "id" TEXT NOT NULL,
    "owner_id" TEXT NOT NULL,
    "purpose" "FilePurpose" NOT NULL,
    "storage_key" TEXT NOT NULL,
    "mime" TEXT NOT NULL,
    "size" INTEGER NOT NULL,
    "sha256" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMP(3),

    CONSTRAINT "file_assets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "shipment_proofs" (
    "id" TEXT NOT NULL,
    "transaction_id" TEXT NOT NULL,
    "submitted_by_id" TEXT NOT NULL,
    "courier" TEXT,
    "tracking_number" TEXT,
    "note" TEXT,
    "file_ids" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "shipment_proofs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "file_assets_storage_key_key" ON "file_assets"("storage_key");

-- CreateIndex
CREATE INDEX "file_assets_owner_id_deleted_at_idx" ON "file_assets"("owner_id", "deleted_at");

-- CreateIndex
CREATE INDEX "file_assets_purpose_deleted_at_idx" ON "file_assets"("purpose", "deleted_at");

-- CreateIndex
CREATE UNIQUE INDEX "shipment_proofs_transaction_id_key" ON "shipment_proofs"("transaction_id");

-- AddForeignKey
ALTER TABLE "file_assets" ADD CONSTRAINT "file_assets_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "shipment_proofs" ADD CONSTRAINT "shipment_proofs_transaction_id_fkey" FOREIGN KEY ("transaction_id") REFERENCES "transactions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "shipment_proofs" ADD CONSTRAINT "shipment_proofs_submitted_by_id_fkey" FOREIGN KEY ("submitted_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
