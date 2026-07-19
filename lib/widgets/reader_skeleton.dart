import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ReaderSkeleton extends StatelessWidget {
  final bool isManga;

  const ReaderSkeleton({super.key, required this.isManga});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + kToolbarHeight + 16,
          left: 16,
          right: 16,
        ),
        itemCount: 5,
        itemBuilder: (context, index) {
          if (isManga) {
            // Skeleton for manga: large rectangular blocks mimicking image panels
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            );
          } else {
            // Skeleton for novel: paragraph text lines
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: double.infinity,
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 8),
                  ),
                  Container(
                    height: 16,
                    width: double.infinity,
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 8),
                  ),
                  Container(
                    height: 16,
                    width: MediaQuery.of(context).size.width * 0.7,
                    color: Colors.white,
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
