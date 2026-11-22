import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../injection_container.dart';
import '../../services/local_storage_service.dart';
import '../../data/models/stall.dart';
import '../../data/models/canteen.dart';
import '../../data/repositories/auth_repository.dart';
import '../../services/realtime_service.dart';
import 'choose_stall_cubit.dart';
import 'choose_stall_state.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/app_dialog.dart';

/// "Good morning" before 12:00, "Good afternoon" until 17:00, then "Good evening" (phone's local time).
String greetingFor(DateTime now) => now.hour < 12
    ? AppStrings.goodMorning
    : now.hour < 17
        ? AppStrings.goodAfternoon
        : AppStrings.goodEvening;

class ChooseStallScreen extends StatefulWidget {
  const ChooseStallScreen({super.key});
  @override State<ChooseStallScreen> createState() => _ChooseStallScreenState();
}

class _ChooseStallScreenState extends State<ChooseStallScreen> {
  String? _canteenId;

  @override
  void initState() {
    super.initState();
    final storage = sl<LocalStorageService>();
    final vendor = storage.getVendor();
    // The canteen picked on Choose Canteen (saved there); the account's canteen otherwise.
    _canteenId = storage.getCanteenId() ?? vendor?.canteenId ?? 'main_canteen';
    context.read<ChooseStallCubit>().loadStalls(_canteenId!);
  }

  @override
  Widget build(BuildContext context) {
    final vendor = sl<LocalStorageService>().getVendor();
    return BlocListener<ChooseStallCubit, ChooseStallState>(
      listener: (context, state) async {
        if (state is StallSelected) {
          await sl<LocalStorageService>().saveStallInfo(state.stall.id, state.stall.name);
          // The live order socket was opened with the previous stall's token: reconnect on the new one.
          await sl<RealtimeService>().disconnect();
          if (context.mounted) context.go('/home/orders');
        } else if (state is StallClaimConflict) {
          _showConflictDialog(context, state);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const BrandLockup(height: 32),
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${greetingFor(DateTime.now())}, ${vendor?.name ?? 'Vendor'} 👋',
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
              // Always offered (also on the empty "No stalls configured" list): pick a different canteen.
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                label: const Text(AppStrings.chooseAnotherCanteen, style: TextStyle(color: AppColors.primary)),
                onPressed: () => _backToCanteens(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Back to Choose Canteen: pop when it is the screen underneath (normal flow), otherwise open it (e.g. from
  /// Settings > Change Active Stall), keeping the screen we came from on the back stack.
  void _backToCanteens(BuildContext context) {
    final matches = GoRouter.of(context).routerDelegate.currentConfiguration.matches;
    final below = matches.length >= 2 ? matches[matches.length - 2].matchedLocation : null;
    if (below == '/choose-canteen' && context.canPop()) {
      context.pop();
    } else {
      context.push('/choose-canteen');
    }
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
      builder: (_) => AppDialog(
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

/// First step after login: pick the canteen, then its stall (Choose Stall). Same look as Choose Stall.
class ChooseCanteenScreen extends StatefulWidget {
  const ChooseCanteenScreen({super.key});
  @override State<ChooseCanteenScreen> createState() => _ChooseCanteenScreenState();
}

class _ChooseCanteenScreenState extends State<ChooseCanteenScreen> {
  late Future<List<Canteen>> _canteens = sl<AuthRepository>().getCanteens(); // [API-002] GET /canteens

  @override
  Widget build(BuildContext context) {
    final vendor = sl<LocalStorageService>().getVendor();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const BrandLockup(height: 32),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${greetingFor(DateTime.now())}, ${vendor?.name ?? 'Vendor'} 👋',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text('Choose your canteen', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            Expanded(child: FutureBuilder<List<Canteen>>(
              future: _canteens,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return Shimmer.fromColors(
                    baseColor: AppColors.divider, highlightColor: Colors.white,
                    child: Container(height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppSpacing.radiusMd))),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.wifi_off, size: 64, color: AppColors.errorRed),
                      const SizedBox(height: AppSpacing.md),
                      Text('Failed to load canteens. Please try again.', style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton(
                        onPressed: () => setState(() => _canteens = sl<AuthRepository>().getCanteens()),
                        child: const Text(AppStrings.retryButton),
                      ),
                    ]),
                  );
                }
                final canteens = snap.data ?? const <Canteen>[];
                if (canteens.isEmpty) {
                  return Center(child: Text('No canteens configured', style: Theme.of(context).textTheme.titleLarge));
                }
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 1.5, crossAxisSpacing: AppSpacing.md, mainAxisSpacing: AppSpacing.md,
                  ),
                  itemCount: canteens.length,
                  itemBuilder: (_, i) => _StallCard(
                    emoji: '🏫', name: canteens[i].name,
                    onTap: () async {
                      await sl<LocalStorageService>().saveCanteenInfo(canteens[i].id, canteens[i].name);
                      if (context.mounted) context.push('/choose-stall');
                    },
                  ),
                );
              },
            )),
          ],
        ),
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

