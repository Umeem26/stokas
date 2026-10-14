import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/permissions.dart';
import '../data/session.dart';
import 'cashier_screen.dart';
import 'design/stokas_logo.dart';
import 'design/stokas_tokens.dart';
import 'history_screen.dart';
import 'owner/home_screen.dart';
import 'staff_screen.dart';
import 'stock_list_screen.dart';
import 'warehouse/opname_screen.dart';
import 'warehouse/receive_screen.dart';
import 'warehouse/transfer_screen.dart';
import 'widgets/account_menu_button.dart';

/// Lebar minimum untuk rel samping; di bawahnya tab bawah.
const double railBreakpoint = 768;

/// Semua tab aplikasi. [path] dipakai untuk rute awal / deep link.
enum AppTab {
  kasir('Kasir', Icons.point_of_sale_outlined, Icons.point_of_sale, '/kasir', Permission.useCashier),
  riwayatSaya('Riwayat saya', Icons.receipt_long_outlined, Icons.receipt_long, '/riwayat', Permission.viewHistory),
  home('Home', Icons.home_outlined, Icons.home, '/home', Permission.viewDashboard),
  riwayat('Riwayat', Icons.receipt_long_outlined, Icons.receipt_long, '/riwayat', Permission.viewHistory),
  stok('Stok', Icons.inventory_2_outlined, Icons.inventory_2, '/stok', Permission.viewStock),
  staf('Staf', Icons.people_outline, Icons.people, '/staf', Permission.manageStaff),
  terima('Terima', Icons.move_to_inbox_outlined, Icons.move_to_inbox, '/terima', Permission.restockStock),
  opname('Opname', Icons.fact_check_outlined, Icons.fact_check, '/opname', Permission.countStock),
  pindah('Pindah', Icons.swap_horiz_outlined, Icons.swap_horiz, '/pindah', Permission.moveStock),
  produk('Produk', Icons.category_outlined, Icons.category, '/produk', Permission.addProduct);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
  final Permission permission;

  const AppTab(this.label, this.icon, this.selectedIcon, this.path, this.permission);

  Widget build() {
    switch (this) {
      case AppTab.kasir:
        return const CashierScreen();
      case AppTab.riwayatSaya:
      case AppTab.riwayat:
        return const HistoryScreen();
      case AppTab.stok:
        return const StockListScreen();
      case AppTab.produk:
        return const StockListScreen(title: 'Produk', showAllProducts: true);
      case AppTab.staf:
        return const StaffScreen();
      case AppTab.terima:
        return const ReceiveScreen();
      case AppTab.opname:
        return const OpnameScreen();
      case AppTab.pindah:
        return const TransferScreen();
      case AppTab.home:
        return const HomeScreen();
    }
  }
}

const _tabsByRole = {
  AppRole.cashier: [AppTab.kasir, AppTab.riwayatSaya, AppTab.stok],
  AppRole.owner: [AppTab.home, AppTab.riwayat, AppTab.stok, AppTab.staf],
  AppRole.warehouse: [AppTab.terima, AppTab.opname, AppTab.pindah, AppTab.produk],
};

/// Tab milik [role], berurutan; tab pertama = layar pertama.
List<AppTab> tabsFor(AppRole role) => [for (final t in _tabsByRole[role]!) if (can(role, t.permission)) t];

/// Tab untuk [path]; rute tak dikenal atau milik peran lain -> layar pertama peran.
AppTab resolveTab(AppRole role, String? path) {
  final tabs = tabsFor(role);
  return tabs.firstWhere((t) => t.path == path, orElse: () => tabs.first);
}

/// Kerangka navigasi per peran: rel samping (>= 768 px) atau tab bawah.
/// State tiap tab dipertahankan (IndexedStack); tab dibangun saat pertama dibuka.
class AppShell extends StatefulWidget {
  final AppRole role;
  final String? initialPath;

  const AppShell({super.key, required this.role, this.initialPath});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _stackKey = GlobalKey();
  late final List<AppTab> _tabs = tabsFor(widget.role);
  late int _index = _tabs.indexOf(resolveTab(widget.role, widget.initialPath));
  late final Set<int> _opened = {_index};

