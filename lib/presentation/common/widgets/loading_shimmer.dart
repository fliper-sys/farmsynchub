import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer loading placeholder widget.
class LoadingShimmer extends StatelessWidget {
  const LoadingShimmer({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8.0,
    this.child,
  });

  final double? width;
  final double? height;
  final double borderRadius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surface,
      highlightColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: child ??
          Container(
            width: width,
            height: height ?? 16,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
    );
  }
}

/// Shimmer loading card for lists.
class LoadingShimmerCard extends StatelessWidget {
  const LoadingShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const LoadingShimmer(width: 40, height: 40, borderRadius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LoadingShimmer(width: double.infinity, height: 16),
                      const SizedBox(height: 8),
                      const LoadingShimmer(width: 100, height: 12),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const LoadingShimmer(width: double.infinity, height: 12),
            const SizedBox(height: 8),
            const LoadingShimmer(width: 150, height: 12),
          ],
        ),
      ),
    );
  }
}