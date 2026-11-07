import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/menu_repository.dart';
import '../../data/models/menu_item.dart';
import '../../core/errors/app_exception.dart';
import 'menu_state.dart';

class MenuCubit extends Cubit<MenuState> {
  final MenuRepository _menuRepository;
  String? _currentStallId;

  MenuCubit(this._menuRepository) : super(const MenuInitial());

  String? get currentStallId => _currentStallId;

  Future<void> loadMenu(String stallId) async {
    _currentStallId = stallId;
    emit(const MenuLoading());
    try {
      // [API-011] GET /stalls/{stallId}/menu
      final items = await _menuRepository.getMenu(stallId);
      if (items.isEmpty) {
        emit(const MenuEmpty());
      } else {
        emit(MenuLoaded(items));
      }
    } on AppException catch (e) {
      emit(MenuError(e.message));
    } catch (_) {
      emit(const MenuError('Failed to load menu.'));
    }
  }

  Future<void> toggleAvailability({required String itemId, required bool isAvailable}) async {
    final base = _currentItems;
    if (base == null || _currentStallId == null) return;
    emit(MenuSaving(base));
    try {
      // [API-013] PATCH /stalls/{stallId}/menu/{itemId}
      final updated = await _menuRepository.updateItem(
        stallId: _currentStallId!,
        itemId: itemId,
        isAvailable: isAvailable,
      );
      final items = base.map((i) => i.id == itemId ? updated : i).toList();
      emit(MenuLoaded(items));
    } catch (_) {
      emit(MenuLoaded(base)); // revert on error
    }
  }

  /// Optimistic stock update with automatic rollback on failure
  Future<void> updateStock({required String itemId, required int stock}) async {
    final base = _currentItems;
    if (base == null || _currentStallId == null) return;

    // Optimistic update
    final optimisticItems = base.map((i) {
      if (i.id == itemId) {
        return i.copyWith(
          stock: stock,
          isAvailable: stock > 0 ? i.isAvailable : false,
        );
      }
      return i;
    }).toList();
    emit(MenuLoaded(optimisticItems));

    try {
      // [API-013] PATCH /stalls/{stallId}/menu/{itemId}
      final updated = await _menuRepository.updateItem(
        stallId: _currentStallId!,
        itemId: itemId,
        stock: stock,
        isAvailable: stock > 0 ? null : false,
      );
      final items = optimisticItems.map((i) => i.id == itemId ? updated : i).toList();
      emit(MenuLoaded(items));
    } catch (_) {
      // Rollback to original base
      emit(MenuLoaded(base));
    }
  }

  Future<void> saveItem({
    MenuItem? existing,
    required String name,
    required double price,
    String? category,
    required bool isAvailable,
    bool isVeg = true,
    int stock = 20,
    String? imageUrl,
    int prepMinutes = 5,
    bool isPendingApproval = false,
    double? pendingPrice,
  }) async {
    final base = _currentItems ?? [];
    if (_currentStallId == null) return;
    emit(MenuSaving(base));
    try {
      if (existing == null) {
        // [API-012] POST /stalls/{stallId}/menu
        final added = await _menuRepository.addItem(
          stallId: _currentStallId!,
          name: name,
          price: price,
          category: category,
          isAvailable: isAvailable,
          isVeg: isVeg,
          stock: stock,
          imageUrl: imageUrl,
          prepMinutes: prepMinutes,
          isPendingApproval: isPendingApproval,
        );
        emit(MenuLoaded([...base, added]));
      } else {
        // [API-013] PATCH /stalls/{stallId}/menu/{itemId}
        final updated = await _menuRepository.updateItem(
          stallId: _currentStallId!,
          itemId: existing.id,
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
        final items = base.map((i) => i.id == existing.id ? updated : i).toList();
        emit(MenuLoaded(items));
      }
    } on AppException catch (e) {
      emit(MenuError(e.message));
    } catch (_) {
      emit(const MenuError('Failed to save item.'));
    }
  }

  Future<void> deleteItem(String itemId) async {
    final base = _currentItems;
    if (base == null || _currentStallId == null) return;
    emit(MenuSaving(base));
    try {
      // [API-014] DELETE /stalls/{stallId}/menu/{itemId}
      await _menuRepository.deleteItem(stallId: _currentStallId!, itemId: itemId);
      final items = base.where((i) => i.id != itemId).toList();
      emit(items.isEmpty ? const MenuEmpty() : MenuLoaded(items));
    } catch (_) {
      emit(MenuLoaded(base));
    }
  }

  List<MenuItem>? get _currentItems {
    final s = state;
    if (s is MenuLoaded) return s.items;
    if (s is MenuSaving) return s.items;
    return null;
  }
}
