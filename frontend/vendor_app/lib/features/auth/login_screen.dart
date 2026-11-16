// lib/features/auth/login_screen.dart
// Phone + OTP login. The stall comes from the account on the server (one phone per stall, blueprint 5.4),
// so there is nothing to pick here.
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/validators.dart';
import 'auth_cubit.dart';
import 'auth_state.dart';
import '../../core/widgets/brand_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  // Starts empty so the placeholder shows; debug builds offer a one-tap demo number (seed data: Burger Hub).
  static const _demoPhone = '9000000001';
  final _phoneCtr = TextEditingController();
  final _codeCtr = TextEditingController();
  String? _codeSentTo;
  bool _devFilled = false;

  @override
  void dispose() {
    _phoneCtr.dispose();
    _codeCtr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthOtpSent) {
          setState(() {
            _codeSentTo = state.phone;
            if (state.devCode != null) {
              _codeCtr.text = state.devCode!;
              _devFilled = true;
            }
          });
        } else if (state is AuthSuccess) {
          context.go('/home/orders');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(children: [
          // Soft teal glows behind the content.
          Positioned(top: -120, right: -90, child: _glow(300, AppColors.brandTeal.withValues(alpha: 0.18))),
          Positioned(bottom: -140, left: -110, child: _glow(320, AppColors.primary.withValues(alpha: 0.10))),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                child: ConstrainedBox(
                  // At least the screen's height, so the content sits in the vertical middle.
                  constraints: BoxConstraints(minHeight: box.maxHeight - AppSpacing.md * 2),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Form(key: _formKey, child: _content(context)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _glow(double size, Color color) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)])),
        ),
      );

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final codeStep = _codeSentTo != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const BrandLogo(size: 92),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppSpacing.radiusFull)),
          child: const Text('VENDOR', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.4)),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Welcome back!', textAlign: TextAlign.center, style: theme.textTheme.displayLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          codeStep ? 'Enter the code we sent to your stall phone' : "Sign in with your stall's phone number",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        // The form card
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.divider),
            boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _steps(codeStep),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _phoneCtr,
                enabled: !codeStep,
                style: theme.textTheme.titleMedium?.copyWith(letterSpacing: 1.2),
                decoration: InputDecoration(
                  hintText: 'Stall phone number (10 digits)',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(color: AppColors.grey500, letterSpacing: 0),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.phone_iphone_rounded, size: 20, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text('+91', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700)),
                      Container(width: 1, height: 20, margin: const EdgeInsets.only(left: 10), color: AppColors.divider),
                    ]),
                  ),
                  suffixIcon: codeStep ? const Icon(Icons.check_circle_rounded, color: AppColors.successGreen) : null,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                validator: Validators.validatePhone,
                onChanged: (_) => setState(() {}),
              ),
              if (!codeStep && kDebugMode && _phoneCtr.text.isEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: ActionChip(
                    avatar: const Icon(Icons.bolt_rounded, size: 16, color: AppColors.primary),
                    label: const Text('Use demo stall ($_demoPhone)'),
                    labelStyle: theme.textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    side: BorderSide.none,
                    onPressed: () => setState(() => _phoneCtr.text = _demoPhone),
                  ),
                ),
              ],
              if (codeStep) ...[
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _codeCtr,
                  autofocus: !_devFilled,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 10, color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: '6-digit code',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(color: AppColors.grey500, letterSpacing: 0),
                    helperText: _devFilled ? 'Development server: code filled in for you' : 'Sent to +91 $_codeSentTo',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  onChanged: (_) => setState(() {}),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _codeSentTo = null;
                      _codeCtr.clear();
                      _devFilled = false;
                    }),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Change number'),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              BlocBuilder<AuthCubit, AuthState>(
                builder: (context, state) {
                  final loading = state is AuthLoading;
                  final enabled = !loading &&
                      (codeStep ? _codeCtr.text.trim().length == 6 : _phoneCtr.text.trim().length == 10);
                  return SizedBox(
                    height: AppSpacing.ctaHeight,
                    child: ElevatedButton(
                      onPressed: enabled ? (codeStep ? _verify : _sendCode) : null,
                      child: loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                          : Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(codeStep ? AppStrings.startMyDay : 'Send code', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Icon(codeStep ? Icons.storefront_rounded : Icons.arrow_forward_rounded, size: 18),
                            ]),
                    ),
                  );
                },
              ),
            ]),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text('Use the phone number registered for your stall', textAlign: TextAlign.center, style: theme.textTheme.labelSmall),
          ),
        ]),
        const SizedBox(height: AppSpacing.xl),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: 'A product of ', style: theme.textTheme.labelSmall),
            TextSpan(
                text: 'ANCILIENT',
                style: theme.textTheme.labelSmall?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w800, letterSpacing: 2)),
          ]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// "1 Phone — 2 Verify" with the current step highlighted.
  Widget _steps(bool codeStep) {
    Widget dot(int n, String label, bool active, bool done) => Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: active || done ? AppColors.primary : AppColors.grey100),
            child: done
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : Text('$n', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: active ? Colors.white : AppColors.grey500)),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active || done ? AppColors.ink : AppColors.grey500)),
        ]);
    return Row(children: [
      dot(1, 'Phone', !codeStep, codeStep),
      Expanded(
        child: Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: codeStep ? AppColors.primary : AppColors.divider, borderRadius: BorderRadius.circular(2)),
        ),
      ),
      dot(2, 'Verify', codeStep, false),
    ]);
  }

  void _sendCode() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<AuthCubit>().sendOtp(_phoneCtr.text.trim());
  }

  void _verify() {
    FocusScope.of(context).unfocus();
    context.read<AuthCubit>().verifyOtp(phone: _codeSentTo!, code: _codeCtr.text.trim());
  }
}
