import { useEffect, useState } from 'react';
import { Trash2, UserPlus, ShieldCheck, LogOut, Mail } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import LoadingSpinner from '@/components/LoadingSpinner';
import ConfirmDialog from '@/components/ConfirmDialog';

interface AllowRow {
  id: string;
  email: string;
  added_at: string;
}

export default function AdminPage() {
  const [rows, setRows] = useState<AllowRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [newEmail, setNewEmail] = useState('');
  const [error, setError] = useState('');
  const [confirmDelete, setConfirmDelete] = useState<AllowRow | null>(null);
  const [me, setMe] = useState('');

  const load = async () => {
    setLoading(true);
    const { data: userData } = await supabase.auth.getUser();
    setMe(userData.user?.email?.toLowerCase() ?? '');
    const { data, error: err } = await supabase
      .from('admin_allowlist')
      .select('id, email, added_at')
      .order('added_at', { ascending: true });
    if (err) {
      setError('Tidak bisa memuat daftar admin.');
    } else {
      setRows(data ?? []);
    }
    setLoading(false);
  };

  useEffect(() => { load(); }, []);

  const addAdmin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    if (!newEmail.trim()) return;
    const { error: err } = await supabase.rpc('add_admin', { p_email: newEmail.trim() });
    if (err) {
      setError(
        err.message.includes('Invalid email')
          ? 'Format email tidak valid.'
          : 'Tidak bisa menambahkan admin. Coba lagi.'
      );
    } else {
      setNewEmail('');
      load();
    }
  };

  const deleteAdmin = async (row: AllowRow) => {
    setError('');
    const { error: err } = await supabase.rpc('remove_admin', { p_email: row.email });
    if (err) {
      setError(
        err.message.includes('terakhir')
          ? 'Tidak bisa menghapus admin terakhir.'
          : 'Tidak bisa menghapus admin. Coba lagi.'
      );
    }
    setConfirmDelete(null);
    load();
  };

  const signOut = async () => {
    await supabase.auth.signOut();
  };

  return (
    <div className="space-y-5">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-lg font-bold text-gray-900">Akses Admin</h2>
          <p className="text-sm text-gray-500">
            Email di daftar ini yang diizinkan masuk ke aplikasi. Semua admin melihat data yang sama.
          </p>
        </div>
        <button
          onClick={signOut}
          className="inline-flex items-center justify-center gap-2 rounded-lg border border-gray-200 px-4 py-2 text-sm font-medium text-gray-600 transition hover:bg-gray-50"
        >
          <LogOut className="h-4 w-4" /> Keluar
        </button>
      </div>

      <form onSubmit={addAdmin} className="flex flex-col gap-2 sm:flex-row">
        <input
          type="email"
          value={newEmail}
          onChange={(e) => setNewEmail(e.target.value)}
          placeholder="email-baru@email.com"
          className="w-full flex-1 rounded-lg border border-gray-200 bg-white px-3 py-2 text-gray-700 placeholder:text-gray-400 focus:border-[#FB5EA8] focus:outline-none focus:ring-1 focus:ring-[#FB5EA8]"
        />
        <button
          type="submit"
          className="inline-flex items-center justify-center gap-2 rounded-lg bg-[#FB5EA8] px-4 py-2 font-semibold text-white transition hover:bg-[#e04b93]"
        >
          <UserPlus className="h-4 w-4" /> Tambah Admin
        </button>
      </form>

      {error && <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-600">{error}</p>}

      {loading ? (
        <div className="flex justify-center py-10">
          <LoadingSpinner />
        </div>
      ) : (
        <div className="overflow-hidden rounded-xl border border-gray-100 bg-white shadow-sm">
          <ul className="divide-y divide-gray-100">
            {rows.map((row) => (
              <li key={row.id} className="flex items-center justify-between gap-3 px-4 py-3">
                <div className="flex items-center gap-3">
                  <div className="flex h-9 w-9 items-center justify-center rounded-full bg-[#FEF1F7]">
                    {row.email.toLowerCase() === me ? (
                      <ShieldCheck className="h-4 w-4 text-[#FB5EA8]" />
                    ) : (
                      <Mail className="h-4 w-4 text-[#FB5EA8]" />
                    )}
                  </div>
                  <div>
                    <p className="text-sm font-medium text-gray-900">{row.email}</p>
                    <p className="text-xs text-gray-400">
                      {row.email.toLowerCase() === me ? 'Akun kamu' : 'Admin lain'} · ditambahkan{' '}
                      {new Date(row.added_at).toLocaleDateString('id-ID', {
                        day: 'numeric',
                        month: 'short',
                        year: 'numeric',
                      })}
                    </p>
                  </div>
                </div>
                <button
                  onClick={() => setConfirmDelete(row)}
                  disabled={rows.length <= 1}
                  title={rows.length <= 1 ? 'Minimal harus ada satu admin' : 'Hapus admin'}
                  className="rounded-lg p-2 text-gray-400 transition hover:bg-red-50 hover:text-red-600 disabled:cursor-not-allowed disabled:opacity-30"
                >
                  <Trash2 className="h-4 w-4" />
                </button>
              </li>
            ))}
            {rows.length === 0 && (
              <li className="px-4 py-6 text-center text-sm text-gray-500">
                Belum ada admin terdaftar.
              </li>
            )}
          </ul>
        </div>
      )}

      <ConfirmDialog
        open={!!confirmDelete}
        title="Hapus admin?"
        message={`Email ${confirmDelete?.email ?? ''} tidak akan bisa masuk ke aplikasi lagi.`}
        confirmLabel="Hapus"
        onConfirm={() => confirmDelete && deleteAdmin(confirmDelete)}
        onCancel={() => setConfirmDelete(null)}
      />
    </div>
  );
}
