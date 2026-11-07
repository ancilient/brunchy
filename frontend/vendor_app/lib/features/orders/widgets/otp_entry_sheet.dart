import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../data/models/order.dart';
import '../../handover/handover_result.dart';
import '../../handover/handover_service.dart';

class OtpEntrySheet extends StatefulWidget {
  final Order order;
  final String stallId;
  final HandoverService handoverService;
  final ValueChanged<HandoverResult> onSuccess;
  const OtpEntrySheet({super.key, required this.order, required this.stallId, required this.handoverService, required this.onSuccess});
  @override State<OtpEntrySheet> createState() => _OtpEntrySheetState();
}
class _OtpEntrySheetState extends State<OtpEntrySheet> {
  final _controllers = List.generate(3, (_) => TextEditingController());
  final _nodes = List.generate(3, (_) => FocusNode());
  bool _isSubmitting = false;
  String? _error;
  @override void dispose() { for (final c in _controllers) { c.dispose(); } for (final n in _nodes) { n.dispose(); } super.dispose(); }
  void _clear() { for (final c in _controllers) { c.clear(); } _nodes.first.requestFocus(); }
  Future<void> _submit() async {
    if (_isSubmitting) return;
    final code = _controllers.map((c) => c.text).join();
    if (code.length != 3) return;
    setState(() { _isSubmitting = true; _error = null; });
    final result = await widget.handoverService.handOver(stallId: widget.stallId, order: widget.order, code: code);
    if (!mounted) return;
    if (result.isSuccess || result.outcome == HandoverOutcome.offlineQueued) { widget.onSuccess(result); return; }
    setState(() { _isSubmitting = false; _error = result.message; });
    _clear();
  }
  void _changed(int index, String value) { if (value.isNotEmpty && index < 2) _nodes[index + 1].requestFocus(); if (index == 2 && value.isNotEmpty) _submit(); }
  @override Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Expanded(child: Text('Enter 3-Digit Counter Code', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))), IconButton(onPressed: _isSubmitting ? null : () => Navigator.pop(context), icon: const Icon(Icons.close))]),
        Text('Order #${widget.order.counterCode} • ${widget.order.studentFirstName}'),
        const SizedBox(height: AppSpacing.lg),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: SizedBox(width: 64, height: 64, child: TextField(controller: _controllers[i], focusNode: _nodes[i], enabled: !_isSubmitting, autofocus: i == 0, textAlign: TextAlign.center, keyboardType: TextInputType.number, maxLength: 1, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold), decoration: const InputDecoration(counterText: '', border: OutlineInputBorder()), onChanged: (v) => _changed(i, v)))))),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: AppSpacing.md), child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.errorRed, fontWeight: FontWeight.w600))),
        const SizedBox(height: AppSpacing.md),
        ElevatedButton(onPressed: _isSubmitting ? null : _submit, child: _isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator()) : const Text('Hand Over')),
      ])),
    ),
  );
}
