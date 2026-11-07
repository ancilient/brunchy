import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/dashboard_period.dart';

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
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Row(
        children: DashboardPeriod.values.map((period) {
          final isSelected = period == selectedPeriod;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3.0),
              child: ChoiceChip(
                labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                visualDensity: VisualDensity.compact,
                label: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      period.label,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? AppColors.white : AppColors.brandBrown,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                selected: isSelected,
                selectedColor: AppColors.primaryOrange,
                backgroundColor: AppColors.grey100,
                showCheckmark: false,
                onSelected: (val) {
                  if (val) {
                    onPeriodChanged(period);
                  }
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}