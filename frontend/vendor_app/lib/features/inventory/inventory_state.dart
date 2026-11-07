import 'package:equatable/equatable.dart';
import '../../data/models/inventory_item.dart';

abstract class InventoryState extends Equatable {
  const InventoryState();
  @override List<Object?> get props => [];
}

class InventoryInitial extends InventoryState { const InventoryInitial(); }
class InventoryLoading extends InventoryState { const InventoryLoading(); }
class InventoryEmpty   extends InventoryState { const InventoryEmpty(); }

class InventoryLoaded extends InventoryState {
  final List<InventoryItem> items;
  final String date;
  const InventoryLoaded({required this.items, required this.date});
  @override List<Object?> get props => [items, date];
}

class InventoryError extends InventoryState {
  final String message;
  const InventoryError(this.message);
  @override List<Object?> get props => [message];
}

