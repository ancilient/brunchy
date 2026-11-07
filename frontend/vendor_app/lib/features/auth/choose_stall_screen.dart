import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../injection_container.dart';
import '../../services/local_storage_service.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/stall.dart';
import 'choose_stall_cubit.dart';
import 'choose_stall_state.dart';

class ChooseStallScreen extends StatefulWidget {
  const ChooseStallScreen({super.key});
  @override State<ChooseStallScreen> createState() => _ChooseStallScreenState();
}

class _ChooseStallScreenState extends State<ChooseStallScreen> {
  String? _canteenId;
  bool _hasExistingSession = false;

  @override
  void initState() {
    super.initState();
    final storage = sl<LocalStorageService>();
    final vendor = storage.getVendor();
    _canteenId = vendor?.canteenId ?? 'main_canteen';
    _hasExistingSession = storage.getStallId(DateFormatter.todayKey()) != null;
    context.read<ChooseStallCubit>().loadStalls(_canteenId!);
  }

  @override
  Widget build(BuildContext context) {
    final vendor = sl<LocalStorageService>().getVendor();
    return BlocListener<ChooseStallCubit, ChooseStallState>(
      listener: (context, state) {
        if (state is StallSelected) {
          context.go('/home/orders');
        } else if (state is StallClaimConflict) {
          _showConflictDialog(context, state);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Image.asset('assets/images/logo_horizontal.png', height: 32),
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Good morning, ${vendor?.name ?? 'Vendor'} 👋',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text('Choose your stall to start the day', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.lg),
              Expanded(child: BlocBuilder<ChooseStallCubit, ChooseStallState>(
                builder: (context, state) {
                  if (state is ChooseStallLoading) return _buildSkeleton();
                  if (state is ChooseStallEmpty) return _buildEmpty();
                  if (state is ChooseStallError) return _buildError(context, state.message);
                  if (state is ChooseStallLoaded || state is StallClaimConflict) {
                    final stalls = state is ChooseStallLoaded ? state.stalls : <Stall>[];
                    return GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, childAspectRatio: 1.5, crossAxisSpacing: AppSpacing.md, mainAxisSpacing: AppSpacing.md,
                      ),
                      itemCount: stalls.length,
                      itemBuilder: (_, i) {
                        final stall = stalls[i];
                        return _StallCard(
                          emoji: stall.iconEmoji, name: stall.name,
                          onTap: () => context.read<ChooseStallCubit>().selectStall(stall.id),
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              )),
              if (_hasExistingSession) ...[
                const SizedBox(height: AppSpacing.md),
                TextButton.icon(
                  icon: const Icon(Icons.swap_horiz, color: AppColors.primaryOrange),
                  label: const Text(AppStrings.switchStall, style: TextStyle(color: AppColors.primaryOrange)),
                  onPressed: () async {
                    await sl<LocalStorageService>().clearStallSession(DateFormatter.todayKey());
                    setState(() => _hasExistingSession = false);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() => GridView.builder(
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.5, crossAxisSpacing: AppSpacing.md, mainAxisSpacing: AppSpacing.md),
    itemCount: 6,
    itemBuilder: (_, __) => Shimmer.fromColors(
      baseColor: AppColors.divider, highlightColor: Colors.white,
      child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppSpacing.radiusMd))),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.storefront_outlined, size: 64, color: AppColors.textSecondary),
      const SizedBox(height: AppSpacing.md),
      Text('No stalls configured', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.xs),
      Text('Contact your admin', style: Theme.of(context).textTheme.bodyMedium),
    ]),
  );

  Widget _buildError(BuildContext context, String msg) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.wifi_off, size: 64, color: AppColors.errorRed),
      const SizedBox(height: AppSpacing.md),
      Text(msg, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
      const SizedBox(height: AppSpacing.md),
      ElevatedButton(
        onPressed: () => context.read<ChooseStallCubit>().loadStalls(_canteenId!),
        child: const Text(AppStrings.retryButton),
      ),
    ]),
  );

  void _showConflictDialog(BuildContext context, StallClaimConflict state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Stall Already Open'),
        content: Text('This stall is open on another device (${state.claimedBy}). Take over?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ChooseStallCubit>().selectStall(state.stallId, forceTakeover: true);
            },
            child: const Text('Take Over'),
          ),
        ],
      ),
    );
  }
}

class _StallCard extends StatelessWidget {
  final String emoji, name;
  final VoidCallback onTap;
  const _StallCard({required this.emoji, required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: AppSpacing.sm),
          Text(name, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

