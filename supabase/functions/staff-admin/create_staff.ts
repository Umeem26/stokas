// Logika aksi "create" dipisah tanpa import agar bisa dites (Deno/Node) dengan klien palsu.

type Err = { message: string } | null;

// Bagian klien admin Supabase yang dipakai di sini.
export interface StaffAdminClient {
  auth: {
    admin: {
      createUser(attrs: Record<string, unknown>): Promise<{ data: { user: { id: string } | null }; error: Err }>;
      deleteUser(id: string): Promise<{ error: Err }>;
    };
  };
  from(table: string): {
    update(values: Record<string, unknown>): {
      eq(column: string, value: string): {
        select(columns: string): PromiseLike<{ data: unknown[] | null; error: Err }>;
      };
    };
  };
}

export type CreateStaffResult =
  | { ok: true; id: string }
  | { ok: false; status: number; error: string };

export async function createStaff(
  admin: StaffAdminClient,
  input: { email: string; password: string; role: string; fullName: string },
): Promise<CreateStaffResult> {
  const { data, error } = await admin.auth.admin.createUser({
    email: input.email,
    password: input.password,
    email_confirm: true,
    app_metadata: { role: input.role },
    user_metadata: { full_name: input.fullName },
  });
  if (error || !data.user) {
    const msg = error?.message ?? "Gagal membuat akun";
    const dup = /already|registered|exists/i.test(msg);
    return { ok: false, status: dup ? 409 : 400, error: dup ? "Username sudah dipakai" : msg };
  }
  const id = data.user.id;

  // Trigger handle_new_user membaca app_metadata sebelum GoTrue menulisnya,
  // sehingga profil selalu 'cashier'. Tulis peran terpilih secara eksplisit.
  const { data: rows, error: pe } = await admin
    .from("profiles")
    .update({ role: input.role })
    .eq("id", id)
    .select("id");
  if (pe || !rows || rows.length === 0) {
    // Jangan tinggalkan akun setengah jadi.
    const { error: de } = await admin.auth.admin.deleteUser(id);
    const reason = pe?.message ?? "profil tidak ditemukan";
    return {
      ok: false,
      status: 500,
      error: de
        ? `Gagal menyimpan peran (${reason}) dan akun gagal dihapus: ${de.message}`
        : `Gagal menyimpan peran staf (${reason}); akun dibatalkan, coba lagi`,
    };
  }
  return { ok: true, id };
}
