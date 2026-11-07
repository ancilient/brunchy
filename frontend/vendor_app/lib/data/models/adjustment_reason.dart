enum AdjustmentReason { sale, waste, spoilage, correction }

extension AdjustmentReasonLabel on AdjustmentReason {
  String get label {
    switch (this) {
      case AdjustmentReason.sale:       return 'Sale';
      case AdjustmentReason.waste:      return 'Waste';
      case AdjustmentReason.spoilage:   return 'Spoilage';
      case AdjustmentReason.correction: return 'Correction';
    }
  }

  String get apiValue {
    switch (this) {
      case AdjustmentReason.sale:       return 'sale';
      case AdjustmentReason.waste:      return 'waste';
      case AdjustmentReason.spoilage:   return 'spoilage';
      case AdjustmentReason.correction: return 'correction';
    }
  }
}

