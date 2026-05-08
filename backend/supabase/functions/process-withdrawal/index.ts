import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const MINIMUM_WITHDRAWAL = 10000;
const WITHDRAWAL_FEE = 2500;

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization")!;

    const supabaseUser = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } },
    });
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { bank_account_id, amount } = await req.json();

    if (amount < MINIMUM_WITHDRAWAL) {
      return new Response(
        JSON.stringify({ error: `Minimum withdrawal is Rp ${MINIMUM_WITHDRAWAL.toLocaleString()}` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: bankAccount } = await supabaseAdmin
      .from("bank_accounts").select("*")
      .eq("id", bank_account_id).eq("user_id", user.id).single();

    if (!bankAccount) {
      return new Response(JSON.stringify({ error: "Bank account not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const { data: wallet } = await supabaseAdmin
      .from("wallets").select("*").eq("user_id", user.id).single();

    if (!wallet) {
      return new Response(JSON.stringify({ error: "Wallet not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const totalDeduction = amount + WITHDRAWAL_FEE;
    if (wallet.available_balance < totalDeduction) {
      return new Response(JSON.stringify({
        error: "Insufficient balance", available: wallet.available_balance,
        required: totalDeduction, fee: WITHDRAWAL_FEE,
      }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    await supabaseAdmin.from("wallets")
      .update({ available_balance: wallet.available_balance - totalDeduction })
      .eq("user_id", user.id);

    const { data: withdrawal, error: wdError } = await supabaseAdmin
      .from("withdrawals").insert({
        user_id: user.id, bank_account_id, amount, fee: WITHDRAWAL_FEE,
        status: "pending",
        reference: `WD-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      }).select().single();

    if (wdError) {
      await supabaseAdmin.from("wallets")
        .update({ available_balance: wallet.available_balance })
        .eq("user_id", user.id);
      return new Response(JSON.stringify({ error: "Failed to create withdrawal" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({
      success: true, withdrawal,
      message: "Withdrawal request submitted. Processing within 1x24 hours.",
      new_balance: wallet.available_balance - totalDeduction,
    }), { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (error) {
    console.error("Withdrawal error:", error);
    return new Response(JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
