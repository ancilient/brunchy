import '../../data/models/menu_item.dart';
import '../../data/repositories/menu_repository.dart';
import '../mock/mock_data.dart';

class MockMenuRepository implements MenuRepository {
  final List<MenuItem> _items = MockData.buildMenuItems();

  @override
  Future<List<MenuItem>> getMenu(String stallId) async {
    // TODO(BACKEND-API): API-013 GET /stalls/{stallId}/menu
    await Future.delayed(const Duration(milliseconds: 300));
    return _items.where((i) => i.stallId == stallId).toList();
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
  }) async {
    // TODO(BACKEND-API): API-014 POST /stalls/{stallId}/menu
    await Future.delayed(const Duration(milliseconds: 300));
    final item = MenuItem(
      id: 'item_${DateTime.now().millisecondsSinceEpoch}',
      stallId: stallId,
      name: name,
      price: price,
      isAvailable: isAvailable,
      category: category,
      isVeg: isVeg,
      stock: stock,
      imageUrl: imageUrl,
      prepMinutes: prepMinutes,
      isPendingApproval: isPendingApproval,
    );
    _items.add(item);
    return item;
  }

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
    // TODO(BACKEND-API): API-015 PATCH /stalls/{stallId}/menu/{itemId}
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx == -1) throw Exception('Item not found');
    final updated = _items[idx].copyWith(
      name: name,
      price: price,
      category: category,
      isAvailable: isAvailable,
      isVeg: isVeg,
      stock: stock,
      imageUrl: imageUrl,
      prepMinutes: prepMinutes,
      isPendingApproval: isPendingApproval,
      pendingPrice: pendingPrice,
    );
    _items[idx] = updated;
    return updated;
  }

  @override
  Future<void> deleteItem({required String stallId, required String itemId}) async {
    // TODO(BACKEND-API): API-016 DELETE /stalls/{stallId}/menu/{itemId}
    await Future.delayed(const Duration(milliseconds: 200));
    _items.removeWhere((i) => i.id == itemId);
  }
}
