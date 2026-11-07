enum OrderFilter { newOrders, preparing, ready, all }

extension OrderFilterLabel on OrderFilter {
  String get label {
    switch (this) {
      case OrderFilter.newOrders: return 'New';
      case OrderFilter.preparing: return 'Preparing';
      case OrderFilter.ready:     return 'Ready';
      case OrderFilter.all:       return 'All';
    }
  }
}

