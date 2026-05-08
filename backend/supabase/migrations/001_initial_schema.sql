-- ============================================================
-- REKBER - Automated Escrow Platform
-- Database Schema v1.0
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- ENUM TYPES
-- ============================================================

CREATE TYPE user_role AS ENUM ('buyer', 'seller', 'admin');
CREATE TYPE kyc_status AS ENUM ('none', 'pending', 'verified', 'rejected');
CREATE TYPE transaction_status AS ENUM (
  'awaiting_payment',
  'escrow',
  'processed',
  'shipped',
  'completed',
  'disputed',
  'refunded',
  'cancelled'
);
CREATE TYPE payment_method AS ENUM ('virtual_account', 'qris', 'ewallet');
CREATE TYPE message_type AS ENUM ('text', 'image', 'system', 'proof');
CREATE TYPE proof_type AS ENUM ('shipping', 'delivery', 'receipt');
CREATE TYPE withdrawal_status AS ENUM ('pending', 'processing', 'completed', 'failed');

-- ============================================================
-- 1. USERS TABLE
-- ============================================================
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT NOT NULL,
  phone TEXT,
  avatar_url TEXT,
  role user_role NOT NULL DEFAULT 'buyer',
  kyc_status kyc_status NOT NULL DEFAULT 'none',
  id_card_url TEXT,
  selfie_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Auto-update timestamp trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 2. WALLETS TABLE
-- ============================================================
CREATE TABLE public.wallets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  available_balance BIGINT NOT NULL DEFAULT 0 CHECK (available_balance >= 0),
  escrow_balance BIGINT NOT NULL DEFAULT 0 CHECK (escrow_balance >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER set_wallets_updated_at
  BEFORE UPDATE ON public.wallets
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Auto-create wallet when user is created
CREATE OR REPLACE FUNCTION create_wallet_for_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.wallets (user_id) VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_user_created_create_wallet
  AFTER INSERT ON public.users
  FOR EACH ROW EXECUTE FUNCTION create_wallet_for_user();

-- ============================================================
-- 3. BANK ACCOUNTS TABLE
-- ============================================================
CREATE TABLE public.bank_accounts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  bank_name TEXT NOT NULL,
  account_number TEXT NOT NULL,
  account_holder TEXT NOT NULL,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER set_bank_accounts_updated_at
  BEFORE UPDATE ON public.bank_accounts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Ensure only one primary bank account per user
CREATE OR REPLACE FUNCTION ensure_single_primary_bank()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_primary THEN
    UPDATE public.bank_accounts
    SET is_primary = false
    WHERE user_id = NEW.user_id AND id != NEW.id AND is_primary = true;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_single_primary_bank
  BEFORE INSERT OR UPDATE ON public.bank_accounts
  FOR EACH ROW EXECUTE FUNCTION ensure_single_primary_bank();

-- ============================================================
-- 4. PRODUCTS TABLE
-- ============================================================
CREATE TABLE public.products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  price BIGINT NOT NULL CHECK (price > 0),
  image_url TEXT,
  category TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER set_products_updated_at
  BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 5. TRANSACTIONS TABLE
-- ============================================================

-- Sequence for readable transaction codes
CREATE SEQUENCE tx_code_seq START 1000;

CREATE OR REPLACE FUNCTION generate_tx_code()
RETURNS TEXT AS $$
BEGIN
  RETURN 'RKB-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(nextval('tx_code_seq')::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql;

CREATE TABLE public.transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tx_code TEXT UNIQUE NOT NULL DEFAULT generate_tx_code(),
  buyer_id UUID NOT NULL REFERENCES public.users(id),
  seller_id UUID NOT NULL REFERENCES public.users(id),
  product_id UUID REFERENCES public.products(id),
  amount BIGINT NOT NULL CHECK (amount > 0),
  platform_fee BIGINT NOT NULL DEFAULT 0 CHECK (platform_fee >= 0),
  status transaction_status NOT NULL DEFAULT 'awaiting_payment',
  description TEXT,
  payment_method payment_method,
  payment_reference TEXT,
  metadata JSONB DEFAULT '{}',
  paid_at TIMESTAMPTZ,
  shipped_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  disputed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Buyer and seller cannot be the same
  CONSTRAINT different_parties CHECK (buyer_id != seller_id)
);

CREATE TRIGGER set_transactions_updated_at
  BEFORE UPDATE ON public.transactions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Index for fast transaction lookups
