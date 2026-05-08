// ============================================================
// REKBER - Process Payment Edge Function (Mock)
// ============================================================
// Simulates payment processing via Xendit/Midtrans
// In production, replace with actual payment gateway SDK
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface ProcessPaymentRequest {
  transaction_id: string;
  payment_method: "virtual_account" | "qris" | "ewallet";
  // Mock fields - in production these come from payment gateway
  ewallet_type?: string; // gopay, ovo, dana, shopeepay
  bank_code?: string;    // bca, bni, bri, mandiri
}

// Mock payment gateway response generators
function generateMockVAResponse(bankCode: string, amount: number) {
  const vaBanks: Record<string, string> = {
    bca: "BCA",
    bni: "BNI",
    bri: "BRI",
    mandiri: "Mandiri",
  };
  return {
    payment_id: `VA-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
    virtual_account_number: `${Math.floor(Math.random() * 9000000000000) + 1000000000000}`,
    bank_name: vaBanks[bankCode] || "BCA",
    amount: amount,
    expiry_date: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
    status: "PENDING",
  };
}

function generateMockQRISResponse(amount: number) {
  return {
    payment_id: `QRIS-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
    qr_string: `00020101021226670016COM.REKBER.WWW01189360091804${amount}0215ID10260000000110303UMI51440014ID.CO.QRIS.WWW0215ID102600000010303UMI5802ID5913REKBER ESCROW6007JAKARTA61051234062070703A01630${Math.floor(Math.random() * 100)}`,
    amount: amount,
    expiry_date: new Date(Date.now() + 30 * 60 * 1000).toISOString(), // 30 min expiry
    status: "PENDING",
  };
}

function generateMockEWalletResponse(ewalletType: string, amount: number) {
  return {
    payment_id: `EW-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
    ewallet_type: ewalletType.toUpperCase(),
    checkout_url: `https://mock-payment.rekber.app/${ewalletType}/checkout/${Date.now()}`,
    amount: amount,
    expiry_date: new Date(Date.now() + 60 * 60 * 1000).toISOString(), // 1h expiry
    status: "PENDING",
  };
}

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

    // Authenticate user
    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body: ProcessPaymentRequest = await req.json();
    const { transaction_id, payment_method, ewallet_type, bank_code } = body;

    // Get transaction
    const { data: tx, error: txError } = await supabaseAdmin
      .from("transactions")
      .select("*")
      .eq("id", transaction_id)
      .single();

    if (txError || !tx) {
      return new Response(
        JSON.stringify({ error: "Transaction not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify buyer owns this transaction
    if (tx.buyer_id !== user.id) {
      return new Response(
        JSON.stringify({ error: "Only the buyer can process payment" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (tx.status !== "awaiting_payment") {
      return new Response(
        JSON.stringify({ error: "Transaction is not awaiting payment" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Total amount including platform fee
    const totalAmount = tx.amount + tx.platform_fee;

    // Generate mock payment response based on method
    let paymentResponse;
    switch (payment_method) {
      case "virtual_account":
        paymentResponse = generateMockVAResponse(bank_code || "bca", totalAmount);
        break;
      case "qris":
        paymentResponse = generateMockQRISResponse(totalAmount);
        break;
      case "ewallet":
        paymentResponse = generateMockEWalletResponse(ewallet_type || "gopay", totalAmount);
        break;
      default:
        return new Response(
          JSON.stringify({ error: "Invalid payment method" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }

    // Update transaction with payment info
    await supabaseAdmin
      .from("transactions")
      .update({
        payment_method: payment_method,
        payment_reference: paymentResponse.payment_id,
        metadata: {
          ...tx.metadata,
          payment_details: paymentResponse,
        },
      })
      .eq("id", transaction_id);

    return new Response(
      JSON.stringify({
        success: true,
        payment: paymentResponse,
        message: `Payment initiated via ${payment_method}`,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Payment processing error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
