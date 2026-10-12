import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/common.dart';
import '../auth/auth_controller.dart';
import '../auth/brand_mark.dart';
import '../notifications/notifications_repository.dart';
import '../profile/profile_screen.dart';

class NavItem {
  const NavItem(this.label, this.icon, this.selectedIcon, this.path);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
}

/// Phone bottom bar: the four daily screens plus "More".
const mobileNav = [
  NavItem('Home', Icons.home_outlined, Icons.home_rounded, '/'),
  NavItem('Timetable', Icons.schedule_outlined, Icons.schedule, '/timetable'),
  NavItem('Attendance', Icons.fact_check_outlined, Icons.fact_check, '/attendance'),
  NavItem('Results', Icons.workspace_premium_outlined, Icons.workspace_premium, '/results'),
  NavItem('More', Icons.menu_rounded, Icons.menu_open_rounded, '/more'),
];

/// Tablet and desktop sidebar: every student section.
const sideNav = [
  NavItem('Home', Icons.home_outlined, Icons.home_rounded, '/'),
  NavItem('Timetable', Icons.schedule_outlined, Icons.schedule, '/timetable'),
  NavItem('Attendance', Icons.fact_check_outlined, Icons.fact_check, '/attendance'),
  NavItem('Exams & results', Icons.workspace_premium_outlined, Icons.workspace_premium, '/results'),
  NavItem('Notices', Icons.campaign_outlined, Icons.campaign, '/notices'),
  NavItem('Fees', Icons.receipt_long_outlined, Icons.receipt_long, '/fees'),
  NavItem('Notifications', Icons.notifications_outlined, Icons.notifications, '/notifications'),
  NavItem('Profile', Icons.person_outline, Icons.person, '/profile'),
  NavItem('Help & support', Icons.help_outline, Icons.help, '/support'),
];

/// Index of the nav item that owns [location] (its longest matching prefix).
int navIndexFor(List<NavItem> items, String location) {
  var best = -1, bestLen = -1;
  for (var i = 0; i < items.length; i++) {
    final p = items[i].path;
    final matches = p == '/' ? location == '/' : (location == p || location.startsWith('$p/'));
    if (matches && p.length > bestLen) {
      best = i;
      bestLen = p.length;
    }
  }
  if (best == -1 && identical(items, mobileNav)) return mobileNav.length - 1; // secondary screens live under More
  return best;
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < Breakpoints.tablet) {
      final index = navIndexFor(mobileNav, location);
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index < 0 ? 0 : index,
          onDestinationSelected: (i) => context.go(mobileNav[i].path),
          destinations: [
            for (final item in mobileNav)
              NavigationDestination(icon: Icon(item.icon), selectedIcon: Icon(item.selectedIcon), label: item.label),
          ],
        ),
      );
    }

    final extended = width >= Breakpoints.desktop;
    final index = navIndexFor(sideNav, location);
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final student = ref.watch(authControllerProvider.select((s) => s.student));
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 240,
            selectedIndex: index < 0 ? null : index,
            onDestinationSelected: (i) => context.go(sideNav[i].path),
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: extended
                  ? SizedBox(
                      width: 208,
                      child: Row(children: [
                        const BrandMark(size: 36),
                        const SizedBox(width: 12),
                        Text('Student Portal', style: Theme.of(context).textTheme.titleMedium),
                      ]),
                    )
                  : const BrandMark(size: 36),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: extended && student != null
                      ? SizedBox(
                          width: 216,
                          child: ListTile(
                            leading: StudentAvatar(initials: student.initials, radius: 18),
                            title: Text(student.fullName, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(student.studentNumber),
                            trailing: IconButton(
                              tooltip: 'Sign out',
                              icon: const Icon(Icons.logout),
                              onPressed: () => confirmSignOut(context, ref),
                            ),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Sign out',
                          icon: const Icon(Icons.logout),
                          onPressed: () => confirmSignOut(context, ref),
                        ),
                ),
              ),
            ),
            destinations: [
              for (final item in sideNav)
                NavigationRailDestination(
                  icon: item.path == '/notifications'
                      ? Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: Icon(item.icon))
                      : Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: Text(item.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
