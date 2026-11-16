// lib/features/auth/login_screen.dart
// Sign in with Google. Each stall has one registered Google account (one account per stall, blueprint 5.4),
// so the stall comes from the server and there is nothing to pick here.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/errors/app_exception.dart';
import 'auth_cubit.dart';
import 'auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  ({bool google, String? googleClientId, bool devLogin})? _options;
  String? _optionsError;
  bool _loadingOptions = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOptions());
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loadingOptions = true;
      _optionsError = null;
    });
    try {
      final o = await context.read<AuthCubit>().loadLoginOptions();
      if (mounted) setState(() => _options = o);
    } on AppException catch (e) {
      if (mounted) setState(() => _optionsError = e.message);
    } catch (_) {
      if (mounted) setState(() => _optionsError = 'Cannot reach Brunchy. Check your internet and try again.');
    } finally {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  void _google() {
    final clientId = _options?.googleClientId;
    if (_options?.google != true || clientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Google sign-in is not set up on the server yet. Use the development login for now.'),
      ));
      return;
    }
    context.read<AuthCubit>().signInWithGoogle(clientId);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthSuccess) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),
                Center(child: Image.asset('assets/images/logo_horizontal.png', height: 54)),
                const SizedBox(height: AppSpacing.lg),
                Text('Welcome!', style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: AppSpacing.xs),
                Text('Sign in with your stall\'s Google account', style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.xl),
                if (_loadingOptions)
                  const Center(child: CircularProgressIndicator())
                else if (_optionsError != null) ...[
                  Text(_optionsError!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(width: double.infinity, height: 52, child: ElevatedButton(onPressed: _loadOptions, child: const Text('Try again'))),
                ] else
                  BlocBuilder<AuthCubit, AuthState>(
                    builder: (context, state) {
                      final loading = state is AuthLoading;
                      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: AppColors.divider, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                            ),
                            onPressed: loading ? null : _google,
                            child: loading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF4285F4))),
                                    SizedBox(width: 12),
                                    Text('Sign in with Google',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                                  ]),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Use the Google account registered for your stall. Ask the canteen manager if yours is not added.',
                            style: TextStyle(fontSize: 12, color: AppColors.grey600)),
                        if (_options?.devLogin == true) ...[
                          const SizedBox(height: AppSpacing.lg),
                          SizedBox(
                            height: 48,
                            child: TextButton(
                              onPressed: loading ? null : () => context.read<AuthCubit>().devLogin(),
                              child: const Text('Continue as demo vendor (Burger Hub) · development only'),
                            ),
                          ),
                        ],
                      ]);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
