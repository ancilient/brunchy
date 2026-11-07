// lib/features/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/validators.dart';
import '../../data/mock/mock_data.dart';
import '../../injection_container.dart';
import '../../services/local_storage_service.dart';
import 'auth_cubit.dart';
import 'auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtr = TextEditingController(text: 'Demo Vendor');
  final _phoneCtr = TextEditingController(text: '9999999999');
  String _selectedCanteenId = 'main_canteen';
  String _selectedStallId = 'stall_001';

  // Mock mode flag per requirement
  static const bool isMockMode = true;

  @override
  void dispose() {
    _nameCtr.dispose();
    _phoneCtr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthSuccess) {
          final storage = sl<LocalStorageService>();
          final stall = MockData.stalls.firstWhere(
            (s) => s.id == _selectedStallId,
            orElse: () => MockData.stalls.first,
          );
          storage.saveStallInfo(stall.id, stall.name);
          storage.saveStallSession(stall.id, DateFormatter.todayKey());
          final canteen = MockData.canteens.firstWhere(
            (c) => c.id == _selectedCanteenId,
            orElse: () => MockData.canteens.first,
          );
          storage.saveCanteenInfo(canteen.id, canteen.name);

          context.go('/home/orders');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  Center(child: Image.asset('assets/images/logo_horizontal.png', height: 54)),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Welcome!', style: Theme.of(context).textTheme.displayLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Sign in to manage your stall orders', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _nameCtr,
                    decoration: const InputDecoration(labelText: 'Your full name'),
                    textCapitalization: TextCapitalization.words,
                    validator: Validators.validateName,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _phoneCtr,
                    decoration: const InputDecoration(labelText: 'Phone number (10 digits)'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    validator: Validators.validatePhone,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Select your canteen', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Row(children: [
                    _CanteenButton(
                      id: 'main_canteen',
                      label: AppStrings.mainCanteen,
                      selected: _selectedCanteenId == 'main_canteen',
                      onTap: () {
                        setState(() {
                          _selectedCanteenId = 'main_canteen';
                          _selectedStallId = 'stall_001';
                        });
                      },
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _CanteenButton(
                      id: 'advance_block',
                      label: AppStrings.advanceBlock,
                      selected: _selectedCanteenId == 'advance_block',
                      onTap: () {
                        setState(() {
                          _selectedCanteenId = 'advance_block';
                          _selectedStallId = 'stall_006';
                        });
                      },
                    ),
                  ]),

                  // Mock Mode Canteen & Stall Picker
                  if (isMockMode) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.vendorTeal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: AppColors.vendorTeal.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.storefront_outlined, size: 20, color: AppColors.vendorTeal),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                'Assigned Stall (1 Stall / Device)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.brandBrown,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Blueprint 5.4: Each vendor device is bound to one stall.',
                            style: TextStyle(fontSize: 11, color: AppColors.grey600),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          DropdownButtonFormField<String>(
                            value: _selectedStallId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                              isDense: true,
                            ),
                            items: MockData.stalls
                                .where((s) => s.canteenId == _selectedCanteenId)
                                .map((s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text('${s.iconEmoji} ${s.name}', style: const TextStyle(fontSize: 14)),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedStallId = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),
                  BlocBuilder<AuthCubit, AuthState>(
                    builder: (context, state) {
                      final loading = state is AuthLoading;
                      final enabled = !loading &&
                          _nameCtr.text.trim().length >= 2 &&
                          _phoneCtr.text.trim().length == 10;
                      return SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: enabled ? _submit : null,
                          child: loading
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : const Text(AppStrings.startMyDay, style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthCubit>().login(
      name: _nameCtr.text.trim(),
      phone: _phoneCtr.text.trim(),
      canteenId: _selectedCanteenId,
    );
  }
}

class _CanteenButton extends StatelessWidget {
  final String id, label;
  final bool selected;
  final VoidCallback onTap;
  const _CanteenButton({required this.id, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryOrange : AppColors.cardWhite,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: selected ? AppColors.primaryOrange : AppColors.divider, width: 2),
            boxShadow: selected
                ? [BoxShadow(color: AppColors.primaryOrange.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
          ),
        ),
      ),
    );
  }
}
