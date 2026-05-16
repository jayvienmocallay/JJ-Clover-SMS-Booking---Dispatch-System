import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/order_model.dart';
import '../../data/providers/order_provider.dart';
import '../../data/services/command_handlers/sms_handler_utils.dart';
import '../theme/app_theme.dart';
import 'shared/bottom_sheet_handle.dart';
import 'shared/primary_action_button.dart';

class CompleteOrderSheet extends StatefulWidget {
  final Order order;

  const CompleteOrderSheet({super.key, required this.order});

  @override
  State<CompleteOrderSheet> createState() => _CompleteOrderSheetState();
}

class _CompleteOrderSheetState extends State<CompleteOrderSheet> {
  late int _quantityDelivered;
  int? _returnedContainers;
  bool _cashCollected = true;
  bool _submitting = false;
  final _notesController = TextEditingController();
  final _returnedController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _quantityDelivered = widget.order.quantity;
  }

  @override
  void dispose() {
    _notesController.dispose();
    _returnedController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_quantityDelivered < AppConstants.minQuantity ||
        _quantityDelivered > AppConstants.maxQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivered quantity is out of range.')),
      );
      return;
    }

    final smsMessage = _deliveryCompletedSms();
    final confirmed = await _confirmCompleteDelivery(smsMessage);
    if (!confirmed || !mounted) return;

    setState(() => _submitting = true);
    final provider = context.read<OrderProvider>();
    await provider.completeOrder(
      widget.order.id!,
      quantityDelivered: _quantityDelivered,
      returnedContainers: _returnedContainers,
      cashCollected: _cashCollected,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!)),
      );
      return;
    }

    await SmsHandlerUtils.sendReply(widget.order.phoneNumber, smsMessage);
    if (!mounted) return;
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Order completed. Customer SMS notification queued.'),
      ),
    );
  }

  Future<bool> _confirmCompleteDelivery(String smsMessage) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final palette = AppColors.of(ctx);
            return AlertDialog(
              backgroundColor: palette.card,
              title: Text(
                'Complete Delivery?',
                style: Theme.of(ctx).textTheme.headlineSmall,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will complete the order, save the delivery log, and notify the customer by SMS.',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.muted,
                      borderRadius: BorderRadius.circular(kButtonRadius),
                      border: Border.all(color: palette.border),
                    ),
                    child: Text(
                      smsMessage,
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.statusOperating,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Complete Delivery'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  String _deliveryCompletedSms() {
    final quantity = _quantityDelivered > 0
        ? ' ($_quantityDelivered gallon${_quantityDelivered == 1 ? '' : 's'})'
        : '';
    return 'JJ Clover: Your water order$quantity has been delivered. '
        'Thank you!';
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
            const BottomSheetHandle(title: 'Complete Delivery'),
            const SizedBox(height: 16),
            Text(
              '${widget.order.quantity} gallon${widget.order.quantity == 1 ? '' : 's'} ordered',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.mutedForeground,
                  ),
            ),
            const SizedBox(height: 20),
            Text('Quantity delivered',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                _quantityButton(Icons.remove, () {
                  if (_quantityDelivered > AppConstants.minQuantity) {
                    setState(() => _quantityDelivered--);
                  }
                }),
                Expanded(
                  child: Center(
                    child: Text(
                      '$_quantityDelivered',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                ),
                _quantityButton(Icons.add, () {
                  if (_quantityDelivered < AppConstants.maxQuantity) {
                    setState(() => _quantityDelivered++);
                  }
                }),
              ],
            ),
            const SizedBox(height: 16),
            Text('Returned containers',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _returnedController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Optional'),
              onChanged: (value) {
                final parsed = int.tryParse(value.trim());
                setState(() => _returnedContainers = parsed);
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _cashCollected,
              onChanged: (value) => setState(() => _cashCollected = value),
              title: Text('Cash collected',
                  style: Theme.of(context).textTheme.bodyMedium),
              subtitle: Text(
                _cashCollected ? 'Mark log as paid in cash' : 'Cash not collected yet',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 12),
            Text('Notes', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              decoration: _inputDecoration('Optional delivery notes'),
            ),
            const SizedBox(height: 24),
            PrimaryActionButton(
              label: _submitting ? 'Completing...' : 'Complete Order',
              onTap: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _quantityButton(IconData icon, VoidCallback onTap) {
    final palette = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(kButtonRadius),
          border: Border.all(color: palette.border),
        ),
        child: Icon(icon, size: 18, color: palette.mutedForeground),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    final palette = AppColors.of(context);
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: palette.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kButtonRadius),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kButtonRadius),
        borderSide: BorderSide(color: palette.border),
      ),
    );
  }
}
