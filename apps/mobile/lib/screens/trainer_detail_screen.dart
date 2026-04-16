import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../services/trainer_profile_service.dart';

class TrainerDetailScreen extends StatefulWidget {
  final String trainerId;
  final String trainerName;
  final String trainerEmail;

  const TrainerDetailScreen({
    super.key,
    required this.trainerId,
    required this.trainerName,
    required this.trainerEmail,
  });

  @override
  State<TrainerDetailScreen> createState() => _TrainerDetailScreenState();
}

class _TrainerDetailScreenState extends State<TrainerDetailScreen> {
  final _service = TrainerProfileService();

  bool _loading = true;
  List<TrainerQualification> _qualifications = [];
  ComplianceData _compliance = ComplianceData();
  TrainerRate? _rate;
  bool _savingRate = false;

  final _dayRateController = TextEditingController();
  final _contractUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _dayRateController.dispose();
    _contractUrlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final companyId =
        context.read<AuthProvider>().trainingCompanyId ?? '';
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _service.getQualifications(widget.trainerId),
        _service.getTrainerRate(companyId, widget.trainerId),
        _service.getCompliance(widget.trainerId),
      ]);
      final quals = results[0] as List<TrainerQualification>;
      final rate = results[1] as TrainerRate?;
      final compliance = results[2] as ComplianceData;
      if (mounted) {
        setState(() {
          _qualifications = quals;
          _compliance = compliance;
          _rate = rate;
          _dayRateController.text =
              rate?.dayRate != null ? rate!.dayRate!.toStringAsFixed(0) : '';
          _contractUrlController.text = rate?.contractUrl ?? '';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveRate() async {
    final companyId =
        context.read<AuthProvider>().trainingCompanyId ?? '';
    final rateText = _dayRateController.text.trim();
    final contractUrl = _contractUrlController.text.trim();

    setState(() => _savingRate = true);
    try {
      await _service.setTrainerRate(
        companyId,
        widget.trainerId,
        dayRate: rateText.isNotEmpty ? double.tryParse(rateText) : null,
        contractUrl: contractUrl.isNotEmpty ? contractUrl : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rate saved.')),
        );
        await _load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save rate.')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingRate = false);
    }
  }

  String get _initials {
    final parts = widget.trainerName
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
    return widget.trainerName.isNotEmpty
        ? widget.trainerName[0].toUpperCase()
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
        title: const Text('Trainer Profile'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTrainerHeader(),
                  const SizedBox(height: 16),
                  _buildRateCard(),
                  const SizedBox(height: 16),
                  _buildQualificationsCard(),
                  const SizedBox(height: 16),
                  _buildComplianceCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildTrainerHeader() {
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
                Text(widget.trainerName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(widget.trainerEmail,
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Freelance Trainer',
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

  Widget _buildRateCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rate & Contract',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
                letterSpacing: 0.3),
          ),
          const SizedBox(height: 14),
          _buildField(
            label: 'Day Rate (£)',
            controller: _dayRateController,
            hint: 'e.g. 350',
            keyboardType: TextInputType.number,
            icon: Icons.currency_pound,
          ),
          const SizedBox(height: 12),
          _buildField(
            label: 'Contract URL',
            controller: _contractUrlController,
            hint: 'https://docs.google.com/...',
            keyboardType: TextInputType.url,
            icon: Icons.link_outlined,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _savingRate ? null : _saveRate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _savingRate
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          if (_rate?.contractUrl != null &&
              _rate!.contractUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                const Text('Contract attached',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQualificationsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Qualifications & Expiry Dates',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
                letterSpacing: 0.3),
          ),
          const SizedBox(height: 12),
          if (_qualifications.isEmpty)
            const Text(
              'No qualifications uploaded by this trainer yet.',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            )
          else
            ..._qualifications.map(_buildQualTile),
        ],
      ),
    );
  }

  Widget _buildQualTile(TrainerQualification q) {
    final expiry = DateTime.tryParse(q.expiryDate);
    final now = DateTime.now();
    final isExpired = expiry != null && expiry.isBefore(now);
    final isExpiringSoon = expiry != null &&
        !isExpired &&
        expiry.isBefore(now.add(const Duration(days: 60)));

    final bgColor = isExpired
        ? const Color(0xFFFFF1F2)
        : isExpiringSoon
            ? const Color(0xFFFFFBEB)
            : const Color(0xFFF8FAFC);
    final borderColor = isExpired
        ? const Color(0xFFFECACA)
        : isExpiringSoon
            ? const Color(0xFFFDE68A)
            : const Color(0xFFE2E8F0);
    final iconColor = isExpired
        ? const Color(0xFFDC2626)
        : isExpiringSoon
            ? const Color(0xFFD97706)
            : AppColors.primary;
    final dateColor = isExpired
        ? const Color(0xFFDC2626)
        : isExpiringSoon
            ? const Color(0xFFD97706)
            : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_outlined, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111111))),
                if (q.issuer != null && q.issuer!.isNotEmpty)
                  Text(q.issuer!,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDate(q.expiryDate),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: dateColor),
              ),
              if (isExpired)
                const Text('EXPIRED',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFDC2626),
                        letterSpacing: 0.5))
              else if (isExpiringSoon)
                const Text('EXPIRING SOON',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFD97706),
                        letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceCard() {
    final dbs = _compliance.dbs;
    final ins = _compliance.insurance;
    final now = DateTime.now();

    bool isExp(String? iso) {
      if (iso == null || iso.isEmpty) return false;
      final dt = DateTime.tryParse(iso);
      return dt != null && dt.isBefore(now);
    }

    bool isSoon(String? iso) {
      if (iso == null || iso.isEmpty) return false;
      final dt = DateTime.tryParse(iso);
      if (dt == null) return false;
      return !dt.isBefore(now) &&
          dt.isBefore(now.add(const Duration(days: 60)));
    }

    Color statusColor(String? iso) => isExp(iso)
        ? const Color(0xFFDC2626)
        : isSoon(iso)
            ? const Color(0xFFD97706)
            : AppColors.primary;

    Widget compRow({
      required IconData icon,
      required String label,
      required String value,
      required String? expiryDate,
    }) {
      final expired = isExp(expiryDate);
      final soon = isSoon(expiryDate);
      final color = statusColor(expiryDate);
      return Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569))),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111111))),
                if (expiryDate != null && expiryDate.isNotEmpty)
                  Text(
                    '${expired ? 'Expired' : 'Expires'}: ${_formatDate(expiryDate)}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color),
                  ),
              ],
            ),
          ),
          if (expired)
            _badge('EXPIRED', const Color(0xFFFEE2E2),
                const Color(0xFFDC2626))
          else if (soon)
            _badge('SOON', const Color(0xFFFEF3C7),
                const Color(0xFFD97706)),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Compliance',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
                letterSpacing: 0.3),
          ),
          const SizedBox(height: 14),
          compRow(
            icon: Icons.security_outlined,
            label: 'DBS Certificate',
            value: dbs?.certificateNumber?.isNotEmpty == true
                ? dbs!.certificateNumber!
                : (dbs != null ? 'Recorded' : 'Not provided'),
            expiryDate: dbs?.expiryDate,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFF0F0F0)),
          ),
          compRow(
            icon: Icons.policy_outlined,
            label: 'Insurance',
            value: ins?.provider?.isNotEmpty == true
                ? ins!.provider!
                : (ins != null ? 'Recorded' : 'Not provided'),
            expiryDate: ins?.expiryDate,
          ),
          if (_compliance.cpd.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: Color(0xFFF0F0F0)),
            ),
            const Text(
              'CPD Log',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569)),
            ),
            const SizedBox(height: 8),
            ..._compliance.cpd.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.school_outlined,
                          size: 15, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.title +
                              (e.provider != null
                                  ? ' · ${e.provider}'
                                  : '') +
                              (e.hours != null
                                  ? ' · ${e.hours}h'
                                  : ''),
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF334155)),
                        ),
                      ),
                      Text(
                        _formatDate(e.completedDate),
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w800, color: fg),
        ),
      );

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

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    const m = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }
}
