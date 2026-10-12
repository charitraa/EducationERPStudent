import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Breakpoints shared by every screen.
class Breakpoints {
  const Breakpoints._();
  static const double tablet = 600;
  static const double desktop = 1000;
  static const double contentMax = 1120;

  static bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= tablet;
}

/// Centres content and caps its width so lines stay readable on wide screens.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child, this.maxWidth = Breakpoints.contentMax});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );
  }
}

EdgeInsets pagePadding(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  final h = w >= Breakpoints.desktop ? 32.0 : (w >= Breakpoints.tablet ? 24.0 : 16.0);
  return EdgeInsets.fromLTRB(h, 12, h, 32);
}

/// A titled card section, e.g. "Today's classes" on the dashboard.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.icon, this.actionLabel, this.onAction});

  final String title;
  final IconData? icon;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Semantics(header: true, child: Text(title, style: theme.textTheme.titleMedium)),
                ),
                if (actionLabel != null)
                  TextButton(onPressed: onAction, child: Text(actionLabel!))
                else
                  const SizedBox(height: 40),
              ],
            ),
            Padding(padding: const EdgeInsets.only(right: 8, top: 4), child: child),
          ],
        ),
      ),
    );
  }
}

/// A small coloured label, e.g. a status.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Color.lerp(color, Colors.white, 0.45)! : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: isDark ? 0.25 : 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// A label/value line in a details card.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.icon});
  final String label;
  final String? value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              (value == null || value!.isEmpty) ? '—' : value!,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

/// A headline number with a caption, e.g. "92%  Attendance".
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.color});
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: theme.textTheme.headlineSmall?.copyWith(color: color ?? theme.colorScheme.onSurface)),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

/// Colour for a percentage: green at 75% and above, amber from 60%, else red.
Color percentColor(double? p) {
  if (p == null) return AppColors.neutral;
  if (p >= 75) return AppColors.success;
  if (p >= 60) return AppColors.warning;
  return AppColors.danger;
}

/// A responsive grid of cards: one column on phones, two from tablet width.
class ResponsiveColumns extends StatelessWidget {
  const ResponsiveColumns({super.key, required this.children, this.spacing = 16, this.minColumnWidth = 420});
  final List<Widget> children;
  final double spacing;
  final double minColumnWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = (constraints.maxWidth / minColumnWidth).floor().clamp(1, 2);
      if (columns == 1) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final c in children) Padding(padding: EdgeInsets.only(bottom: spacing), child: c)],
        );
      }
      final left = <Widget>[], right = <Widget>[];
      for (var i = 0; i < children.length; i++) {
        (i.isEven ? left : right).add(Padding(padding: EdgeInsets.only(bottom: spacing), child: children[i]));
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left)),
          SizedBox(width: spacing),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
        ],
      );
    });
  }
}
