import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return reply({ success: false, error: "Method not allowed." }, 405);

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const expectedCode = Deno.env.get("ADMIN_CODE");
    if (!expectedCode) return reply({ success: false, error: "ADMIN_CODE secret is not configured." }, 500);

    const authHeader = req.headers.get("Authorization") || "";
    const jwt = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
    if (!jwt) return reply({ success: false, error: "Sign in to the game first." }, 401);

    const authClient = createClient(url, anonKey, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: userData, error: userError } = await authClient.auth.getUser(jwt);
    if (userError || !userData.user) return reply({ success: false, error: "Your game session is invalid. Reload and try again." }, 401);

    const body = await req.json();
    const { action, code } = body ?? {};
    if (typeof code !== "string" || code.length > 128 || code !== expectedCode) {
      return reply({ success: false, error: "Incorrect admin code." }, 403);
    }
    if (action === "unlock") return reply({ success: true });

    const admin = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    if (action === "set_announcement") {
      const message = typeof body.message === "string" ? body.message.trim().slice(0, 120) : "";
      if (!message) return reply({ success: false, error: "Enter an announcement first." }, 400);
      const { error } = await admin.from("game_state")
        .update({ announcement: message, updated_at: new Date().toISOString() }).eq("id", 1);
      if (error) throw error;
      return reply({ success: true });
    }

    if (action === "clear_announcement") {
      const { error } = await admin.from("game_state")
        .update({ announcement: "", updated_at: new Date().toISOString() }).eq("id", 1);
      if (error) throw error;
      return reply({ success: true });
    }

    if (action === "start_event") {
      const allowed = ["Thanksgiving Eating", "Trick-or-Treat", "TV Station Takeover"];
      const name = typeof body.name === "string" ? body.name : "";
      const minutes = Number(body.minutes);
      let multiplier = Number(body.multiplier);
      if (!allowed.includes(name)) return reply({ success: false, error: "That event is not allowed." }, 400);
      if (!Number.isInteger(minutes) || minutes < 1 || minutes > 60) return reply({ success: false, error: "Event duration must be 1–60 minutes." }, 400);
      if (!Number.isInteger(multiplier) || multiplier < 1 || multiplier > 10) return reply({ success: false, error: "Multiplier must be 1–10." }, 400);
      if (name === "Thanksgiving Eating" || name === "Trick-or-Treat") multiplier = Math.max(10, multiplier);
      const active_event = { name, multiplier, endsAt: Date.now() + minutes * 60000 };
      const { error } = await admin.from("game_state")
        .update({ active_event, updated_at: new Date().toISOString() }).eq("id", 1);
      if (error) throw error;
      return reply({ success: true, active_event });
    }

    if (action === "stop_event") {
      const { error } = await admin.from("game_state")
        .update({ active_event: null, updated_at: new Date().toISOString() }).eq("id", 1);
      if (error) throw error;
      return reply({ success: true });
    }

    return reply({ success: false, error: "Unknown admin action." }, 400);
  } catch (error) {
    console.error("Admin function error:", error);
    return reply({ success: false, error: "The server could not complete that admin action." }, 500);
  }
});
