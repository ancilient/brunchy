import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../data/models/adjustment_reason.dart';
import '../../core/errors/app_exception.dart';
import 'inventory_state.dart';

class InventoryCubit extends Cubit<InventoryState> {
  final InventoryRepository _inventoryRepository;

  InventoryCubit(this._inventoryRepository) : super(const InventoryInitial());

  Future<void> loadInventory({required String stallId, required String date}) async {
    emit(const InventoryLoading());
    try {
      // [API-015] GET /stalls/{stallId}/inventory/{date}
      final items = await _inventoryRepository.getInventory(stallId: stallId, date: date);
      if (items.isEmpty) {
        emit(const InventoryEmpty());
      } else {
        emit(InventoryLoaded(items: items, date: date));
      }
    } on AppException catch (e) {
      emit(InventoryError(e.message));
    } catch (_) {
      emit(const InventoryError('Failed to load inventory.'));
    }
  }

  Future<void> updateStock({
    required String stallId,
    required String itemId,
    required int newStock,
    AdjustmentReason reason = AdjustmentReason.sale,
  }) async {
    final base = _currentLoaded;
    if (base == null) return;
    // Optimistic update
    final updated = base.items.map((i) {
      if (i.id == itemId) return i.copyWith(currentStock: newStock, reason: reason);
      return i;
    }).toList();
    emit(InventoryLoaded(items: updated, date: base.date));
    try {
      // [API-016] PATCH /stalls/{stallId}/inventory/{date}/{itemId}
      await _inventoryRepository.updateStock(
        stallId: stallId,
        date: base.date,
        itemId: itemId,
        currentStock: newStock,
        reason: reason,
      );
    } catch (_) {
      // Revert on error
      emit(base);
    }
  }

  void resetItemToDefault({required String itemId}) {
    final base = _currentLoaded;
    if (base == null) return;
    final updated = base.items.map((i) {
      if (i.id == itemId) return i.copyWith(currentStock: i.openingStock);
      return i;
    }).toList();
    emit(InventoryLoaded(items: updated, date: base.date));
  }

  InventoryLoaded? get _currentLoaded {
    final s = state;
    return s is InventoryLoaded ? s : null;
  }
}

