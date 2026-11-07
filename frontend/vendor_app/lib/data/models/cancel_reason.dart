enum CancelReason { outOfStock, kitchenIssue, stallEmergency }

extension CancelReasonLabel on CancelReason {
  String get label {
    switch (this) {
      case CancelReason.outOfStock:
        return 'Out of stock';
      case CancelReason.kitchenIssue:
        return 'Kitchen issue';
      case CancelReason.stallEmergency:
        return 'Stall emergency';
    }
  }

  String get apiValue {
    switch (this) {
      case CancelReason.outOfStock:
        return 'OUT_OF_STOCK';
      case CancelReason.kitchenIssue:
        return 'KITCHEN_ISSUE';
      case CancelReason.stallEmergency:
        return 'STALL_EMERGENCY';
    }
  }
}
