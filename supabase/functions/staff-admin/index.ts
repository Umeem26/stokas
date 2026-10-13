import { createClient } from "npm:@supabase/supabase-js@2";

// Samakan dengan konstanta di aplikasi. TLD .invalid dicadangkan standar internet.
const STAFF_EMAIL_DOMAIN = "staff.pos.invalid";
const ROLES = ["owner", "cashier", "warehouse"];

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Metode tidak didukung" }, 405);

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // 1) Hanya owner aktif yang boleh memanggil.
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer /i, "");
  const { data: caller, error: callerErr } = await admin.auth.getUser(token);
  if (callerErr || !caller.user) return json({ error: "Tidak terautentikasi" }, 401);
  const { data: prof } = await admin
    .from("profiles")
    .select("role,is_active")
    .eq("id", caller.user.id)
    .maybeSingle();
  if (!prof || !prof.is_active || prof.role !== "owner") {
    return json({ error: "Hanya owner yang boleh mengelola akun" }, 403);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Isi permintaan tidak valid" }, 400);
  }
  const action = String(body.action ?? "");
  const password = String(body.password ?? "");
  const userId = String(body.user_id ?? "");
  const uuid = /^[0-9a-f-]{36}$/i;

  if (action === "create") {
    const username = String(body.username ?? "").trim().toLowerCase();
    const fullName = String(body.full_name ?? "").trim();
    const role = String(body.role ?? "");
    if (!/^[a-z0-9._@+-]{3,60}$/.test(username)) {
      return json({ error: "Username 3-60 karakter: huruf, angka, titik, strip, garis bawah" }, 400);
    }
    if (!fullName || fullName.length > 80) return json({ error: "Nama wajib diisi (maks 80 karakter)" }, 400);
    if (!ROLES.includes(role)) return json({ error: "Peran tidak valid" }, 400);
    if (password.length < 8) return json({ error: "Password minimal 8 karakter" }, 400);

    const email = username.includes("@") ? username : `${username}@${STAFF_EMAIL_DOMAIN}`;
    const { data, error } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      app_metadata: { role },
      user_metadata: { full_name: fullName },
    });
    if (error) {
      const dup = /already|registered|exists/i.test(error.message);
      return json({ error: dup ? "Username sudah dipakai" : error.message }, dup ? 409 : 400);
    }
    return json({ id: data.user.id, email });
  }

  if (action === "set_password") {
    if (!uuid.test(userId)) return json({ error: "user_id tidak valid" }, 400);
    if (password.length < 8) return json({ error: "Password minimal 8 karakter" }, 400);
    const { error } = await admin.auth.admin.updateUserById(userId, { password });
    if (error) return json({ error: error.message }, 400);
    return json({ ok: true });
  }

  if (action === "set_active") {
    if (!uuid.test(userId)) return json({ error: "user_id tidak valid" }, 400);
    if (userId === caller.user.id) return json({ error: "Tidak bisa menonaktifkan akun sendiri" }, 400);
    const isActive = body.is_active === true;
    const { error: pe } = await admin.from("profiles").update({ is_active: isActive }).eq("id", userId);
    if (pe) return json({ error: pe.message }, 400);
    // Blokir/aktifkan sesi login akun tersebut.
    const { error: ae } = await admin.auth.admin.updateUserById(userId, {
      ban_duration: isActive ? "none" : "876000h",
    });
    if (ae) return json({ error: ae.message }, 400);
    return json({ ok: true });
  }

  return json({ error: "Aksi tidak dikenal" }, 400);
});
