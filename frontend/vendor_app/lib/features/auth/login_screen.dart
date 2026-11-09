// lib/features/auth/login_screen.dart
// Phone + OTP login. The stall comes from the account on the server (one phone per stall, blueprint 5.4),
// so there is nothing to pick here.
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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  // Pre-filled with the backend's demo Burger Hub vendor (seed data) to make development quick.
  final _phoneCtr = TextEditingController(text: '9000000001');
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
                  Text('Sign in with your stall\'s phone number', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _phoneCtr,
                    enabled: _codeSentTo == null,
                    decoration: const InputDecoration(labelText: 'Stall phone number (10 digits)'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                    validator: Validators.validatePhone,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_codeSentTo != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _codeCtr,
                      autofocus: !_devFilled,
                      decoration: InputDecoration(
                        labelText: '6-digit code sent to $_codeSentTo',
                        helperText: _devFilled ? 'Development server: code filled in for you' : null,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                      onChanged: (_) => setState(() {}),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _codeSentTo = null;
                        _codeCtr.clear();
                        _devFilled = false;
                      }),
                      child: const Text('Change number'),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  BlocBuilder<AuthCubit, AuthState>(
                    builder: (context, state) {
                      final loading = state is AuthLoading;
                      final codeStep = _codeSentTo != null;
                      final enabled = !loading &&
                          (codeStep ? _codeCtr.text.trim().length == 6 : _phoneCtr.text.trim().length == 10);
                      return SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: enabled ? (codeStep ? _verify : _sendCode) : null,
                          child: loading
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : Text(codeStep ? AppStrings.startMyDay : 'Send code',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
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
