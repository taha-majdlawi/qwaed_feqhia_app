import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';

/// خلفية التطبيق: صورة المسجد النبوي خافتة تحت طبقة لونية هادئة،
/// حتى يبقى النص مقروءاً في الوضعين الفاتح والداكن.
class MosqueBackground extends StatelessWidget {
  const MosqueBackground({
    super.key,
    required this.child,
    this.imageOpacity,
  });

  final Widget child;
  final double? imageOpacity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final opacity = imageOpacity ?? (isDark ? 0.16 : 0.13);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBg : AppColors.cream,
          ),
        ),
        Opacity(
          opacity: opacity,
          child: Image.asset(
            AppConstants.splashImage,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.medium,
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      AppColors.darkBg.withValues(alpha: 0.55),
                      AppColors.darkBg.withValues(alpha: 0.92),
                    ]
                  : [
                      AppColors.cream.withValues(alpha: 0.70),
                      AppColors.cream.withValues(alpha: 0.94),
                    ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// شريط زخرفي ذهبي رفيع يُستعمل فاصلاً.
class GoldDivider extends StatelessWidget {
  const GoldDivider({super.key, this.width = 120, this.margin});

  final double width;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 12),
      width: width,
      height: 2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: LinearGradient(
          colors: [
            AppColors.gold.withValues(alpha: 0),
            AppColors.gold,
            AppColors.gold.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
