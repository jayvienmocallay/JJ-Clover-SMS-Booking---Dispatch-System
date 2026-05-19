import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(kCardPadding),
    this.margin,
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = kCardRadius,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? palette.border),
    );

    if (onTap != null) {
      final interactiveCard = Material(
        color: color ?? palette.card,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      );
      if (margin == null) return interactiveCard;
      return Padding(padding: margin!, child: interactiveCard);
    }

    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? palette.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? palette.border),
      ),
      child: child,
    );
    return card;
  }
}
