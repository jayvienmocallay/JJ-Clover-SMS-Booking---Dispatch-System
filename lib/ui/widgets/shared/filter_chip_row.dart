import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class FilterChipRow extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const FilterChipRow({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (i) {
          final isActive = i == selectedIndex;
          return Padding(
            padding: EdgeInsets.only(right: i < labels.length - 1 ? kCompactGap : 0),
            child: GestureDetector(
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.muted,
                  borderRadius: BorderRadius.circular(100),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isActive ? Colors.white : AppColors.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