  void _select(int index) => setState(() {
        _index = index;
        _opened.add(index);
      });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= railBreakpoint;
    // GlobalKey: isi tab tetap hidup saat tata letak berganti rel <-> tab bawah.
    final stack = IndexedStack(
      key: _stackKey,
      index: _index,
      children: [
        for (var i = 0; i < _tabs.length; i++) _opened.contains(i) ? _tabs[i].build() : const SizedBox.shrink(),
      ],
    );

    return Scaffold(
      body: wide
          ? Row(children: [
              _SideRail(tabs: _tabs, index: _index, onSelect: _select),
              Expanded(child: stack),
            ])
          : stack,
      bottomNavigationBar: wide ? null : _BottomTabs(tabs: _tabs, index: _index, onSelect: _select),
    );
  }
}

class _SideRail extends ConsumerWidget {
  final List<AppTab> tabs;
  final int index;
  final ValueChanged<int> onSelect;

  const _SideRail({required this.tabs, required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.stokas;
    final profile = ref.watch(currentProfileProvider);
    return Container(
      key: const Key('app-nav-rail'),
      width: StokasSpace.s8 * 2 + StokasSpace.s2,
      decoration: BoxDecoration(color: c.surface, border: Border(right: BorderSide(color: c.line))),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: StokasSpace.s5),
              child: StokasLogo(height: StokasSpace.s6),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: StokasSpace.s2),
                child: Column(
                  children: [
                    for (var i = 0; i < tabs.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: StokasSpace.s2),
                        child: _NavItem(tab: tabs[i], selected: i == index, onTap: () => onSelect(i)),
                      ),
                  ],
                ),
              ),
            ),
            if (profile != null)
              Padding(
                padding: const EdgeInsets.all(StokasSpace.s2),
                child: Column(
                  children: [
                    Text(
                      profile.fullName.isEmpty ? "-" : profile.fullName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: StokasType.label.copyWith(color: c.ink),
                    ),
                    Text(profile.role?.label ?? "-", style: StokasType.caption.copyWith(color: c.inkMuted)),
                    IconButton(
                      icon: Icon(Icons.logout, color: c.inkMuted),
                      tooltip: "Keluar",
                      onPressed: () => confirmSignOut(context, ref),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomTabs extends StatelessWidget {
  final List<AppTab> tabs;
  final int index;
  final ValueChanged<int> onSelect;

  const _BottomTabs({required this.tabs, required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    return Container(
      key: const Key('app-nav-bottom'),
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(StokasSpace.s1),
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: StokasSpace.s1),
                    child: _NavItem(tab: tabs[i], selected: i == index, onTap: () => onSelect(i)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Item navigasi: ikon + label; aktif = latar surface-sunken + warna primary; cincin fokus 2 px.
class _NavItem extends StatefulWidget {
  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({required this.tab, required this.selected, required this.onTap});

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = context.stokas;
    final fg = widget.selected ? c.primary : c.inkMuted;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(StokasRadius.md),
      side: _focused ? BorderSide(color: c.focus, width: 2) : BorderSide.none,
    );
    return Semantics(
      container: true,
      button: true,
      selected: widget.selected,
      label: widget.tab.label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: Material(
        color: widget.selected ? c.surfaceSunken : c.surface,
        shape: shape,
        child: InkWell(
          key: Key('nav-${widget.tab.name}'),
          customBorder: shape,
          focusColor: c.surfaceSunken,
          onTap: widget.onTap,
          onFocusChange: (focused) => setState(() => _focused = focused),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: StokasSpace.tapMin + StokasSpace.s3, minWidth: StokasSpace.tapMin),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: StokasSpace.s2, horizontal: StokasSpace.s1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.selected ? widget.tab.selectedIcon : widget.tab.icon, color: fg),
                  const SizedBox(height: StokasSpace.s1),
                  Text(
                    widget.tab.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: StokasType.label.copyWith(color: fg),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
