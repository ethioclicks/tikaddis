import 'package:flutter/material.dart';

import '../models/models.dart';
import 'theme.dart';

/// Small formatting + presentation helpers shared across screens.
class Fmt {
  Fmt._();

  /// 1200 -> "1.2K", 3_400_000 -> "3.4M"
  static String compact(num n) {
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(n % 1000000 == 0 ? 0 : 1)}M';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
    }
    return n.toString();
  }

  static String birr(double cost) {
    final s = cost == cost.roundToDouble()
        ? cost.toStringAsFixed(0)
        : cost.toStringAsFixed(2);
    return 'ETB $s';
  }

  static String date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Brand color per platform (used to theme the channel detail header).
  static Color platformColor(AccountType? t) {
    switch (t) {
      case AccountType.telegram:
        return const Color(0xFF229ED9);
      case AccountType.youtube:
        return const Color(0xFFFF0000);
      case AccountType.tiktok:
        return const Color(0xFF000000);
      case AccountType.facebook:
        return const Color(0xFF1877F2);
      case AccountType.instagram:
        return const Color(0xFFC13584);
      default:
        return AppColors.primary;
    }
  }

  /// Brand icon per platform.
  static IconData platformIcon(AccountType? t) {
    switch (t) {
      case AccountType.telegram:
        return Icons.send_rounded;
      case AccountType.youtube:
        return Icons.play_circle_outline;
      case AccountType.tiktok:
        return Icons.music_note_outlined;
      case AccountType.facebook:
        return Icons.facebook_outlined;
      case AccountType.instagram:
        return Icons.camera_alt_outlined;
      default:
        return Icons.public;
    }
  }

  /// Status pill colours (bg, fg).
  static (Color, Color) statusColors(PromotionStatus? s) {
    switch (s) {
      case PromotionStatus.fulfilled:
      case PromotionStatus.ownerApproved:
        return (const Color(0xFFECFDF5), const Color(0xFF047857));
      case PromotionStatus.running:
        return (const Color(0xFFEFF6FF), const Color(0xFF1D4ED8));
      case PromotionStatus.adminRejected:
      case PromotionStatus.ownerRejected:
      case PromotionStatus.businessCanceled:
        return (const Color(0xFFFEF2F2), const Color(0xFFB91C1C));
      case PromotionStatus.adminApproved:
      case PromotionStatus.requested:
      case null:
        return (const Color(0xFFFFF7ED), AppColors.accentHover);
    }
  }
}

/// Reusable states for list/detail screens.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
    ),
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.action,
  });
  final String message;
  final VoidCallback? onRetry;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 44, color: AppColors.neutral300),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.neutral600),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.icon, this.action});
  final String message;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon ?? Icons.inbox_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.neutral600,
                fontSize: 14.5,
                height: 1.4,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// A large title that collapses into a compact pinned bar as the user
/// scrolls — used on the main list tabs.
class CollapsingTitleBar extends StatelessWidget {
  const CollapsingTitleBar({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.neutral50,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      shadowColor: Colors.black12,
      automaticallyImplyLeading: false,
      expandedHeight: 76,
      collapsedHeight: 56,
      actions: actions,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final top = MediaQuery.of(context).padding.top;
          // Progress 0 (expanded) -> 1 (collapsed).
          final maxH = 76 + top;
          final minH = 56 + top;
          final t = ((maxH - constraints.maxHeight) / (maxH - minH)).clamp(
            0.0,
            1.0,
          );
          final fontSize = 30 - (12 * t); // 30 -> 18
          return Container(
            color: AppColors.neutral50,
            padding: EdgeInsets.only(top: top + 16, left: 20, bottom: 8),
            alignment: Alignment.topLeft,
            child: Text(
              title,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.neutral900,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A clean, full-width 1px bottom border for app bars (no Divider indent
/// artifacts).
class AppBarBottomLine extends StatelessWidget implements PreferredSizeWidget {
  const AppBarBottomLine({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(1);

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: AppColors.neutral200);
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final PromotionStatus? status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = Fmt.statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status?.label ?? 'Unknown',
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
