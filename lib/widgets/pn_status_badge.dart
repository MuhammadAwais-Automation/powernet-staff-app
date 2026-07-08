import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum PnStatus {
  paid,
  unpaid,
  overdue,
  partial,
  open,
  inProgress,
  resolved,
  active,
  suspended,
  disconnected,
}

class PnStatusBadge extends StatelessWidget {
  final String label;
  final PnStatus status;

  const PnStatusBadge({super.key, required this.label, required this.status});

  factory PnStatusBadge.fromString(String value) {
    final s = switch (value.toLowerCase()) {
      'paid' => PnStatus.paid,
      'unpaid' => PnStatus.unpaid,
      'overdue' => PnStatus.overdue,
      'partial' => PnStatus.partial,
      'open' => PnStatus.open,
      'in_progress' || 'inprogress' => PnStatus.inProgress,
      'resolved' => PnStatus.resolved,
      'active' => PnStatus.active,
      'suspended' => PnStatus.suspended,
      'disconnected' => PnStatus.disconnected,
      _ => PnStatus.open,
    };
    return PnStatusBadge(
      label: switch (value.toLowerCase()) {
        'partial' => 'Less Paid',
        'paid' => 'Paid',
        'overdue' => 'Overdue',
        'pending' => 'Pending',
        _ => value,
      },
      status: s,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    final color = switch (status) {
      PnStatus.paid || PnStatus.resolved || PnStatus.active => pn.success,
      PnStatus.unpaid || PnStatus.open || PnStatus.suspended => pn.warning,
      PnStatus.overdue || PnStatus.disconnected => pn.danger,
      PnStatus.partial || PnStatus.inProgress => info,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
