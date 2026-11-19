// lib/features/menu/widgets/add_edit_item_sheet.dart
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/image_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/menu_item.dart';
import '../menu_cubit.dart';
import '../../../core/widgets/app_dialog.dart';

class AddEditItemSheet extends StatefulWidget {
  final MenuItem? existingItem;
  final MenuCubit menuCubit;
  final ImageHelper? imageHelper;

  const AddEditItemSheet({
    super.key,
    this.existingItem,
    required this.menuCubit,
    this.imageHelper,
  });

  @override
  State<AddEditItemSheet> createState() => _AddEditItemSheetState();
}

class _AddEditItemSheetState extends State<AddEditItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _categoryController;
  late final TextEditingController _stockController;
  late final TextEditingController _prepMinutesController;
  late bool _isAvailable;
  late bool _isVeg;
  String? _selectedPhotoPath;
  Uint8List? _selectedPhotoBytes;
  bool _isCompressing = false;
  late final ImageHelper _imageHelper;

  final List<String> _suggestedCategories = ['Burgers', 'Sides', 'Rolls', 'Drinks', 'Combos'];

  @override
  void initState() {
    super.initState();
    _imageHelper = widget.imageHelper ?? ImageHelper();
    final item = widget.existingItem;
    _nameController = TextEditingController(text: item?.name ?? '');
    _priceController = TextEditingController(text: item != null ? item.price.toStringAsFixed(0) : '');
    _categoryController = TextEditingController(text: item?.category ?? 'Burgers');
    _stockController = TextEditingController(text: '${item?.stock ?? 25}');
    _prepMinutesController = TextEditingController(text: '${item?.prepMinutes ?? 5}');
    _isAvailable = item?.isAvailable ?? true;
    _isVeg = item?.isVeg ?? true;
    _selectedPhotoPath = item?.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _stockController.dispose();
    _prepMinutesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final price = double.parse(_priceController.text.trim());
    final category = _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim();
    final stock = int.tryParse(_stockController.text.trim()) ?? 20;
    final prepMinutes = int.tryParse(_prepMinutesController.text.trim()) ?? 5;

    // Price change request check (if vendor changes existing price, mock manager approval)
    final isPriceChanged = widget.existingItem != null && widget.existingItem!.price != price;

    widget.menuCubit.saveItem(
      existing: widget.existingItem,
      name: name,
      price: price,
      category: category,
      isAvailable: _isAvailable,
      isVeg: _isVeg,
      stock: stock,
      imageUrl: _selectedPhotoPath,
      prepMinutes: prepMinutes,
      isPendingApproval: isPriceChanged, // Pending manager approval if price changed
      pendingPrice: isPriceChanged ? price : null,
    );

    Navigator.of(context).pop();
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        title: const Text('Delete Menu Item?'),
        content: Text('Are you sure you want to delete "${widget.existingItem!.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () {
              Navigator.of(ctx).pop(); // dialog
              Navigator.of(context).pop(); // sheet
              widget.menuCubit.deleteItem(widget.existingItem!.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePhotoSelection() async {
    if (_isCompressing) return;

    final source = await ImageHelper.showPhotoSourceSheet(context);
    if (!mounted || source == null) return; // User cancelled source selection

    setState(() => _isCompressing = true);

    try {
      final result = await _imageHelper.pickAndCompressImage(
        source: source,
        context: context,
      );

      if (!mounted) return;

      if (result != null) {
        setState(() {
          _selectedPhotoPath = result.path;
          _selectedPhotoBytes = result.bytes;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo selected & compressed to WebP (${result.sizeInKb} KB)'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCompressing = false);
      }
    }
  }

  Widget _buildImagePreview() {
    if (_isCompressing) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (_selectedPhotoBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Image.memory(
          _selectedPhotoBytes!,
          fit: BoxFit.cover,
          width: 56,
          height: 56,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 24, color: AppColors.grey500),
        ),
      );
    }

    if (_selectedPhotoPath != null && _selectedPhotoPath!.isNotEmpty) {
      final path = _selectedPhotoPath!;
      Widget imageWidget;
      if (path.startsWith('assets/')) {
        imageWidget = Image.asset(path, fit: BoxFit.cover, width: 56, height: 72);
      } else if (path.startsWith('http://') || path.startsWith('https://')) {
        imageWidget = Image.network(
          path,
          fit: BoxFit.cover,
          width: 56,
          height: 56,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 24, color: AppColors.grey500),
        );
      } else {
        if (kIsWeb) {
          imageWidget = Image.network(path, fit: BoxFit.cover, width: 56, height: 72);
        } else {
          imageWidget = Image.file(
            File(path),
            fit: BoxFit.cover,
            width: 56,
            height: 56,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 24, color: AppColors.grey500),
          );
        }
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: imageWidget,
      );
    }

    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo_outlined, size: 24, color: AppColors.grey600),
        SizedBox(height: 2),
        Text('Photo', style: TextStyle(fontSize: 10, color: AppColors.grey600)),
      ],
    );
  }

  // ---------------- layout: a classic compact form (labels above slim fields) ----------------

  InputDecoration _field({String? hint, String? prefix, String? suffix}) => InputDecoration(
        isDense: true,
        hintText: hint,
        prefixText: prefix,
        suffixText: suffix,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.grey500),
        prefixStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        suffixStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        filled: true,
        fillColor: AppColors.cardWhite,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.grey300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.grey300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.errorRed)),
        errorStyle: const TextStyle(fontSize: 11),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textSecondary)),
      );

  Widget _labeled(String label, Widget field) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [_label(label), field]);

  /// The standard Indian food mark: a dot in a square, green for veg, red for non-veg.
  Widget _foodMark(Color color) => Container(
        width: 13,
        height: 13,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: color, width: 1.4), borderRadius: BorderRadius.circular(2)),
        child: Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      );

  Widget _vegSwitch() {
    Widget option(bool veg) {
      final selected = _isVeg == veg;
      final color = veg ? AppColors.successGreen : AppColors.errorRed;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => _isVeg = veg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.cardWhite : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              boxShadow: selected ? [BoxShadow(color: AppColors.ink.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))] : null,
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _foodMark(color),
              const SizedBox(width: 6),
              Text(veg ? 'Veg' : 'Non-veg',
                  style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.textPrimary : AppColors.textSecondary)),
            ]),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [option(true), option(false)]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingItem != null;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.sm),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isEditing ? 'Edit Menu Item' : 'Add New Item',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.ink)),
                  Text(isEditing ? 'Changes show in the student app right away' : 'Fill in the details students will see',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                visualDensity: VisualDensity.compact,
                tooltip: AppStrings.cancel,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Photo
                Row(children: [
                  InkWell(
                    onTap: _handlePhotoSelection,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.grey50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.grey300),
                      ),
                      child: _buildImagePreview(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Item Photo (WebP < 150KB)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        _isCompressing
                            ? 'Compressing image to WebP...'
                            : (_selectedPhotoPath != null ? 'Image uploaded and compressed ✓' : 'Tap square to take or upload a photo'),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _isCompressing
                              ? AppColors.primary
                              : (_selectedPhotoPath != null ? AppColors.successGreen : AppColors.textSecondary),
                        ),
                      ),
                    ]),
                  ),
                ]),
                const SizedBox(height: AppSpacing.md),

                _labeled('Type', _vegSwitch()),
                const SizedBox(height: AppSpacing.md),

                _labeled(
                  'Item name *',
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(fontSize: 14),
                    decoration: _field(hint: 'e.g. Veg Burger'),
                    textCapitalization: TextCapitalization.words,
                    validator: Validators.validateItemName,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Price · Stock · Prep in one row
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    flex: 4,
                    child: _labeled(
                      'Price *',
                      TextFormField(
                        controller: _priceController,
                        style: const TextStyle(fontSize: 14),
                        decoration: _field(hint: '80', prefix: '₹ '),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: Validators.validatePrice,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 3,
                    child: _labeled(
                      'Stock *',
                      TextFormField(
                        controller: _stockController,
                        style: const TextStyle(fontSize: 14),
                        decoration: _field(hint: '25'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 3,
                    child: _labeled(
                      'Prep',
                      TextFormField(
                        controller: _prepMinutesController,
                        style: const TextStyle(fontSize: 14),
                        decoration: _field(hint: '5', suffix: 'min'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: AppSpacing.md),

                _labeled(
                  'Category',
                  TextFormField(
                    controller: _categoryController,
                    style: const TextStyle(fontSize: 14),
                    decoration: _field(hint: 'Burgers'),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final cat in _suggestedCategories)
                      () {
                        final selected = _categoryController.text == cat;
                        return InkWell(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          onTap: () => setState(() => _categoryController.text = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.cardWhite,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                              border: Border.all(color: selected ? AppColors.primary : AppColors.grey300),
                            ),
                            child: Text(cat,
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
                                    color: selected ? AppColors.primary : AppColors.textSecondary)),
                          ),
                        );
                      }(),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Available
                Container(
                  padding: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.grey300),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Available for ordering', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        Text(_isAvailable ? 'Students can order this item' : 'Marked as sold out',
                            style: TextStyle(fontSize: 11, color: _isAvailable ? AppColors.successGreen : AppColors.textSecondary)),
                      ]),
                    ),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: _isAvailable,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) => setState(() => _isAvailable = val),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          const Divider(height: 1),
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
            child: Row(children: [
              if (isEditing)
                TextButton.icon(
                  onPressed: _confirmDelete,
                  style: TextButton.styleFrom(foregroundColor: AppColors.errorRed, visualDensity: VisualDensity.compact),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete', style: TextStyle(fontSize: 13)),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                child: const Text(AppStrings.cancel, style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _submit,
                child: Text(isEditing ? 'Save Changes' : 'Add Item', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
