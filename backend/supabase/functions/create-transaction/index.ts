// ============================================================
// REKBER - Create Transaction Edge Function
// ============================================================
// Creates a new escrow transaction between buyer and seller
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface CreateTransactionRequest {
  seller_email: string;
  amount: number;
  description: string;
  product_id?: string;
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization")!;

    // Client with user's auth context
    const supabaseUser = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } },
    });

    // Admin client for privileged operations
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

    // Get authenticated user
    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body: CreateTransactionRequest = await req.json();
    const { seller_email, amount, description, product_id } = body;

    // Validate input
    if (!seller_email || !amount || amount <= 0) {
      return new Response(
        JSON.stringify({ error: "Invalid input. Required: seller_email, amount (> 0)" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Find seller by email
    const { data: seller, error: sellerError } = await supabaseAdmin
      .from("users")
      .select("id, email, full_name, role")
      .eq("email", seller_email)
      .single();

    if (sellerError || !seller) {
      return new Response(
        JSON.stringify({ error: "Seller not found with that email" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Prevent self-transaction
    if (seller.id === user.id) {
      return new Response(
        JSON.stringify({ error: "Cannot create transaction with yourself" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Calculate platform fee (2.5%)
    const platformFee = Math.round(amount * 0.025);

    // Create transaction
    const { data: transaction, error: txError } = await supabaseAdmin
      .from("transactions")
      .insert({
        buyer_id: user.id,
        seller_id: seller.id,
        product_id: product_id || null,
        amount: amount,
        platform_fee: platformFee,
        description: description,
        status: "awaiting_payment",
        expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(), // 24h expiry
      })
      .select()
      .single();

    if (txError) {
      console.error("Transaction creation error:", txError);
      return new Response(
        JSON.stringify({ error: "Failed to create transaction" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        transaction: transaction,
        message: "Transaction created. Awaiting payment.",
      }),
      { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Unexpected error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
