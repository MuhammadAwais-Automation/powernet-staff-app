import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pn_card.dart';

class PnKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;
  final VoidCallback? onTap;

  const PnKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    return PnCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: pn.textMuted),
            const SizedBox(height: 8),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: valueColor ?? pn.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: pn.textMuted),
          ),
        ],
      ),
    );
  }
}
