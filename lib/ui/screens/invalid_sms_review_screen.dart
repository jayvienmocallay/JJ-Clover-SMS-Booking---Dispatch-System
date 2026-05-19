import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/shared/brand_mascot.dart';
import '../widgets/shared/empty_state.dart';

class InvalidSmsReviewScreen extends StatefulWidget {
  const InvalidSmsReviewScreen({super.key});

  @override
  State<InvalidSmsReviewScreen> createState() => _InvalidSmsReviewScreenState();
}

class _InvalidSmsReviewScreenState extends State<InvalidSmsReviewScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRows());
  }

  Future<void> _loadRows() async {
    setState(() => _loading = true);
    final rows = await context.read<OrderRepository>().getInvalidSmsOrders();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _markReviewed(Order order) async {
    final id = order.id;
    if (id == null) return;
    final updated = await context.read<OrderRepository>().updateOrderStatus(
      id,
      'rejected',
      reason: order.cancelReason ?? 'Reviewed invalid SMS',
    );
    if (!mounted) return;
    if (updated == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message was not marked reviewed.')),
      );
      return;
    }
    await _loadRows();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Message marked reviewed.')));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    final pendingReview = _rows
        .where((row) => row['status'] != 'rejected')
        .toList();
    final reviewed = _rows.where((row) => row['status'] == 'rejected').toList();

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: palette.foreground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Invalid SMS Review',
          style: TextStyle(
            color: palette.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRows,
        child: ListView(
          padding: const EdgeInsets.all(kPagePadding),
          children: [
            _SummaryCard(
              pending: pendingReview.length,
              reviewed: reviewed.length,
            ),
            const SizedBox(height: 16),
            if (_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(color: palette.primary),
                ),
              )
            else if (_rows.isEmpty)
              const EmptyState(
                icon: Icons.sms_failed,
                mascot: MascotPose.smsConfirm,
                title: 'SMS queue is clean',
                message: 'No invalid SMS messages found.',
              )
            else ...[
              if (pendingReview.isNotEmpty) ...[
                _SectionLabel('Needs review'),
                const SizedBox(height: 8),
                ...pendingReview.map(
                  (row) => _InvalidSmsCard(
                    order: Order.fromMap(row),
                    reviewed: false,
                    onReviewed: _markReviewed,
                  ),
                ),
              ],
              if (reviewed.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionLabel('Reviewed'),
                const SizedBox(height: 8),
                ...reviewed.map(
                  (row) => _InvalidSmsCard(
                    order: Order.fromMap(row),
                    reviewed: true,
                    onReviewed: _markReviewed,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int pending;
  final int reviewed;

  const _SummaryCard({required this.pending, required this.reviewed});

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          _SummaryValue(label: 'Needs Review', value: pending.toString()),
          Container(width: 1, height: 36, color: palette.border),
          _SummaryValue(label: 'Reviewed', value: reviewed.toString()),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.of(context).mutedForeground,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _InvalidSmsCard extends StatelessWidget {
  final Order order;
  final bool reviewed;
  final ValueChanged<Order> onReviewed;

  const _InvalidSmsCard({
    required this.order,
    required this.reviewed,
    required this.onReviewed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.sms_failed, color: palette.statusMaintenance),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.phoneNumber,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDateTime(order.createdAt),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: reviewed
                      ? palette.muted
                      : palette.statusMaintenanceLight,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  reviewed ? 'Reviewed' : 'Needs Review',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: reviewed
                        ? palette.mutedForeground
                        : palette.statusMaintenance,
                  ),
                ),
              ),
            ],
          ),
          if (order.cancelReason?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              order.cancelReason!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${order.quantity} gal · ${order.source ?? 'sms'}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const Spacer(),
              if (!reviewed)
                TextButton.icon(
                  onPressed: () => onReviewed(order),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Mark reviewed'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour}:$minute';
  }
}
