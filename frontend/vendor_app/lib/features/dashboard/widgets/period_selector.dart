import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/dashboard_period.dart';
import '../../../core/widgets/sliding_tabs.dart';

class PeriodSelector extends StatelessWidget {
  final DashboardPeriod selectedPeriod;
  final ValueChanged<DashboardPeriod> onPeriodChanged;

  const PeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    const periods = DashboardPeriod.values;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: SlidingTabs(
        labels: [for (final p in periods) p.label],
        selected: periods.indexOf(selectedPeriod),
        onChanged: (i) => onPeriodChanged(periods[i]),
      ),
    );
  }
}
