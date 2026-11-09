import '../../core/errors/app_exception.dart';
import '../models/adjustment_reason.dart';
import '../models/inventory_item.dart';
import '../models/menu_item.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/menu_repository.dart';
import 'vendor_api.dart';

const _needsApproval = AppException(
  message: 'New items and price or name changes need the canteen manager\'s approval. That screen is coming soon.',
  code: 'NEEDS_MANAGER_APPROVAL',
);

Future<List<Map<String, dynamic>>> _products(VendorApi api) async =>
    ((await api.get('/vendor/products'))['products'] as List).cast<Map<String, dynamic>>();

/// The stall's items. Vendors switch items on/off and set quantities (two taps in a rush);
/// adding items and changing prices go through the manager (blueprint 5.3), not built yet.
class RemoteMenuRepository implements MenuRepository {
  RemoteMenuRepository(this._api);
  final VendorApi _api;

  MenuItem _item(Map<String, dynamic> p) => MenuItem(
        id: p['id'] as String,
        stallId: p['stallId'] as String,
        name: p['name'] as String,
        price: (p['price'] as num).toDouble(),
        isAvailable: p['isActive'] as bool,
        category: p['category'] as String?,
        isVeg: (p['isVeg'] as bool?) ?? true,
        stock: (p['stockQuantity'] as num).toInt(),
        imageUrl: p['imageUrl'] as String?,
        prepMinutes: (p['prepMinutes'] as num?)?.toInt() ?? 5,
        isPendingApproval: p['approvalStatus'] == 'pending',
      );

  @override
  Future<List<MenuItem>> getMenu(String stallId) async => (await _products(_api)).map(_item).toList();

  @override
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
  }) async {
    final current = (await getMenu(stallId)).where((m) => m.id == itemId).firstOrNull;
    final changesNeedingApproval = (name != null && name != current?.name) ||
        (price != null && price != current?.price) ||
        (pendingPrice != null && pendingPrice != current?.price);
    if (changesNeedingApproval) throw _needsApproval;
    if (isAvailable == null && stock == null) {
      if (current == null) throw const AppException(message: 'Item not found', code: 'PRODUCT_NOT_FOUND');
      return current; // nothing the vendor may change on their own
    }
    await _api.patch('/vendor/products/$itemId', {
      if (isAvailable != null) 'isActive': isAvailable,
      if (stock != null) 'stockQuantity': stock,
    });
    return (await getMenu(stallId)).firstWhere((m) => m.id == itemId);
  }

  @override
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
  }) async =>
      throw _needsApproval;

  @override
  Future<void> deleteItem({required String stallId, required String itemId}) async {
    // Items are never deleted (soft delete only): switching off hides it from students.
    await _api.patch('/vendor/products/$itemId', {'isActive': false});
  }
}

/// Today's stock per item. Opening = the item's daily default quantity (or the current stock, if higher);
/// current = live stock on the server, which checkout reduces as students order.
class RemoteInventoryRepository implements InventoryRepository {
  RemoteInventoryRepository(this._api);
  final VendorApi _api;

  InventoryItem _item(Map<String, dynamic> p, String date) {
    final stock = (p['stockQuantity'] as num).toInt();
    final daily = (p['dailyDefaultQty'] as num?)?.toInt() ?? 0;
    return InventoryItem(
      id: p['id'] as String,
      stallId: p['stallId'] as String,
      menuItemId: p['id'] as String,
      menuItemName: p['name'] as String,
      date: date,
      openingStock: stock > daily ? stock : daily,
      currentStock: stock,
    );
  }

  @override
  Future<List<InventoryItem>> getInventory({required String stallId, required String date}) async =>
      (await _products(_api)).where((p) => p['isActive'] == true).map((p) => _item(p, date)).toList();

  @override
  Future<InventoryItem> updateStock({
    required String stallId,
    required String date,
    required String itemId,
    required int currentStock,
    required AdjustmentReason reason,
  }) async {
    if (currentStock < 0) throw const AppException(message: 'Stock cannot be negative', code: 'STOCK_BELOW_ZERO');
    await _api.patch('/vendor/products/$itemId', {'stockQuantity': currentStock});
    final p = (await _products(_api)).firstWhere((x) => x['id'] == itemId);
    return _item(p, date).copyWith(reason: reason);
  }

  @override
  Future<void> closeDay({required String stallId, required bool forceClose}) async {
    await _api.post('/vendor/stall/status', {'action': 'close'});
  }
}