CREATE INDEX idx_transactions_buyer ON public.transactions(buyer_id);
CREATE INDEX idx_transactions_seller ON public.transactions(seller_id);
CREATE INDEX idx_transactions_status ON public.transactions(status);
CREATE INDEX idx_transactions_tx_code ON public.transactions(tx_code);

-- ============================================================
-- 6. CHAT MESSAGES TABLE
-- ============================================================
CREATE TABLE public.chat_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  transaction_id UUID NOT NULL REFERENCES public.transactions(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES public.users(id),  -- NULL for system messages
  message TEXT,
  type message_type NOT NULL DEFAULT 'text',
  attachment_url TEXT,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_chat_messages_transaction ON public.chat_messages(transaction_id, created_at);

-- ============================================================
-- 7. TRANSACTION PROOFS TABLE
-- ============================================================
CREATE TABLE public.transaction_proofs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  transaction_id UUID NOT NULL REFERENCES public.transactions(id) ON DELETE CASCADE,
  uploaded_by UUID NOT NULL REFERENCES public.users(id),
  proof_type proof_type NOT NULL,
  file_url TEXT NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_proofs_transaction ON public.transaction_proofs(transaction_id);

-- ============================================================
-- 8. WITHDRAWALS TABLE
-- ============================================================
CREATE TABLE public.withdrawals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id),
  bank_account_id UUID NOT NULL REFERENCES public.bank_accounts(id),
  amount BIGINT NOT NULL CHECK (amount > 0),
  fee BIGINT NOT NULL DEFAULT 0,
  status withdrawal_status NOT NULL DEFAULT 'pending',
  reference TEXT,
  notes TEXT,
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER set_withdrawals_updated_at
  BEFORE UPDATE ON public.withdrawals
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 9. ESCROW STATE MACHINE FUNCTIONS
-- ============================================================

-- Function to move funds into escrow after payment
CREATE OR REPLACE FUNCTION process_escrow_payment(p_transaction_id UUID)
RETURNS VOID AS $$
DECLARE
  v_tx RECORD;
BEGIN
  SELECT * INTO v_tx FROM public.transactions WHERE id = p_transaction_id;
  
  IF v_tx.status != 'awaiting_payment' THEN
    RAISE EXCEPTION 'Transaction is not awaiting payment. Current status: %', v_tx.status;
  END IF;

  -- Update transaction status
  UPDATE public.transactions
  SET status = 'escrow', paid_at = NOW()
  WHERE id = p_transaction_id;

  -- Add funds to seller's escrow balance
  UPDATE public.wallets
  SET escrow_balance = escrow_balance + v_tx.amount
  WHERE user_id = v_tx.seller_id;

  -- Insert system message in chat
  INSERT INTO public.chat_messages (transaction_id, message, type)
  VALUES (p_transaction_id, 'Payment confirmed. Funds are now in escrow. Seller, please process this order.', 'system');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to release escrow funds to seller
CREATE OR REPLACE FUNCTION release_escrow_funds(p_transaction_id UUID)
RETURNS VOID AS $$
DECLARE
  v_tx RECORD;
  v_net_amount BIGINT;
BEGIN
  SELECT * INTO v_tx FROM public.transactions WHERE id = p_transaction_id;
  
  IF v_tx.status NOT IN ('shipped', 'disputed') THEN
    RAISE EXCEPTION 'Cannot release funds. Current status: %', v_tx.status;
  END IF;

  v_net_amount := v_tx.amount - v_tx.platform_fee;

  -- Move from escrow to available
  UPDATE public.wallets
  SET escrow_balance = escrow_balance - v_tx.amount,
      available_balance = available_balance + v_net_amount
  WHERE user_id = v_tx.seller_id;

  -- Update transaction
  UPDATE public.transactions
  SET status = 'completed', completed_at = NOW()
  WHERE id = p_transaction_id;

  -- System message
  INSERT INTO public.chat_messages (transaction_id, message, type)
  VALUES (p_transaction_id, 'Order completed! Funds have been released to the seller.', 'system');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to refund escrow to buyer
CREATE OR REPLACE FUNCTION refund_escrow_funds(p_transaction_id UUID)
RETURNS VOID AS $$
DECLARE
  v_tx RECORD;
