import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/permissions.dart';
import '../data/providers.dart';
import '../data/session.dart';
import 'stock_list_screen.dart';
import 'cashier_screen.dart';
import 'add_product_screen.dart';
import 'history_screen.dart';
import 'staff_screen.dart';
import 'widgets/account_menu_button.dart';
import 'widgets/error_view.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // Formatter Rupiah
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // Fungsi untuk menyegarkan data Dashboard
  void _loadDashboardData() => ref.invalidate(dashboardSummaryProvider);

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(dashboardSummaryProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("Dashboard Admin", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: "Refresh Data",
          ),
          const AccountMenuButton(),
        ],
      ),
      body: summary.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(error: error, onRetry: _loadDashboardData),
        data: (data) => _buildContent(data),
      ),
    );
  }

  Widget _buildContent(DashboardSummary data) {
    final role = ref.watch(currentRoleProvider);
    return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sapaan
                Text(
                  "Halo, Selamat Bekerja! 👋", 
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),

                // KARTU OMZET
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Pendapatan Hari Ini", style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 5),
                      Text(
                        _currency.format(data.todayRevenue),
                        style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                        child: Text(DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now()), 
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // PERINGATAN STOK
                if (data.lowStockCount > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 30),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Perhatian!", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                            Text("Ada ${data.lowStockCount} barang stoknya menipis.", style: TextStyle(color: Colors.orange[800])),
                          ],
                        )
                      ],
                    ),
                  ),

                // MENU GRID
                Text("Menu Utama", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  children: [
                    if (can(role, Permission.useCashier))
                    _buildMenuCard(
                      title: "Kasir",
                      icon: Icons.point_of_sale,
                      color: Colors.green,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CashierScreen())).then((_) => _loadDashboardData()),
                    ),
                    if (can(role, Permission.viewStock))
                    _buildMenuCard(
                      title: "Stok Barang",
                      icon: Icons.inventory_2,
                      color: Colors.blue,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockListScreen())).then((_) => _loadDashboardData()),
                    ),
                    if (can(role, Permission.addProduct))
                    _buildMenuCard(
                      title: "Input Barang",
                      icon: Icons.add_box,
                      color: Colors.orange,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductScreen())).then((_) => _loadDashboardData()),
                    ),
                    if (can(role, Permission.viewHistory))
                    _buildMenuCard(
                      title: "Laporan", // Atau ganti jadi "Riwayat"
                      icon: Icons.history, // Ganti icon jadi history biar cocok
                      color: Colors.purple,
                      onTap: () {
                         // Arahkan ke Halaman Riwayat
                         Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
                      }, 
                    ),
                    if (can(role, Permission.manageStaff))
                      _buildMenuCard(
                        title: "Staf",
                        icon: Icons.people,
                        color: Colors.teal,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffScreen())),
                      ),
                  ],
                ),
              ],
            ),
          );
  }

  Widget _buildMenuCard({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 5, offset: const Offset(0, 3))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 35, color: color),
            ),
            const SizedBox(height: 15),
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}