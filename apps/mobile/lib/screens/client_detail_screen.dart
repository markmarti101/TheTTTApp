import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../services/client_pricing_service.dart';

class ClientDetailScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  final String clientEmail;
  final String? organisation;

  const ClientDetailScreen({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    this.organisation,
  });

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  final _service = ClientPricingService();

  bool _loading = true;
  ClientPricing? _pricing;
  bool _saving = false;

  final _dayRateController = TextEditingController();
  final _halfDayRateController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _dayRateController.dispose();
    _halfDayRateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final companyId =
        context.read<AuthProvider>().trainingCompanyId ?? '';
    setState(() => _loading = true);
    try {
      final pricing = await _service.getPricing(companyId, widget.clientId);
      if (mounted) {
        setState(() {
          _pricing = pricing;
          _dayRateController.text =
              pricing?.dayRate != null
                  ? pricing!.dayRate!.toStringAsFixed(0)
                  : '';
          _halfDayRateController.text =
              pricing?.halfDayRate != null
                  ? pricing!.halfDayRate!.toStringAsFixed(0)
                  : '';
          _notesController.text = pricing?.notes ?? '';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final companyId =
        context.read<AuthProvider>().trainingCompanyId ?? '';
    final dayText = _dayRateController.text.trim();
    final halfText = _halfDayRateController.text.trim();
    final notes = _notesController.text.trim();

    setState(() => _saving = true);
    try {
      await _service.setPricing(
        companyId,
        widget.clientId,
        dayRate: dayText.isNotEmpty ? double.tryParse(dayText) : null,
        halfDayRate: halfText.isNotEmpty ? double.tryParse(halfText) : null,
        notes: notes.isNotEmpty ? notes : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pricing saved.')),
        );
        await _load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save pricing.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _initials {
    final parts = widget.clientName
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts.isNotEmpty && parts[0].length >= 2) {
      return parts[0].substring(0, 2).toUpperCase();
    }
    return widget.clientName.isNotEmpty
        ? widget.clientName[0].toUpperCase()
        : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: const Text('Client Profile'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildClientHeader(),
                  const SizedBox(height: 16),
                  _buildPricingCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildClientHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              _initials,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.clientName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(widget.clientEmail,
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                if (widget.organisation != null &&
                    widget.organisation!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(widget.organisation!,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Client',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Custom Pricing',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
                letterSpacing: 0.3),
          ),
          const SizedBox(height: 4),
          Text(
            'Set client-specific rates that override standard pricing.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          _buildField(
            label: 'Day Rate (£)',
            controller: _dayRateController,
            hint: 'e.g. 1200',
            keyboardType: TextInputType.number,
            icon: Icons.currency_pound,
          ),
          const SizedBox(height: 12),
          _buildField(
            label: 'Half-Day Rate (£)',
            controller: _halfDayRateController,
            hint: 'e.g. 700',
            keyboardType: TextInputType.number,
            icon: Icons.currency_pound_outlined,
          ),
          const SizedBox(height: 12),
          _buildField(
            label: 'Notes',
            controller: _notesController,
            hint: 'e.g. Includes travel expenses',
            keyboardType: TextInputType.text,
            icon: Icons.notes_outlined,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Pricing',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          if (_pricing != null &&
              (_pricing!.dayRate != null ||
                  _pricing!.halfDayRate != null)) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  _buildPricingSummary(),
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _buildPricingSummary() {
    final parts = <String>[];
    if (_pricing?.dayRate != null) {
      parts.add('Day: £${_pricing!.dayRate!.toStringAsFixed(0)}');
    }
    if (_pricing?.halfDayRate != null) {
      parts.add('Half-day: £${_pricing!.halfDayRate!.toStringAsFixed(0)}');
    }
    return parts.join(' · ');
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required TextInputType keyboardType,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
            prefixIcon:
                Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      );
}