BEGIN
  SELECT * INTO v_tx FROM public.transactions WHERE id = p_transaction_id;
  
  IF v_tx.status != 'disputed' THEN
    RAISE EXCEPTION 'Can only refund disputed transactions. Current status: %', v_tx.status;
  END IF;

  -- Remove from seller escrow
  UPDATE public.wallets
  SET escrow_balance = escrow_balance - v_tx.amount
  WHERE user_id = v_tx.seller_id;

  -- Refund to buyer (add to available balance as wallet credit)
  UPDATE public.wallets
  SET available_balance = available_balance + v_tx.amount
  WHERE user_id = v_tx.buyer_id;

  -- Update transaction
  UPDATE public.transactions
  SET status = 'refunded', completed_at = NOW()
  WHERE id = p_transaction_id;

  -- System message
  INSERT INTO public.chat_messages (transaction_id, message, type)
  VALUES (p_transaction_id, 'Dispute resolved. Funds have been refunded to the buyer.', 'system');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 10. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transaction_proofs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.withdrawals ENABLE ROW LEVEL SECURITY;

-- ---- USERS ----
CREATE POLICY "Users can view their own profile"
  ON public.users FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can view other users basic info"
  ON public.users FOR SELECT
  USING (true);  -- Public profiles; sensitive fields handled at app level

CREATE POLICY "Users can update their own profile"
  ON public.users FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile"
  ON public.users FOR INSERT
  WITH CHECK (auth.uid() = id);

-- ---- WALLETS ----
CREATE POLICY "Users can view their own wallet"
  ON public.wallets FOR SELECT
  USING (auth.uid() = user_id);

-- Wallet updates are handled by SECURITY DEFINER functions only
CREATE POLICY "No direct wallet updates"
  ON public.wallets FOR UPDATE
  USING (false);

-- ---- BANK ACCOUNTS ----
CREATE POLICY "Users can manage their own bank accounts"
  ON public.bank_accounts FOR ALL
  USING (auth.uid() = user_id);

-- ---- PRODUCTS ----
CREATE POLICY "Anyone can view active products"
  ON public.products FOR SELECT
  USING (is_active = true);

CREATE POLICY "Sellers can manage their own products"
  ON public.products FOR ALL
  USING (auth.uid() = seller_id);

-- ---- TRANSACTIONS ----
CREATE POLICY "Parties can view their transactions"
  ON public.transactions FOR SELECT
  USING (auth.uid() = buyer_id OR auth.uid() = seller_id);

CREATE POLICY "Buyers can create transactions"
  ON public.transactions FOR INSERT
  WITH CHECK (auth.uid() = buyer_id);

CREATE POLICY "Parties can update their transactions"
  ON public.transactions FOR UPDATE
  USING (auth.uid() = buyer_id OR auth.uid() = seller_id);

-- ---- CHAT MESSAGES ----
CREATE POLICY "Transaction parties can view chat"
  ON public.chat_messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.transactions t
      WHERE t.id = transaction_id
      AND (t.buyer_id = auth.uid() OR t.seller_id = auth.uid())
    )
  );

CREATE POLICY "Transaction parties can send messages"
  ON public.chat_messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id AND
    EXISTS (
      SELECT 1 FROM public.transactions t
      WHERE t.id = transaction_id
      AND (t.buyer_id = auth.uid() OR t.seller_id = auth.uid())
      AND t.status NOT IN ('awaiting_payment', 'cancelled', 'completed', 'refunded')
    )
  );

-- ---- TRANSACTION PROOFS ----
CREATE POLICY "Transaction parties can view proofs"
  ON public.transaction_proofs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.transactions t
      WHERE t.id = transaction_id
      AND (t.buyer_id = auth.uid() OR t.seller_id = auth.uid())
    )
  );

CREATE POLICY "Parties can upload proofs"
  ON public.transaction_proofs FOR INSERT
  WITH CHECK (
    auth.uid() = uploaded_by AND
    EXISTS (
      SELECT 1 FROM public.transactions t
      WHERE t.id = transaction_id
      AND (t.buyer_id = auth.uid() OR t.seller_id = auth.uid())
    )
  );

-- ---- WITHDRAWALS ----
CREATE POLICY "Users can view their own withdrawals"
  ON public.withdrawals FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create withdrawal requests"
  ON public.withdrawals FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 11. REALTIME SUBSCRIPTIONS
-- ============================================================

-- Enable realtime for key tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.transactions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.wallets;

-- ============================================================
-- 12. STORAGE BUCKETS (run via Supabase dashboard or API)
-- ============================================================
-- bucket: kyc-documents (private, for ID cards & selfies)
-- bucket: transaction-proofs (private, for shipping/delivery photos)
-- bucket: product-images (public, for product catalog)
-- bucket: chat-attachments (private, for chat file uploads)
-- bucket: avatars (public, for user profile pictures)
