// lib/features/menu/widgets/add_edit_item_sheet.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/menu_item.dart';
import '../menu_cubit.dart';

class AddEditItemSheet extends StatefulWidget {
  final MenuItem? existingItem;
  final MenuCubit menuCubit;

  const AddEditItemSheet({
    super.key,
    this.existingItem,
    required this.menuCubit,
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

  final List<String> _suggestedCategories = ['Burgers', 'Sides', 'Rolls', 'Drinks', 'Combos'];

  @override
  void initState() {
    super.initState();
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
      builder: (ctx) => AlertDialog(
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

  void _simulatePhotoSelection() {
    // Simulates choosing a photo (compressed to WebP < 150KB)
    setState(() {
      _selectedPhotoPath = 'assets/images/logo_mascot.png';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Photo selected & compressed to WebP (84 KB)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingItem != null;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Menu Item' : 'Add New Item',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Photo Picker Row
              Row(
                children: [
                  GestureDetector(
                    onTap: _simulatePhotoSelection,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.grey100,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: AppColors.grey300),
                      ),
                      child: _selectedPhotoPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              child: Image.asset(_selectedPhotoPath!, fit: BoxFit.cover),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined, size: 24, color: AppColors.grey600),
                                SizedBox(height: 2),
                                Text('Photo', style: TextStyle(fontSize: 10, color: AppColors.grey600)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Item Photo (WebP < 150KB)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(
                          _selectedPhotoPath != null ? 'Image uploaded and compressed ✓' : 'Tap square to take or upload a photo',
                          style: TextStyle(fontSize: 12, color: _selectedPhotoPath != null ? AppColors.successGreen : AppColors.grey600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Veg / Non-Veg Selector
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      selected: _isVeg,
                      label: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.eco, size: 16, color: AppColors.successGreen),
                          SizedBox(width: 6),
                          Text('Pure Veg'),
                        ],
                      ),
                      selectedColor: AppColors.successGreen.withValues(alpha: 0.15),
                      onSelected: (val) => setState(() => _isVeg = true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ChoiceChip(
                      selected: !_isVeg,
                      label: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lunch_dining, size: 16, color: AppColors.errorRed),
                          SizedBox(width: 6),
                          Text('Non-Veg'),
                        ],
                      ),
                      selectedColor: AppColors.errorRed.withValues(alpha: 0.15),
                      onSelected: (val) => setState(() => _isVeg = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Item Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  hintText: 'e.g. Veg Burger',
                  prefixIcon: Icon(Icons.fastfood_outlined),
                ),
                textCapitalization: TextCapitalization.words,
                validator: Validators.validateItemName,
              ),
              const SizedBox(height: AppSpacing.md),

              // Price & Daily Stock
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price (₹) *',
                        hintText: '80',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: Validators.validatePrice,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      decoration: const InputDecoration(
                        labelText: 'Daily Stock *',
                        hintText: '25',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Category & Prep minutes
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        hintText: 'Burgers',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _prepMinutesController,
                      decoration: const InputDecoration(
                        labelText: 'Prep (min)',
                        hintText: '5',
                        prefixIcon: Icon(Icons.timer_outlined),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Suggested categories
              Wrap(
                spacing: AppSpacing.xs,
                children: _suggestedCategories.map((cat) {
                  return ActionChip(
                    label: Text(cat),
                    backgroundColor: _categoryController.text == cat
                        ? AppColors.primaryOrange.withValues(alpha: 0.15)
                        : AppColors.grey100,
                    labelStyle: TextStyle(
                      color: _categoryController.text == cat
                          ? AppColors.primaryOrange
                          : AppColors.grey700,
                      fontSize: 12,
                    ),
                    onPressed: () {
                      setState(() {
                        _categoryController.text = cat;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),

              // Available switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Available for ordering'),
                subtitle: Text(
                  _isAvailable ? 'Students can order this item' : 'Marked as sold out',
                  style: theme.textTheme.bodySmall,
                ),
                value: _isAvailable,
                activeColor: AppColors.vendorTeal,
                onChanged: (val) => setState(() => _isAvailable = val),
              ),
              const SizedBox(height: AppSpacing.lg),

              Row(
                children: [
                  if (isEditing) ...[
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
                      tooltip: 'Delete item',
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      onPressed: _confirmDelete,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(AppStrings.cancel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: _submit,
                      child: Text(isEditing ? 'Save Changes' : 'Add Item'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
