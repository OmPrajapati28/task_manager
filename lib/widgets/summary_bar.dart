import 'package:flutter/material.dart';

/// Shows total / pending / completed counts.
class SummaryBar extends StatelessWidget {
  const SummaryBar({
    super.key,
    required this.total,
    required this.pending,
    required this.completed,
  });

  final int total;
  final int pending;
  final int completed;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            _Stat(label: 'Total', value: total),
            _Stat(label: 'Pending', value: pending),
            _Stat(label: 'Completed', value: completed),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: textTheme.headlineSmall),
          Text(label, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}
