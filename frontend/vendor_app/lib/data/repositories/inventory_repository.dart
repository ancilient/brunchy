import 'package:brunchy_vendor/data/models/adjustment_reason.dart';
import 'package:brunchy_vendor/data/models/inventory_item.dart';

/// Abstract repository for inventory operations.
/// Concrete implementations: [MockInventoryRepository] (dev) and a future DioInventoryRepository (prod).
abstract class InventoryRepository {
  /// [API-017] Fetches all inventory items for [stallId] on [date] (YYYY-MM-DD).
  /// Opening stock is pre-populated from the previous day's closing stock.
  Future<List<InventoryItem>> getInventory({
    required String stallId,
    required String date,
  });

  /// [API-018] Updates the [currentStock] for a specific inventory item.
  /// [currentStock] must satisfy: 0 ≤ currentStock ≤ openingStock.
  /// Throws [AppException] if bounds are violated.
  Future<InventoryItem> updateStock({
    required String stallId,
    required String date,
    required String itemId,
    required int currentStock,
    required AdjustmentReason reason,
  });

  /// [API-019] Closes the stall's day, saving currentStock as tomorrow's opening stock.
  /// Pass [forceClose] = true to cancel any active orders before closing.
  Future<void> closeDay({
    required String stallId,
    required bool forceClose,
  });
}

