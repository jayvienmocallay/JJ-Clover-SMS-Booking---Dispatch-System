import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'shared/bottom_sheet_handle.dart';
import 'shared/primary_action_button.dart';

class DeliveryIssueResult {
  final String note;
  final bool keepForRedispatch;

  const DeliveryIssueResult({
    required this.note,
    required this.keepForRedispatch,
  });
}

class DeliveryIssueSheet extends StatefulWidget {
  const DeliveryIssueSheet({super.key});

  @override
  State<DeliveryIssueSheet> createState() => _DeliveryIssueSheetState();
}

class _DeliveryIssueSheetState extends State<DeliveryIssueSheet> {
  final _notesController = TextEditingController();
  bool _keepForRedispatch = true;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final note = _notesController.text.trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a note before saving.')),
      );
      return;
    }
    Navigator.pop(
      context,
      DeliveryIssueResult(
        note: note,
        keepForRedispatch: _keepForRedispatch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final palette = AppColors.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BottomSheetHandle(title: 'Delivery Note'),
            const SizedBox(height: 16),
            Text(
              'Record a delivery note for dispatch follow-up.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.mutedForeground,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Add delivery note',
                filled: true,
                fillColor: palette.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(kButtonRadius),
                  borderSide: BorderSide(color: palette.border),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _keepForRedispatch,
              onChanged: (value) => setState(() => _keepForRedispatch = value),
              title: Text(
                'Keep in dispatch queue',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              subtitle: Text(
                _keepForRedispatch
                    ? 'Return this order to confirmed for another attempt.'
                    : 'Move this order out of active dispatch.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 20),
            PrimaryActionButton(label: 'Save Note', onTap: _submit),
          ],
        ),
      ),
    );
  }
}
