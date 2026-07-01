import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class CustomerTdcBanner extends StatelessWidget {
  final VoidCallback? onPayTap;

  const CustomerTdcBanner({super.key, this.onPayTap});

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pn.softOrange,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pn.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.wifi_off_rounded, color: pn.warning, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection temporarily disconnected',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: pn.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Overdue bill ki wajah se service band hai. Bill pay karein — payment verify hone ke baad connection restore ho jayega.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: pn.textSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onPayTap != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onPayTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: pn.warning,
                  side: BorderSide(color: pn.warning.withValues(alpha: 0.5)),
                ),
                child: const Text('Pay overdue bill'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
