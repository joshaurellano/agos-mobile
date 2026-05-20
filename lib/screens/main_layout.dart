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
import 'resident_alerts_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex    = 0;
  AlertLevelType _alertLevel = AlertLevelType.normal;

  void _updateAlertLevel(AlertLevelType level) {
    if (_alertLevel != level) setState(() => _alertLevel = level);
  }

  void _showAccountSheet(BuildContext context) {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.blueDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.blueBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Avatar
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withOpacity(0.15),
                border: Border.all(color: AppColors.accent.withOpacity(0.4), width: 2),
              ),
              child: const Icon(Icons.person_rounded, color: AppColors.accent, size: 32),
            ),
            const SizedBox(height: 14),

            // Name
            Text(
              user?.name ?? 'Unknown',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),

            // Username
            Text(
              '@${user?.username ?? ''}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 8),

            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent.withOpacity(0.3)),
              ),
              child: Text(
                user?.roleDesc ?? '',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Sign out button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  auth.logout();
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign Out', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: AppColors.red),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_NavItem> _residentItems() => const [
    _NavItem(icon: Icons.dashboard_rounded,     label: 'Dashboard'),
    _NavItem(icon: Icons.notifications_rounded, label: 'My Alerts'),
  ];

  List<_NavItem> _officialItems(bool isAdmin) => [
    const _NavItem(icon: Icons.dashboard_rounded,       label: 'Dashboard'),
    const _NavItem(icon: Icons.waves_rounded,           label: 'Water Level'),
    const _NavItem(icon: Icons.grain,                   label: 'Rainfall'),
    const _NavItem(icon: Icons.map_rounded,             label: 'Flood Map'),
    const _NavItem(icon: Icons.history_rounded,         label: 'Historical'),
    const _NavItem(icon: Icons.campaign_rounded,        label: 'Alert Logs'),
    const _NavItem(icon: Icons.cloud_rounded,           label: 'Data Sources'),
    if (isAdmin) const _NavItem(icon: Icons.person_add_rounded, label: 'Register'),
    if (isAdmin) const _NavItem(icon: Icons.group_add_rounded,  label: 'Add Resident'),
  ];


  Widget _buildScreen(int idx, bool isResident, bool isAdmin) {
    if (isResident) {
      final screens = [
        DashboardScreen(onAlertChanged: _updateAlertLevel, residentView: true),
        const ResidentAlertsScreen(),
      ];
      return idx < screens.length ? screens[idx] : screens[0];
    }
    final screens = [
      DashboardScreen(onAlertChanged: _updateAlertLevel),
      const WaterLevelScreen(),
      const RainfallScreen(),
      const FloodMapScreen(),
      const HistoricalScreen(),
      const AlertsScreen(),
      const DataSourcesScreen(),
      if (isAdmin) const RegisterScreen(isResidentMode: false),
      if (isAdmin) const RegisterScreen(isResidentMode: true),
    ];
    return idx < screens.length ? screens[idx] : screens[0];
  }

  @override
  Widget build(BuildContext context) {
    final auth       = context.watch<AuthService>();
    final user       = auth.currentUser;
    final isAdmin    = user?.isAdmin    ?? false;
    final isResident = user?.isResident ?? false;
    final items      = isResident ? _residentItems() : _officialItems(isAdmin);
    final alertInfo  = AlertLevel.levels[_alertLevel]!;

    final safeIdx = _selectedIndex.clamp(0, items.length - 1);
    final isWide  = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      backgroundColor: AppColors.blueDark,
      appBar: _buildAppBar(alertInfo, isResident),
      body: Row(
        children: [
          // Persistent sidebar on tablet/desktop (non-resident)
          if (isWide && !isResident)
            SizedBox(
              width: 220,
              child: Container(
                color: AppColors.blueCard,
                child: _Sidebar(
                  items: items,
                  selectedIndex: safeIdx,
                  onTap: (i) => setState(() => _selectedIndex = i),
                  user: user,
                  onLogout: auth.logout,
                ),
              ),
            ),
          Expanded(
            child: _buildScreen(safeIdx, isResident, isAdmin),
          ),
        ],
      ),
      bottomNavigationBar: (!isWide || isResident)
          ? _buildBottomNav(items, safeIdx)
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(AlertLevel alertInfo, bool isResident) {
    return AppBar(
      backgroundColor: AppColors.blueCard,
      elevation: 0,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Text('🌊', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'AGOS',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    isResident
                        ? 'Resident App · Brgy. Triangulo'
                        : 'Barangay Triangulo, Naga City',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Spacer(),
            _AlertBadge(alertInfo: alertInfo),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _showAccountSheet(context),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withOpacity(0.15),
                  border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                ),
                child: const Icon(Icons.person_rounded, color: AppColors.accent, size: 18),
              ),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.blueBorder),
      ),
    );
  }

  Widget _buildBottomNav(List<_NavItem> items, int safeIdx) {
    // For many items (>5), show only the first 5 on mobile
    final displayItems = items.length > 5 ? items.sublist(0, 5) : items;
    final displayIdx   = safeIdx < displayItems.length ? safeIdx : 0;

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.blueCard,
          border: Border(top: BorderSide(color: AppColors.blueBorder)),
        ),
        child: BottomNavigationBar(
          currentIndex: displayIdx,
          onTap: (i) => setState(() => _selectedIndex = i),
          backgroundColor: AppColors.blueCard,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.textMuted,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          elevation: 0,
          items: displayItems
              .map((e) => BottomNavigationBarItem(
                    icon: Icon(e.icon, size: 22),
                    label: e.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ── Alert badge ───────────────────────────────────────────────────────────────

class _AlertBadge extends StatelessWidget {
  final AlertLevel alertInfo;
  const _AlertBadge({required this.alertInfo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: alertInfo.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: alertInfo.color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: alertInfo.color,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            alertInfo.label.toUpperCase(),
            style: TextStyle(
              color: alertInfo.color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nav data ──────────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String   label;
  const _NavItem({required this.icon, required this.label});
}

// ── Sidebar (tablet/desktop) ──────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final List<_NavItem> items;
  final int            selectedIndex;
  final ValueChanged<int> onTap;
  final dynamic        user;
  final VoidCallback   onLogout;

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
              final item     = items[i];
              final selected = selectedIndex == i;
              return InkWell(
                onTap: () => onTap(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent.withOpacity(0.1)
                        : Colors.transparent,
                    border: Border(
                      left: BorderSide(
                        color: selected
                            ? AppColors.accent
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(item.icon,
                          color: selected
                              ? AppColors.accent
                              : AppColors.textSecondary,
                          size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          style: TextStyle(
                            color: selected
                                ? AppColors.accent
                                : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // User + logout
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.blueBorder)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withOpacity(0.15),
                    ),
                    child: const Icon(Icons.person,
                        color: AppColors.accent, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      user?.name ?? '',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                user?.roleDesc ?? '',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text('Sign Out',
                      style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.blueBorder),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}