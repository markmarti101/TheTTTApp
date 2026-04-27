import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';

class CompanyOnboardingStep2Screen extends StatefulWidget {
  final String companyName;
  final String businessEmail;

  const CompanyOnboardingStep2Screen({
    super.key,
    required this.companyName,
    required this.businessEmail,
  });

  @override
  State<CompanyOnboardingStep2Screen> createState() =>
      _CompanyOnboardingStep2ScreenState();
}

class _CompanyOnboardingStep2ScreenState
    extends State<CompanyOnboardingStep2Screen> {
  final _formKey = GlobalKey<FormState>();
  final _websiteController = TextEditingController();
  final _registrationNumberController = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _websiteController.dispose();
    _registrationNumberController.dispose();
    super.dispose();
  }

  Future<void> _completeSetup() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return;

    setState(() => _saving = true);

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final website = _websiteController.text.trim();
      final reg = _registrationNumberController.text.trim();

      final data = <String, dynamic>{
        'name': widget.companyName,
        'businessEmail': widget.businessEmail,
        if (website.isNotEmpty) 'website': website,
        if (reg.isNotEmpty) 'registrationNumber': reg,
        'ownerId': uid,
        'admins': [uid],
        'createdAt': now,
        'updatedAt': now,
      };

      final docRef = await FirebaseFirestore.instance
          .collection('training_companies')
          .add(data);

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'companyId': docRef.id,
        'updatedAt': now,
      }, SetOptions(merge: true));

      await auth.refreshTrainingCompanyId(docRef.id);

      if (mounted) {
        Navigator.popUntil(context, (r) => r.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Setup failed. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _GreenHeader(
            left: IconButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.chevron_left, color: Colors.white),
            ),
            title: 'The Training Triangle',
            subtitle: 'Step 2 of 2',
            progress: 1.0,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A couple more details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Optional but helps clients and trainers find and trust you.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _LabeledField(
                        label: 'Company website',
                        trailing: 'Optional',
                        child: TextFormField(
                          controller: _websiteController,
                          keyboardType: TextInputType.url,
                          decoration: _inputDecoration(
                            'e.g. www.acmetraining.co.uk',
                          ),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return null;
                            final uri = Uri.tryParse(
                              value.startsWith('http')
                                  ? value
                                  : 'https://$value',
                            );
                            final ok = uri != null && uri.host.isNotEmpty;
                            if (!ok) return 'Enter a valid website';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _LabeledField(
                        label: 'Registration number',
                        trailing: 'Optional',
                        child: TextFormField(
                          controller: _registrationNumberController,
                          decoration: _inputDecoration('e.g. 12345678'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F5F7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE7EBEF)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              color: Color(0xFF97A1AA),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'These can be added or updated later in your company settings.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _completeSetup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0E8F7A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _saving ? 'Completing...' : 'Complete setup',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          'By continuing you agree to our Terms & Privacy Policy',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GreenHeader extends StatelessWidget {
  final Widget left;
  final String title;
  final String subtitle;
  final double progress; // 0..1

  const _GreenHeader({
    required this.left,
    required this.title,
    required this.subtitle,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0E8F7A),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
          child: Column(
            children: [
              Row(
                children: [
                  left,
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final String trailing;
  final Widget child;

  const _LabeledField({
    required this.label,
    required this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF0E8F7A),
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF2F5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                trailing,
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF3F5F7),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}
