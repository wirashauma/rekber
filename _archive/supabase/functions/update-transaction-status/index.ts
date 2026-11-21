// ============================================================
// REKBER - Update Transaction Status Edge Function
// ============================================================
// Handles escrow state machine transitions with validation
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Define valid state transitions and who can trigger them
const STATE_TRANSITIONS: Record<string, { nextStates: string[]; allowedRoles: string[] }> = {
  awaiting_payment: {
    nextStates: ["escrow", "cancelled"],
    allowedRoles: ["system", "buyer"], // system for payment webhook, buyer for cancel
  },
  escrow: {
    nextStates: ["processed"],
    allowedRoles: ["seller"],
  },
  processed: {
    nextStates: ["shipped"],
    allowedRoles: ["seller"],
  },
  shipped: {
    nextStates: ["completed", "disputed"],
    allowedRoles: ["buyer"],
  },
  disputed: {
    nextStates: ["completed", "refunded"],
    allowedRoles: ["admin"],
  },
};

const STATUS_MESSAGES: Record<string, string> = {
  escrow: "✅ Payment confirmed! Funds are secured in escrow.",
  processed: "📦 Seller is processing your order.",
  shipped: "🚚 Order has been shipped! Tracking info added.",
  completed: "🎉 Transaction completed. Funds released to seller.",
  disputed: "⚠️ Dispute raised. An admin will review this case.",
  refunded: "💰 Dispute resolved. Funds refunded to buyer.",
  cancelled: "❌ Transaction cancelled.",
};

interface UpdateStatusRequest {
  transaction_id: string;
  new_status: string;
  notes?: string;
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

    // Authenticate
    const { data: { user }, error: authError } = await supabaseUser.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body: UpdateStatusRequest = await req.json();
    const { transaction_id, new_status, notes } = body;

    // Get transaction
    const { data: tx, error: txError } = await supabaseAdmin
      .from("transactions")
      .select("*, buyer:users!transactions_buyer_id_fkey(role), seller:users!transactions_seller_id_fkey(role)")
      .eq("id", transaction_id)
      .single();

    if (txError || !tx) {
      return new Response(
        JSON.stringify({ error: "Transaction not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Determine user's role in this transaction
    let userRole: string;
    if (user.id === tx.buyer_id) userRole = "buyer";
    else if (user.id === tx.seller_id) userRole = "seller";
    else {
      // Check if user is admin
      const { data: userData } = await supabaseAdmin
        .from("users")
        .select("role")
        .eq("id", user.id)
        .single();
      userRole = userData?.role === "admin" ? "admin" : "none";
    }

    // Validate state transition
    const currentTransition = STATE_TRANSITIONS[tx.status];
    if (!currentTransition) {
      return new Response(
        JSON.stringify({ error: `No transitions available from status: ${tx.status}` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!currentTransition.nextStates.includes(new_status)) {
      return new Response(
        JSON.stringify({ error: `Cannot transition from ${tx.status} to ${new_status}` }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!currentTransition.allowedRoles.includes(userRole)) {
      return new Response(
        JSON.stringify({ error: `${userRole} cannot perform this action` }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Execute state transition with side effects
    const updateData: Record<string, unknown> = { status: new_status };

    switch (new_status) {
      case "escrow":
        // Use the DB function for escrow processing
        await supabaseAdmin.rpc("process_escrow_payment", { p_transaction_id: transaction_id });
        break;

      case "completed":
        // Release funds
        await supabaseAdmin.rpc("release_escrow_funds", { p_transaction_id: transaction_id });
        break;

      case "refunded":
        // Refund funds
        await supabaseAdmin.rpc("refund_escrow_funds", { p_transaction_id: transaction_id });
        break;

      case "disputed":
        updateData.disputed_at = new Date().toISOString();
        await supabaseAdmin.from("transactions").update(updateData).eq("id", transaction_id);
        // Insert system chat message
        await supabaseAdmin.from("chat_messages").insert({
          transaction_id: transaction_id,
          message: STATUS_MESSAGES[new_status] + (notes ? ` Reason: ${notes}` : ""),
          type: "system",
        });
        break;

      case "shipped":
        updateData.shipped_at = new Date().toISOString();
        await supabaseAdmin.from("transactions").update(updateData).eq("id", transaction_id);
        await supabaseAdmin.from("chat_messages").insert({
          transaction_id: transaction_id,
          message: STATUS_MESSAGES[new_status],
          type: "system",
        });
        break;

      default:
        await supabaseAdmin.from("transactions").update(updateData).eq("id", transaction_id);
        await supabaseAdmin.from("chat_messages").insert({
          transaction_id: transaction_id,
          message: STATUS_MESSAGES[new_status] || `Status updated to ${new_status}`,
          type: "system",
        });
    }

    // Fetch updated transaction
    const { data: updatedTx } = await supabaseAdmin
      .from("transactions")
      .select("*")
      .eq("id", transaction_id)
      .single();

    return new Response(
      JSON.stringify({
        success: true,
        transaction: updatedTx,
        message: STATUS_MESSAGES[new_status],
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Status update error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
