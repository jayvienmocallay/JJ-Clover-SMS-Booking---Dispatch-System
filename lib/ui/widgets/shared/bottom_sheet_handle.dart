import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class BottomSheetHandle extends StatelessWidget {
  final String? title;

  const BottomSheetHandle({super.key, this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.of(context).border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        if (title != null) ...[
          const SizedBox(height: 16),
          Text(
            title!,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ],
      ],
    );
  }
}
