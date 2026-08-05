import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../core/theme/djassa_theme.dart';

/// Bloc de base "shimmer" : un container qui pulse doucement en opacité
/// pour signaler un chargement, à la place d'un simple spinner.
/// Remplace [CupertinoActivityIndicator] partout où l'utilisateur perçoit
/// autrement l'app comme "lente" (#5 de la revue UX).
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final Animation<double> _opacity =
      Tween<double>(begin: 0.35, end: 0.85).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: DjassaTheme.primaryBlack
                .withValues(alpha: 0.06 * _opacity.value * 2),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Ligne de pastilles catégories fantômes, imite la forme réelle de
/// [CategoryPill] pendant le chargement.
class CategoryPillSkeletonRow extends StatelessWidget {
  const CategoryPillSkeletonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      scrollDirection: Axis.horizontal,
      itemCount: 5,
      separatorBuilder: (_, __) => SizedBox(width: 3.w),
      itemBuilder: (context, index) => ShimmerBox(
        width: 22.w,
        height: 15.h,
        borderRadius: 16,
      ),
    );
  }
}

/// Grille de cartes produit fantômes, imite [ProductCard] (image + 2 lignes
/// de texte) pendant le chargement.
class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 1.8.h,
        crossAxisSpacing: 3.5.w,
        childAspectRatio: .68,
      ),
      itemBuilder: (context, index) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: ShimmerBox(borderRadius: 14)),
          SizedBox(height: 1.h),
          ShimmerBox(width: double.infinity, height: 1.4.h),
          SizedBox(height: 0.6.h),
          ShimmerBox(width: 18.w, height: 1.4.h),
        ],
      ),
    );
  }
}