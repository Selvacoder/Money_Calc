import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SkeletonLoader extends StatelessWidget {
  final double height;
  final double width;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: 1200.ms,
          color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
        );
  }
}

class TransactionSkeleton extends StatelessWidget {
  const TransactionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SkeletonLoader(height: 48, width: 48, borderRadius: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLoader(height: 16, width: 120),
                const SizedBox(height: 8),
                const SkeletonLoader(height: 12, width: 80),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const SkeletonLoader(height: 16, width: 60),
        ],
      ),
    );
  }
}
