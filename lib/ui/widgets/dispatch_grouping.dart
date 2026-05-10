import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DispatchGroup<T> {
  final String title;
  final String subtitle;
  final List<T> items;

  const DispatchGroup({
    required this.title,
    required this.subtitle,
    required this.items,
  });
}

List<DispatchGroup<Map<String, dynamic>>> buildDispatchGroups(
  List<Map<String, dynamic>> orders,
) {
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final order in orders) {
    final type = order['type'] as String? ?? '';
    final status = order['status'] as String? ?? '';
    if (type == 'unrecognized') continue;
    if (status == 'completed' || status == 'cancelled' || status == 'rejected') {
      continue;
    }

    final zone = (order['delivery_zone'] as String?)?.trim();
    final barangay = (order['barangay'] as String?)?.trim();
    final address = (order['address'] as String?)?.trim();
    final key = [
      if (zone != null && zone.isNotEmpty) zone,
      if (barangay != null && barangay.isNotEmpty) barangay,
    ].join(' · ');

    final fallback = type == 'drop'
        ? 'Walk-ins'
        : (address != null && address.isNotEmpty ? 'Delivery address set' : 'Unassigned area');
    groups.putIfAbsent(key.isEmpty ? fallback : key, () => []).add(order);
  }

  final result = groups.entries.map((entry) {
    final confirmed = entry.value.where((o) => o['status'] == 'confirmed').length;
    final inTransit = entry.value.where((o) => o['status'] == 'in_transit').length;
    final pending = entry.value.where((o) => o['status'] == 'pending').length;
    return DispatchGroup<Map<String, dynamic>>(
      title: entry.key,
      subtitle: '$pending pending · $confirmed confirmed · $inTransit in transit',
      items: entry.value,
    );
  }).toList();

  result.sort((a, b) => a.title.compareTo(b.title));
  return result;
}

class DispatchGroupHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const DispatchGroupHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.muted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Icon(Icons.route, color: palette.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: palette.mutedForeground,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
