import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/challenge.dart';
import '../format.dart';

/// A cover picture with a gradient behind it for while it loads, or when there
/// is no picture. [child] is drawn over it.
class ChallengeCover extends StatelessWidget {
  const ChallengeCover({
    super.key,
    required this.type,
    required this.imageUrl,
    required this.height,
    this.child,
  });

  final ChallengeType type;
  final String? imageUrl;
  final double height;
  final Widget? child;

  static (Color, Color) gradientFor(ChallengeType type) => switch (type) {
    ChallengeType.run => AppCoverColors.run,
    ChallengeType.swim => AppCoverColors.swim,
    ChallengeType.cycle => AppCoverColors.cycle,
  };

  @override
  Widget build(BuildContext context) {
    final (top, bottom) = gradientFor(type);
    final url = imageUrl;
    final width = MediaQuery.sizeOf(context).width;
    final pixels = (width * MediaQuery.devicePixelRatioOf(context)).round();
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [top, bottom],
              ),
            ),
          ),
          if (url != null)
            Image.network(
              resizedImageUrl(url, pixels),
              fit: BoxFit.cover,
              // The gradient stays visible while loading and on an error.
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
              frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: child,
              ),
            ),
          ?child,
        ],
      ),
    );
  }
}

/// The icon of a challenge type.
IconData iconForType(ChallengeType type) => switch (type) {
  ChallengeType.run => Icons.directions_run,
  ChallengeType.swim => Icons.pool,
  ChallengeType.cycle => Icons.directions_bike,
};
