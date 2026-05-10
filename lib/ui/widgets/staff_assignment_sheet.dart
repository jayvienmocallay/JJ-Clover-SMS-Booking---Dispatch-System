import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'shared/bottom_sheet_handle.dart';
import 'shared/primary_action_button.dart';

class StaffAssignmentSheet extends StatefulWidget {
  final int? initialStaffId;

  const StaffAssignmentSheet({super.key, this.initialStaffId});

  @override
  State<StaffAssignmentSheet> createState() => _StaffAssignmentSheetState();
}

class _StaffAssignmentSheetState extends State<StaffAssignmentSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialStaffId == null ? '' : widget.initialStaffId.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid staff ID.')),
      );
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final palette = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BottomSheetHandle(title: 'Assign Staff'),
          const SizedBox(height: 16),
          Text(
            'Enter the staff or driver ID responsible for this delivery.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.mutedForeground,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Staff ID',
              filled: true,
              fillColor: palette.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kButtonRadius),
                borderSide: BorderSide(color: palette.border),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          PrimaryActionButton(label: 'Assign Staff', onTap: _submit),
        ],
      ),
    );
  }
}
