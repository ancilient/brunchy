import '../../data/models/inventory_item.dart';
import '../../data/models/adjustment_reason.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../core/errors/app_exception.dart';
import '../mock/mock_data.dart';

class MockInventoryRepository implements InventoryRepository {
  final List<InventoryItem> _items = MockData.buildInventory();

  @override
  Future<List<InventoryItem>> getInventory({required String stallId, required String date}) async {
    // TODO(BACKEND-API): API-017 GET /stalls/{stallId}/inventory/{date}
    await Future.delayed(const Duration(milliseconds: 600));
    return _items.where((i) => i.stallId == stallId).toList();
  }

  @override
  Future<InventoryItem> updateStock({
    required String stallId, required String date, required String itemId,
    required int currentStock, required AdjustmentReason reason,
  }) async {
    // TODO(BACKEND-API): API-018 PATCH /stalls/{stallId}/inventory/{date}/{itemId}
    await Future.delayed(const Duration(milliseconds: 300));
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx == -1) throw AppException.network();
    if (currentStock < 0) {
      throw const AppException(message: 'Stock cannot be negative', code: 'STOCK_BELOW_ZERO');
    }
    if (currentStock > _items[idx].openingStock) {
      throw const AppException(message: 'Stock cannot exceed opening stock', code: 'STOCK_ABOVE_OPENING');
    }
    final updated = _items[idx].copyWith(currentStock: currentStock, reason: reason);
    _items[idx] = updated;
    return updated;
  }

  @override
  Future<void> closeDay({required String stallId, required bool forceClose}) async {
    // TODO(BACKEND-API): API-019 POST /stalls/{stallId}/day/close
    await Future.delayed(const Duration(milliseconds: 400));
    // In mock: no-op. In production, server saves closing stock as next day's opening.
  }
}

