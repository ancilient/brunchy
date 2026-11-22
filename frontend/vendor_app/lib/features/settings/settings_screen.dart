// lib/features/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/date_formatter.dart';
import '../../injection_container.dart';
import '../../services/audio_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/tts_service.dart';
import '../auth/auth_cubit.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/app_dialog.dart';

/// The vendor's contact line: Google accounts store an email here (shown as is); a 10-digit Indian mobile
/// number gets +91. Anything else is shown unchanged.
String contactLabel(String raw) {
  final v = raw.trim();
  if (RegExp(r'^[6-9]\d{9}$').hasMatch(v)) return '+91 $v';
  return v;
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storage = sl<LocalStorageService>();
    final vendor = storage.getVendor();
    final today = DateFormatter.todayKey();
    // The chosen stall's name (saved with it on Choose Stall); its id meant nothing to vendors.
    final stallLabel = storage.getStallId(today) != null ? (storage.getStallName() ?? 'Selected') : 'None selected';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings & Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Vendor profile card
          Card(
            elevation: 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              side: const BorderSide(color: AppColors.grey200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: const Icon(Icons.person, color: AppColors.primary, size: 32),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vendor?.name ?? 'Vendor Partner',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vendor != null ? contactLabel(vendor.phone) : 'Not logged in',
                          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.grey600),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.brandTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Active Stall: $stallLabel',
                            style: const TextStyle(fontSize: 11, color: AppColors.brandTeal, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Operational Settings
          Card(
            elevation: 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              side: const BorderSide(color: AppColors.grey200),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.storefront_outlined, color: AppColors.ink),
                  title: const Text('Change Active Stall'),
                  subtitle: const Text('Select a different counter or stall for today'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    context.push('/choose-stall');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.volume_up_outlined, color: AppColors.primary),
                  title: const Text('Test Order Alert & Voice'),
                  subtitle: const Text('Plays chime & voice alert for hands-free kitchen notice'),
                  trailing: const Icon(Icons.play_circle_outline, color: AppColors.primary),
                  onTap: () async {
                    await sl<AudioService>().playNewOrder();
                    await sl<TtsService>().announceNewOrders(1);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Chime & Voice alert played.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.location_city_outlined, color: AppColors.ink),
                  title: const Text('Switch Canteen Location'),
                  subtitle: Text('Current: ${storage.getCanteenName()}'),
                  trailing: const Icon(Icons.swap_horiz),
                  // Real canteen list from the server, then that canteen's stalls.
                  onTap: () => context.push('/choose-canteen'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Danger zone / Log out
          Card(
            elevation: 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              side: const BorderSide(color: AppColors.grey200),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.power_settings_new, color: AppColors.errorRed),
                  title: const Text('Log Out', style: TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Sign out of your account on this device'),
                  onTap: () => _confirmLogout(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Branding & Version
          Center(
            child: Column(
              children: [
                const BrandLockup(height: 32),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Brunchy Vendor • v1.0.0+1',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.grey500),
                ),
                const SizedBox(height: 2),
                Text(
                  'Built for fast, effortless stall management',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.grey400, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final storage = sl<LocalStorageService>();
    final hasOffline = storage.hasPendingOfflineActions;
    final queueCount = storage.getOfflineQueue().length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: Text(hasOffline ? '⚠ Unsynced Offline Actions' : 'Log Out?'),
        content: Text(hasOffline
            ? 'You have $queueCount pending action(s) waiting to sync with the server. Logging out now will discard these actions.\n\nAre you sure you want to log out?'
            : 'Are you sure you want to log out of Brunchy Vendor? You will need to sign in again to access this stall.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await storage.clearSession();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }
}
