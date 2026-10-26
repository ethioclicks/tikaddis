import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/browse_error.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';
import '../../providers/auth_provider.dart';

/// Creator discovery — editorial: bold headline, tab filters, a large
/// featured hero card, then a compact "Top creators" list.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  int _tab = 0; // 0 Trending, 1 Recent, 2 Top, 3 Verified
  String _query = '';
  static const _tabs = ['Trending', 'Recent', 'Top', 'Verified'];

  List<InfluencerAccount> _sorted(List<InfluencerAccount> all) {
    final list = [...all];
    switch (_tab) {
      case 0: // Trending — by views
        list.sort((a, b) =>
            b.maxViewPerPostCount.compareTo(a.maxViewPerPostCount));
        break;
      case 1: // Recent — by id desc
        list.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
        break;
      case 2: // Top — by audience
        list.sort((a, b) => b.audienceCount.compareTo(a.audienceCount));
        break;
      case 3: // Verified only
        return list.where((a) => a.verified).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(approvedAccountsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(approvedAccountsProvider),
        child: accounts.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            message: browseErrorMessage(e),
            onRetry: () => ref.invalidate(approvedAccountsProvider),
            action: TextButton(
              onPressed: () => ref.read(authProvider.notifier).logout(),
              child: const Text('Sign in again'),
            ),
          ),
          data: (all) {
            final sorted = _sorted(all);
            // Featured rail: top few from the current tab.
            final featured = sorted.take(5).toList();
            // The list below respects the search query.
            final q = _query.trim().toLowerCase();
            final rows = q.isEmpty
                ? sorted
                : sorted.where((a) {
                    return (a.title ?? '').toLowerCase().contains(q) ||
                        (a.category?.categoryName ?? '')
                            .toLowerCase()
                            .contains(q);
                  }).toList();

            return ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                SafeArea(bottom: false, child: const _Headline()),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SearchBar(
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(height: 16),
                _Tabs(
                  tabs: _tabs,
                  selected: _tab,
                  onSelected: (i) => setState(() => _tab = i),
                ),

                // Featured horizontal rail (hidden while searching).
                if (_query.isEmpty && featured.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: _SectionHeader(title: 'Featured'),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 300,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: featured.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 14),
                      itemBuilder: (context, i) =>
                          _FeaturedCard(account: featured[i]),
                    ),
                  ),
                ],

                const SizedBox(height: 26),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _SectionHeader(
                    title: _query.isEmpty
                        ? 'Top creators'
                        : '${rows.length} results',
                    trailing: _query.isEmpty ? 'See all' : null,
                  ),
                ),
                const SizedBox(height: 6),
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: EmptyView(
                      icon: Icons.search_off,
                      message: all.isEmpty
                          ? 'No approved creators are available yet. '
                              'Please check back soon.'
                          : 'No creators match your search.',
                    ),
                  )
                else
                  ...rows.map((a) => _CreatorRow(account: a)),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Bold editorial headline ───────────────────────────────────────────────
class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: RichText(
        text: const TextSpan(
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.8,
            color: AppColors.neutral900,
          ),
          children: [
            TextSpan(text: 'Find the '),
            TextSpan(
              text: 'perfect creator',
              style: TextStyle(color: AppColors.primary),
            ),
            TextSpan(text: '\nfor your brand'),
          ],
        ),
      ),
    );
  }
}

/// Network photo with a graceful fallback (platform-tinted icon) when the
/// image can't load — e.g. no DNS/network for the demo image host.
class _Photo extends StatelessWidget {
  const _Photo({required this.url, required this.color, required this.icon});
  final String? url;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
          color: color.withValues(alpha: 0.16),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 48),
        );
    if ((url ?? '').isEmpty) return fallback();
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => fallback(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(color: color.withValues(alpha: 0.10));
      },
    );
  }
}

// ── Search ────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 15, color: AppColors.neutral900),
      decoration: InputDecoration(
        hintText: 'Search creators, categories…',
        hintStyle: const TextStyle(color: AppColors.neutral500, fontSize: 14.5),
        prefixIcon: const Icon(Icons.search_rounded,
            color: AppColors.neutral500, size: 21),
        filled: true,
        fillColor: AppColors.neutral50,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.neutral200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}

// ── Tab filters ───────────────────────────────────────────────────────────
class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: tabs.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final active = i == selected;
          return GestureDetector(
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active ? AppColors.primary : AppColors.neutral200,
                ),
              ),
              child: Text(
                tabs[i],
                style: TextStyle(
                  color: active ? Colors.white : AppColors.neutral600,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: AppColors.neutral900,
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

// ── Large featured hero card ──────────────────────────────────────────────
class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.account});
  final InfluencerAccount account;

  @override
  Widget build(BuildContext context) {
    final pColor = Fmt.platformColor(account.accountType);
    final lowest = account.lowestCost;

    return GestureDetector(
      onTap: account.accountPublicId == null
          ? null
          : () => context.push('/browse-detail/${account.accountPublicId}'),
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.neutral200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo.
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22)),
              child: SizedBox(
                height: 158,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Photo(
                      url: account.imageURL,
                      color: pColor,
                      icon: Fmt.platformIcon(account.accountType),
                    ),
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Fmt.platformIcon(account.accountType),
                                color: pColor, size: 15),
                            const SizedBox(width: 6),
                            Text(
                              account.category?.categoryName ??
                                  account.accountType?.label ??
                                  '',
                              style: const TextStyle(
                                color: AppColors.neutral900,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info.
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          account.title ?? 'Creator',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.neutral900,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      if (account.verified) ...[
                        const SizedBox(width: 5),
                        const Icon(Icons.verified_rounded,
                            color: AppColors.primary, size: 16),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${Fmt.compact(account.audienceCount)} followers',
                    style: const TextStyle(
                      color: AppColors.neutral500,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('From',
                                style: TextStyle(
                                    color: AppColors.neutral500,
                                    fontSize: 11)),
                            const SizedBox(height: 1),
                            Text(
                              lowest != null ? Fmt.birr(lowest) : '—',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.neutral900,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Promote',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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

// ── Compact creator row ───────────────────────────────────────────────────
class _CreatorRow extends StatelessWidget {
  const _CreatorRow({required this.account});
  final InfluencerAccount account;

  @override
  Widget build(BuildContext context) {
    final hasImage = (account.imageURL ?? '').isNotEmpty;
    final pColor = Fmt.platformColor(account.accountType);
    final lowest = account.lowestCost;

    return InkWell(
      onTap: account.accountPublicId == null
          ? null
          : () => context.push('/browse-detail/${account.accountPublicId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: pColor.withValues(alpha: 0.10),
                    image: hasImage
                        ? DecorationImage(
                            image: NetworkImage(account.imageURL!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: hasImage
                      ? null
                      : Icon(Fmt.platformIcon(account.accountType),
                          color: pColor, size: 22),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 19,
                    height: 19,
                    decoration: BoxDecoration(
                      color: pColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(Fmt.platformIcon(account.accountType),
                        color: Colors.white, size: 9),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          account.title ?? 'Creator',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.neutral900,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (account.verified) ...[
                        const SizedBox(width: 5),
                        const Icon(Icons.verified_rounded,
                            color: AppColors.primary, size: 14),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${Fmt.compact(account.audienceCount)} followers',
                    style: const TextStyle(
                      color: AppColors.neutral500,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  lowest != null ? Fmt.birr(lowest) : '—',
                  style: const TextStyle(
                    color: AppColors.neutral900,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'per day',
                  style: TextStyle(color: AppColors.neutral500, fontSize: 11.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
