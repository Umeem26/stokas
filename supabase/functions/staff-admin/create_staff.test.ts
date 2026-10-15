// Jalankan: deno test supabase/functions/staff-admin/
//       atau: node --experimental-strip-types --test supabase/functions/staff-admin/create_staff.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { createStaff, type StaffAdminClient } from "./create_staff.ts";

type Err = { message: string } | null;

function fakeAdmin(opts: { createErr?: Err; updateErr?: Err; updatedRows?: number } = {}) {
  const calls = {
    created: [] as Record<string, unknown>[],
    updates: [] as { table: string; values: Record<string, unknown>; eq: [string, string] }[],
    deleted: [] as string[],
  };
  const admin: StaffAdminClient = {
    auth: {
      admin: {
        createUser(attrs) {
          calls.created.push(attrs);
          return Promise.resolve(
            opts.createErr ? { data: { user: null }, error: opts.createErr } : { data: { user: { id: "u-1" } }, error: null },
          );
        },
        deleteUser(id) {
          calls.deleted.push(id);
          return Promise.resolve({ error: null });
        },
      },
    },
    from(table) {
      return {
        update(values) {
          return {
            eq(column, value) {
              calls.updates.push({ table, values, eq: [column, value] });
              return {
                select: () => {
                  const n = opts.updatedRows ?? 1;
                  return Promise.resolve(
                    opts.updateErr ? { data: null, error: opts.updateErr } : { data: Array(n).fill({ id: value }), error: null },
                  );
                },
              };
            },
          };
        },
      };
    },
  };
  return { admin, calls };
}

const input = { email: "uji-gudang@staff.pos.invalid", password: "rahasia123", role: "warehouse", fullName: "UJI-gudang" };

test("create role warehouse menulis profiles.role = warehouse untuk user baru", async () => {
  const { admin, calls } = fakeAdmin();
  const res = await createStaff(admin, input);
  assert.deepEqual(res, { ok: true, id: "u-1" });
  assert.deepEqual(calls.updates, [{ table: "profiles", values: { role: "warehouse" }, eq: ["id", "u-1"] }]);
  assert.deepEqual(calls.deleted, []);
});

test("update profiles gagal -> user baru dihapus dan galat jelas", async () => {
  const { admin, calls } = fakeAdmin({ updateErr: { message: "permission denied" } });
  const res = await createStaff(admin, input);
  assert.equal(res.ok, false);
  assert.equal(!res.ok && res.status, 500);
  assert.match(!res.ok ? res.error : "", /Gagal menyimpan peran staf \(permission denied\)/);
  assert.deepEqual(calls.deleted, ["u-1"]);
});

test("profil tidak ditemukan (0 baris) juga dianggap gagal -> deleteUser", async () => {
  const { admin, calls } = fakeAdmin({ updatedRows: 0 });
  const res = await createStaff(admin, input);
  assert.equal(res.ok, false);
  assert.deepEqual(calls.deleted, ["u-1"]);
});

test("createUser duplikat -> 409 tanpa update/delete", async () => {
  const { admin, calls } = fakeAdmin({ createErr: { message: "User already registered" } });
  const res = await createStaff(admin, input);
  assert.deepEqual(res, { ok: false, status: 409, error: "Username sudah dipakai" });
  assert.deepEqual(calls.updates, []);
  assert.deepEqual(calls.deleted, []);
});
