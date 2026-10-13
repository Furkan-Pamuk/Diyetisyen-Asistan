import 'package:flutter/material.dart';
import '../models/supplier_order.dart';

Color alertColor(AlertLevel level) {
  switch (level) {
    case AlertLevel.overdue:
    case AlertLevel.dueToday:
      return Colors.red;
    case AlertLevel.dueSoon:
      return Colors.orange;
    case AlertLevel.ok:
      return Colors.grey;
  }
}

class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  const StatusBadge({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

class CountdownText extends StatelessWidget {
  final int days;
  final String prefix;
  const CountdownText({super.key, required this.days, required this.prefix});

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;
    final IconData icon;
    if (days < 0) {
      text = '$prefix ${days.abs()} gün gecikti';
      color = Colors.red;
      icon = Icons.warning;
    } else if (days == 0) {
      text = '$prefix bugün!';
      color = Colors.red;
      icon = Icons.alarm;
    } else {
      text = '$prefix $days gün kaldı';
      color = days <= 2 ? Colors.orange : Colors.grey;
      icon = Icons.schedule;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(child: Text(text, style: TextStyle(fontSize: 12, color: color))),
      ],
    );
  }
}

class StockBar extends StatelessWidget {
  final double ratio;
  const StockBar({super.key, required this.ratio});

  @override
  Widget build(BuildContext context) {
    final color = ratio <= 0.25
        ? Colors.red
        : ratio <= 0.5
            ? Colors.orange
            : Colors.green;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: ratio,
        minHeight: 6,
        backgroundColor: Colors.grey.shade200,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const EmptyState(
      {super.key, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
