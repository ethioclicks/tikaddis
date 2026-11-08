import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'app_image.dart';

const Color _ink = Color(0xFF111111);

/// A creator (the person, not a channel) as a soft grey card: photo, name,
/// headline and a channel / audience pill. Opens their full profile.
class CreatorPersonCard extends StatelessWidget {
  const CreatorPersonCard({super.key, required this.creator, this.width = 164});

  final CreatorCard creator;

  /// Fixed width for a horizontal rail; null fills the parent (grid).
  final double? width;

  @override
  Widget build(BuildContext context) {
    final name = (creator.name ?? '').isEmpty ? 'Creator' : creator.name!;
    final headline = (creator.headline ?? '').trim();
    final channels = creator.channelCount == 1
        ? '1 channel'
        : '${creator.channelCount} channels';

    return SizedBox(
      width: width,
      child: Material(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: creator.userPublicId != null
              ? () => context.push(
                  '/creator/${Uri.encodeComponent(creator.userPublicId!)}',
                )
              : creator.accountPublicId == null
              ? null
              : () => context.push('/browse-detail/${creator.accountPublicId}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
            child: Column(
              children: [
                Avatar(url: creator.profileImageUrl, name: name, size: 68),
                const SizedBox(height: 12),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  headline.isEmpty ? 'Creator on Tikaddis' : headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.neutral500,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    creator.totalAudience > 0
                        ? '$channels · ${Fmt.compact(creator.totalAudience)}'
                        : channels,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
