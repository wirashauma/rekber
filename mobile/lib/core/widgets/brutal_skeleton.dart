import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Neo Brutalism Skeleton Loader
/// Shimmer effect is contained INSIDE the brutalist container
class BrutalSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Offset shadowOffset;
  final EdgeInsetsGeometry? margin;

  const BrutalSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 4.0,
    this.shadowOffset = const Offset(4, 4),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.black, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black,
            offset: shadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius > 2 ? borderRadius - 2 : 0),
        child: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// A Card variant for lists (Transaction Card Skeleton)
class BrutalSkeletonCard extends StatelessWidget {
  const BrutalSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black, width: 2.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          // Leading Icon/Avatar Skeleton
          const BrutalSkeletonContent(
            width: 50,
            height: 50,
            borderRadius: 4,
          ),
          const SizedBox(width: 16),
          // Text Content Skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrutalSkeletonContent(width: 150, height: 16),
                const SizedBox(height: 8),
                const BrutalSkeletonContent(width: 100, height: 12),
              ],
            ),
          ),
          // Trailing Skeleton
          const BrutalSkeletonContent(width: 60, height: 20),
        ],
      ),
    );
  }
}

/// A smaller variant for text labels
class BrutalSkeletonText extends StatelessWidget {
  final double width;
  final double height;

  const BrutalSkeletonText({
    super.key,
    this.width = 100,
    this.height = 14,
  });

  @override
  Widget build(BuildContext context) {
    return BrutalSkeletonContent(
      width: width,
      height: height,
      borderRadius: 2,
    );
  }
}

/// Internal widget to avoid double borders/shadows in sub-elements
class BrutalSkeletonContent extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const BrutalSkeletonContent({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
