import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class RecoveryHeroCard extends StatelessWidget {
  final double totalDue;
  final int billCount;
  final double collectedTodayAmount;
  final int overdueCount;
  final int partialCount;

  const RecoveryHeroCard({
    super.key,
    required this.totalDue,
    required this.billCount,
    required this.collectedTodayAmount,
    required this.overdueCount,
    required this.partialCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF172033),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.route_outlined, color: primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today route',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Collect, note, sync',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroMetricCard(label: 'Due', value: _formatAmount(totalDue)),
              _HeroMetricCard(label: 'Bills', value: '$billCount'),
              _HeroMetricCard(
                label: 'Today',
                value: _formatAmount(collectedTodayAmount),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SignalChip(
                icon: Icons.warning_amber_outlined,
                label: '$overdueCount overdue',
                color: warning,
              ),
              _SignalChip(
                icon: Icons.pie_chart_outline,
                label: '$partialCount partial',
                color: info,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RecoverySegmentedTabs extends StatelessWidget {
  final TabController controller;
  final Color background;

  const RecoverySegmentedTabs({
    super.key,
    required this.controller,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: pn.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: pn.border),
        ),
        child: TabBar(
          controller: controller,
          indicatorSize: TabBarIndicatorSize.tab,
          labelPadding: EdgeInsets.zero,
          splashBorderRadius: BorderRadius.circular(14),
          labelColor: Colors.white,
          unselectedLabelColor: pn.textMuted,
          indicator: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(14),
          ),
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          tabs: const [
            _SegmentTab(label: 'All'),
            _SegmentTab(label: 'Overdue'),
            _SegmentTab(label: 'Partial'),
            _SegmentTab(label: 'Today'),
            _SegmentTab(label: 'Visits'),
          ],
        ),
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  final String label;

  const _SegmentTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Center(child: Text(label)),
    );
  }
}

class _HeroMetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 92, maxWidth: 160),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SignalChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatAmount(double value) => 'Rs. ${value.toStringAsFixed(0)}';
