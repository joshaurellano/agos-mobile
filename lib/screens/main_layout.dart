import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../models/alert_level.dart';
import 'dashboard_screen.dart';
import 'water_level_screen.dart';
import 'rainfall_screen.dart';
import 'flood_map_screen.dart';
import 'historical_screen.dart';
import 'alerts_screen.dart';
import 'data_sources_screen.dart';
import 'register_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  AlertLevelType _alertLevel = AlertLevelType.warning;

  void updateAlertLevel(AlertLevelType level) {
    setState(() => _alertLevel = level);
  }

  List<_NavItem> _navItems(bool isAdmin, bool isResident) => [
    _NavItem(icon: Icons.dashboard, label: 'Dashboard'),
    _NavItem(icon: Icons.waves,     label: 'Water Level'),
    _NavItem(icon: Icons.grain,     label: 'Rainfall'),
    _NavItem(icon: Icons.map,       label: 'Flood Map'),
    _NavItem(icon: Icons.history,   label: 'Historical'),
    if (!isResident) _NavItem(icon: Icons.notifications, label: 'Alert Logs'),
    if (!isResident) _NavItem(icon: Icons.cloud,         label: 'Data Sources'),
    if (isAdmin)     _NavItem(icon: Icons.person_add,    label: 'Register'),
    if (!isResident) _NavItem(icon: Icons.group_add,     label: 'Add Resident'),
  ];

  Widget _buildScreen(int index, bool isAdmin, bool isResident) {
    final screens = [
      DashboardScreen(onAlertChanged: updateAlertLevel),
      const WaterLevelScreen(),
      const RainfallScreen(),
      const FloodMapScreen(),
      const HistoricalScreen(),
      if (!isResident) const AlertsScreen(),
      if (!isResident) const DataSourcesScreen(),
      if (isAdmin)     const RegisterScreen(isResidentMode: false),
      if (!isResident) const RegisterScreen(isResidentMode: true),
    ];
    return index < screens.length ? screens[index] : screens[0];
  }

  @override
  Widget build(BuildContext context) {
    final auth  = context.watch<AuthService>();
    final user  = auth.currentUser;
    final isAdmin    = user?.isAdmin ?? false;
    final isResident = user?.isResident ?? false;
    final items = _navItems(isAdmin, isResident);
    final alertInfo = AlertLevel.levels[_alertLevel]!;

    return Scaffold(
      backgroundColor: AppColors.blueDark,
      appBar: AppBar(
        backgroundColor: AppColors.blueCard,
        elevation: 0,
        title: Row(children: [
          const Text('🌊', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('AGOS', style: TextStyle(
              color: AppColors.accent, fontWeight: FontWeight.w900,
              fontSize: 18, letterSpacing: -0.5,
            )),
            const Text('Barangay Triangulo, Naga City',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ]),
          const Spacer(),
          // Alert badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: alertInfo.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: alertInfo.color.withOpacity(0.4)),
            ),
            child: Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: alertInfo.color,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                alertInfo.label.toUpperCase(),
                style: TextStyle(
                  color: alertInfo.color, fontSize: 12, fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ]),
          ),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.blueBorder),
        ),
      ),
      body: Row(children: [
        // ── Sidebar (tablet/desktop) ───────────────────────────
        if (MediaQuery.of(context).size.width > 768)
          Container(
            width: 220,
            color: AppColors.blueCard,
            child: _Sidebar(
              items: items,
              selectedIndex: _selectedIndex,
              onTap: (i) => setState(() => _selectedIndex = i),
              user: user,
              onLogout: auth.logout,
            ),
          ),
        // ── Main content ──────────────────────────────────────
        Expanded(
          child: _buildScreen(_selectedIndex, isAdmin, isResident),
        ),
      ]),
      // ── Bottom Nav (mobile) ───────────────────────────────────
      bottomNavigationBar: MediaQuery.of(context).size.width <= 768
          ? BottomNavigationBar(
              currentIndex: _selectedIndex.clamp(0, items.length - 1),
              onTap: (i) => setState(() => _selectedIndex = i),
              backgroundColor: AppColors.blueCard,
              selectedItemColor: AppColors.accent,
              unselectedItemColor: AppColors.textMuted,
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 10,
              unselectedFontSize: 10,
              items: items
                  .map((e) => BottomNavigationBarItem(
                        icon: Icon(e.icon, size: 22),
                        label: e.label,
                      ))
                  .toList(),
            )
          : null,
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _Sidebar extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final dynamic user;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
    required this.user,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              final selected = selectedIndex == i;
              return InkWell(
                onTap: () => onTap(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent.withOpacity(0.1) : Colors.transparent,
                    border: Border(
                      left: BorderSide(
                        color: selected ? AppColors.accent : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Row(children: [
                    Icon(item.icon,
                        color: selected ? AppColors.accent : AppColors.textSecondary,
                        size: 18),
                    const SizedBox(width: 12),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: selected ? AppColors.accent : AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
        // User info & logout
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.blueBorder)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withOpacity(0.15),
                ),
                child: const Icon(Icons.person, color: AppColors.accent, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(user?.name ?? '',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 4),
            Text(user?.roleDesc ?? '',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Sign Out', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.blueBorder),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}