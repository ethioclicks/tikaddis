import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/browse_error.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';
import '../../widgets/creator_person_card.dart';
import '../../widgets/shimmer.dart';
import '../../widgets/sparkle.dart';

const Color _ink = Color(0xFF111111);

/// Height of one creator card in the grid (same as the Browse rail).
const double _cardHeight = 160;

/// Every creator (the people behind the channels), searchable by name or
/// headline. Opened from "View all" on Browse.
class CreatorsScreen extends ConsumerStatefulWidget {
  const CreatorsScreen({super.key});

  @override
  ConsumerState<CreatorsScreen> createState() => _CreatorsScreenState();
}

class _CreatorsScreenState extends ConsumerState<CreatorsScreen> {
  String _query = '';

  List<CreatorCard> _filter(List<CreatorCard> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (c) =>
              (c.name ?? '').toLowerCase().contains(q) ||
              (c.headline ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final creators = ref.watch(creatorsProvider);

    final body = creators.when(
      loading: () => const SliverToBoxAdapter(child: _GridSkeleton()),
      error: (e, _) => SliverToBoxAdapter(
        child: SizedBox(
          height: 360,
          child: ErrorView(
            message: browseErrorMessage(e),
            onRetry: () => ref.invalidate(creatorsProvider),
          ),
        ),
      ),
      data: (all) {
        final rows = _filter(all);
        if (rows.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 48),
              child: EmptyView(
                icon: Icons.search_off,
                message: all.isEmpty
                    ? 'No creators are available yet. Please check back soon.'
                    : 'No creators match your search.',
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: _cardHeight,
            ),
            itemCount: rows.length,
            itemBuilder: (_, i) =>
                CreatorPersonCard(creator: rows[i], width: null),
          ),
        );
      },
    );

    final count = creators.maybeWhen(
      data: (all) => _filter(all).length,
      orElse: () => null,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(creatorsProvider);
            try {
              await ref.read(creatorsProvider.future);
            } catch (_) {
              // The error view takes over.
            }
          },
          child: CustomScrollView(
            // Pulling down never stretches the page; only the spinner shows.
            physics: const ClampingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _Header(onChanged: (v) => setState(() => _query = v)),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Text(
                    count == null
                        ? 'All creators'
                        : _query.trim().isEmpty
                        ? 'All creators ($count)'
                        : '$count results',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

/// Gradient header with a back button, the title and the search field, in
/// the same style as Browse.
class _Header extends StatelessWidget {
  const _Header({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppGradients.hero),
      padding: EdgeInsets.fromLTRB(12, top + 6, 20, 22),
      child: Stack(
        children: [
          const Positioned(
            top: 10,
            right: 4,
            child: Sparkle(size: 24, color: Colors.white),
          ),
          const Positioned(
            top: 46,
            right: 40,
            child: Sparkle(size: 12, color: AppColors.accentLight),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/browse'),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                ),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(
                  'Creators',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryHover.withValues(alpha: 0.18),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 15.5, color: _ink),
                    decoration: const InputDecoration(
                      hintText: 'Search by name or headline',
                      hintStyle: TextStyle(
                        color: AppColors.neutral500,
                        fontSize: 15.5,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.neutral500,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(vertical: 18),
                      // Rounded like the container, so the white fill does
                      // not show square corners.
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(18)),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(18)),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(18)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shimmering 2-column grid with the same card size as the real one.
class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget card() => Expanded(
      child: Container(
        height: _cardHeight,
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
        decoration: BoxDecoration(
          color: kSkeletonBase,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          children: [
            SkeletonBox(width: 52, height: 52, circle: true),
            SizedBox(height: 8),
            SkeletonBox(width: 90, height: 14, radius: 6),
            SizedBox(height: 6),
            SkeletonBox(width: 100, height: 11, radius: 6),
            Spacer(),
            SkeletonBox(width: 80, height: 22, radius: 11),
          ],
        ),
      ),
    );

    return Semantics(
      label: 'Loading creators',
      child: ExcludeSemantics(
        child: Shimmer(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  Row(
                    children: [
                      card(),
                      const SizedBox(width: 12),
                      card(),
                      const SizedBox(width: 12),
                      card(),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
