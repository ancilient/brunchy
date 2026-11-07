import 'package:brunchy_vendor/data/models/menu_item.dart';

/// Abstract repository for menu management operations.
/// Concrete implementations: [MockMenuRepository] (dev) and a future DioMenuRepository (prod).
abstract class MenuRepository {
  /// [API-013] Fetches all menu items for the given [stallId].
  Future<List<MenuItem>> getMenu(String stallId);

  /// [API-014] Creates a new menu item for the given [stallId].
  Future<MenuItem> addItem({
    required String stallId,
    required String name,
    required double price,
    String? category,
    bool isAvailable = true,
    bool isVeg = true,
    int stock = 20,
    String? imageUrl,
    int prepMinutes = 5,
    bool isPendingApproval = false,
  });

  /// [API-015] Updates an existing menu item identified by [itemId].
  /// All update fields are optional — only provided fields are changed.
  Future<MenuItem> updateItem({
    required String stallId,
    required String itemId,
    String? name,
    double? price,
    String? category,
    bool? isAvailable,
    bool? isVeg,
    int? stock,
    String? imageUrl,
    int? prepMinutes,
    bool? isPendingApproval,
    double? pendingPrice,
  });

  /// [API-016] Permanently deletes the menu item identified by [itemId].
  Future<void> deleteItem({
    required String stallId,
    required String itemId,
  });
}
