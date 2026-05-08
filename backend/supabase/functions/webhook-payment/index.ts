// REKBER - Payment Webhook (Mock)
// Simulates callback from Xendit/Midtrans after payment confirmation
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

    const { payment_reference, status } = await req.json();

    if (status !== "PAID") {
      return new Response(JSON.stringify({ message: "Payment not confirmed" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Find transaction by payment reference
    const { data: tx } = await supabaseAdmin
      .from("transactions").select("*")
      .eq("payment_reference", payment_reference).single();

    if (!tx || tx.status !== "awaiting_payment") {
      return new Response(JSON.stringify({ error: "Transaction not found or already processed" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Process escrow via DB function
    await supabaseAdmin.rpc("process_escrow_payment", { p_transaction_id: tx.id });

    return new Response(JSON.stringify({ success: true, message: "Escrow activated" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (error) {
    console.error("Webhook error:", error);
    return new Response(JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
