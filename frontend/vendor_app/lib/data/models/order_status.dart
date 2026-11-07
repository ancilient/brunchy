enum OrderStatus { placed, accepted, ready, collected, cancelled, refunded }

extension OrderStatusLabel on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.placed:    return 'Placed';
      case OrderStatus.accepted:  return 'Preparing';
      case OrderStatus.ready:     return 'Ready';
      case OrderStatus.collected: return 'Collected';
      case OrderStatus.cancelled: return 'Cancelled';
      case OrderStatus.refunded:  return 'Refunded';
    }
  }

  static OrderStatus fromString(String s) {
    switch (s.toLowerCase()) {
      case 'placed':    return OrderStatus.placed;
      case 'accepted':  return OrderStatus.accepted;
      case 'ready':     return OrderStatus.ready;
      case 'collected': return OrderStatus.collected;
      case 'cancelled': return OrderStatus.cancelled;
      case 'refunded':  return OrderStatus.refunded;
      default:          return OrderStatus.placed;
    }
  }
}

