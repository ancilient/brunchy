// lib/features/handover/handover_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/order.dart';
import '../../data/models/order_status.dart';
import '../../data/repositories/order_repository.dart';
import '../../injection_container.dart';
import '../../services/local_storage_service.dart';
import '../orders/orders_cubit.dart';
import 'handover_service.dart';

enum HandoverBannerState {
  idle,
  validReady,
  notReadyYet,
  alreadyCollected,
  notFound,
  cancelledOrRefunded,
}

class HandoverScreen extends StatefulWidget {
  final String? initialCode;
  const HandoverScreen({super.key, this.initialCode});

  @override
  State<HandoverScreen> createState() => _HandoverScreenState();
}

class _HandoverScreenState extends State<HandoverScreen> {
  String _code = '';
  Order? _matchedOrder;
  HandoverBannerState _bannerState = HandoverBannerState.idle;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _code = widget.initialCode!.trim();
      if (_code.length == 3) {
        _lookupCode(_code);
      }
    }
  }

  void _onKeyPress(String key) {
    if (_isSubmitting) return;
    if (_code.length < 3) {
      setState(() {
        _code += key;
      });
      if (_code.length == 3) {
        _lookupCode(_code);
      }
    }
  }

  void _onBackspace() {
    if (_isSubmitting) return;
    if (_code.isNotEmpty) {
      setState(() {
        _code = _code.substring(0, _code.length - 1);
        _matchedOrder = null;
        _bannerState = HandoverBannerState.idle;
        _statusMessage = '';
      });
    }
  }

  void _onClear() {
    if (_isSubmitting) return;
    setState(() {
      _code = '';
      _matchedOrder = null;
      _bannerState = HandoverBannerState.idle;
      _statusMessage = '';
    });
  }

  void _resetAfterSuccess() {
    setState(() {
      _code = '';
      _matchedOrder = null;
      _bannerState = HandoverBannerState.idle;
      _statusMessage = '';
    });
  }

  void _showResultError(String message) {
    setState(() {
      _code = '';
      _matchedOrder = null;
      _bannerState = HandoverBannerState.notFound;
      _statusMessage = message;
    });
  }

  Future<void> _lookupCode(String code) async {
    setState(() {
      _isLoading = true;
      _matchedOrder = null;
    });

    try {
      final orderRepo = sl<OrderRepository>();
      final stallId =
          sl<LocalStorageService>().getStallIdDirect() ?? 'stall_001';
      final order =
          await orderRepo.findOrderByCounterCode(stallId: stallId, code: code);

      if (!mounted) return;

      if (order == null) {
        setState(() {
          _isLoading = false;
          _bannerState = HandoverBannerState.notFound;
          _statusMessage = 'No order found with code #$code';
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _matchedOrder = order;
      });

      if (order.status == OrderStatus.collected || order.isCodeUsed) {
        final timeStr =
            DateFormatter.displayTime(order.collectedAt ?? DateTime.now());
        setState(() {
          _bannerState = HandoverBannerState.alreadyCollected;
          _statusMessage = 'Already collected at $timeStr';
        });
      } else if (order.status == OrderStatus.cancelled ||
          order.status == OrderStatus.refunded) {
        setState(() {
          _bannerState = HandoverBannerState.cancelledOrRefunded;
          _statusMessage = 'Order has been cancelled / refunded';
        });
      } else if (order.status == OrderStatus.ready) {
        setState(() {
          _bannerState = HandoverBannerState.validReady;
          _statusMessage = 'Valid order • Ready for handover';
        });
      } else {
        setState(() {
          _bannerState = HandoverBannerState.notReadyYet;
          _statusMessage = 'Not ready yet • Food is still being prepared';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _bannerState = HandoverBannerState.notFound;
        _statusMessage = 'Error looking up code: $e';
      });
    }
  }

  Future<void> _performHandover() async {
    if (_matchedOrder == null ||
        _bannerState != HandoverBannerState.validReady ||
        _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    final order = _matchedOrder!;

    try {
      final stallId =
          sl<LocalStorageService>().getStallIdDirect() ?? order.stallId;
      final result = await HandoverService(sl<OrderRepository>()).handOver(
          stallId: stallId, order: order, code: _code);
      if (!mounted) return;
      if (!result.isSuccess) { _showResultError(result.message); return; }
      await context.read<OrdersCubit>().markCollected(order.id);
      if (!mounted) return;
      _resetAfterSuccess();
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 300),
        content: Text('Order #${order.billNumber} handed over to ${order.studentFirstName}'), backgroundColor: AppColors.successGreen));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - AppSpacing.md),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: Text(
                          '3-Digit Counter Handover',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.brandBrown,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Text(
                        'Ask student for their 3-digit order code',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.grey600,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // 3-digit boxes
                      _buildCodeDisplayBoxes(),
                      const SizedBox(height: AppSpacing.sm),

                      // Status Banner
                      if (_isLoading)
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.primaryOrange)),
                        )
                      else if (_bannerState != HandoverBannerState.idle)
                        _buildStatusBanner(),

                      // Matched Order Card
                      if (_matchedOrder != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _buildMatchedOrderCard(_matchedOrder!),
                      ],

                      // Hand over action button
                      const SizedBox(height: AppSpacing.sm),
                      _buildHandoverButton(),

                      const Spacer(),
                      const SizedBox(height: AppSpacing.sm),

                      // Numeric Keypad
                      _buildNumericKeypad(constraints.maxHeight),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCodeDisplayBoxes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final char = index < _code.length ? _code[index] : '';
        final isCurrent = index == _code.length;
        return Container(
          width: 64,
          height: 64,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: isCurrent
                  ? AppColors.primaryOrange
                  : (char.isNotEmpty
                      ? AppColors.brandBrown
                      : AppColors.grey300),
              width: isCurrent ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              char,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.brandBrown,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStatusBanner() {
    Color bg;
    Color fg;
    IconData icon;

    switch (_bannerState) {
      case HandoverBannerState.validReady:
        bg = AppColors.successGreen.withValues(alpha: 0.12);
        fg = AppColors.successGreen;
        icon = Icons.check_circle;
      case HandoverBannerState.notReadyYet:
        bg = AppColors.warningAmber.withValues(alpha: 0.15);
        fg = AppColors.warningAmber;
        icon = Icons.hourglass_top;
      case HandoverBannerState.alreadyCollected:
        bg = AppColors.grey200;
        fg = AppColors.grey700;
        icon = Icons.assignment_turned_in;
      case HandoverBannerState.notFound:
      case HandoverBannerState.cancelledOrRefunded:
        bg = AppColors.errorRed.withValues(alpha: 0.12);
        fg = AppColors.errorRed;
        icon = Icons.cancel;
      case HandoverBannerState.idle:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm, horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _statusMessage,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchedOrderCard(Order order) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Code badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#${order.counterCode}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Student Name
                Expanded(
                  child: Text(
                    order.studentFirstName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandBrown,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Paid badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'PAID',
                    style: TextStyle(
                      color: AppColors.successGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            // Items
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      Text(
                        '${item.quantity}×',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryOrange,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.brandBrown,
                          ),
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(item.subtotal),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.grey700,
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Placed at ${DateFormatter.displayTime(order.placedAt)}',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.grey500),
                ),
                Text(
                  'Total: ${CurrencyFormatter.format(order.totalAmount)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandoverButton() {
    final isReady =
        _bannerState == HandoverBannerState.validReady && !_isSubmitting;
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isReady ? AppColors.successGreen : AppColors.grey300,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          elevation: isReady ? 2 : 0,
        ),
        onPressed: isReady ? _performHandover : null,
        child: _isSubmitting
            ? const CircularProgressIndicator(color: Colors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    isReady
                        ? 'Hand Over Order'
                        : 'Enter 3-Digit Code to Hand Over',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildNumericKeypad(double availableHeight) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '⌫'],
    ];

    final keyHeight = ((availableHeight - 370) / 4).clamp(48.0, 52.0);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Column(
        children: keys.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3.0),
            child: Row(
              children: row.map((key) {
                final isSpecial = key == 'C' || key == '⌫';
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: SizedBox(
                      height: keyHeight,
                      child: Material(
                        color:
                            isSpecial ? AppColors.grey200 : AppColors.cardWhite,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        elevation: 1,
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                          onTap: () {
                            if (key == 'C') {
                              _onClear();
                            } else if (key == '⌫') {
                              _onBackspace();
                            } else {
                              _onKeyPress(key);
                            }
                          },
                          child: Center(
                            child: Text(
                              key,
                              style: TextStyle(
                                fontSize: isSpecial ? 20 : 24,
                                fontWeight: FontWeight.bold,
                                color: key == 'C'
                                    ? AppColors.errorRed
                                    : (key == '⌫'
                                        ? AppColors.brandBrown
                                        : AppColors.brandBrown),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}
