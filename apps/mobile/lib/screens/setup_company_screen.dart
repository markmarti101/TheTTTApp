import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import 'company_onboarding_step1_screen.dart';

class SetupCompanyScreen extends StatefulWidget {
  const SetupCompanyScreen({super.key});

  @override
  State<SetupCompanyScreen> createState() => _SetupCompanyScreenState();
}

class _SetupCompanyScreenState extends State<SetupCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createCompany() async {
    if (!_formKey.currentState!.validate()) return;

    // Step-based onboarding: collect the remaining fields before creating Firestore doc.
    final name = _nameController.text.trim();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompanyOnboardingStep1Screen(
          initialCompanyName: name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Container(
              color: const Color(0xFF0E8F7A),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed:
                                _saving ? null : () => context.read<AuthProvider>().signOut(),
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'The Training Triangle',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const _TopTabsPill(),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(26),
                    topRight: Radius.circular(26),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome aboard',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Set up your company profile to start managing clients, trainers, and course requests.',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.35,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const _SetupRow(
                          icon: Icons.workspaces_outline,
                          text: 'Company profile & settings',
                        ),
                        const SizedBox(height: 12),
                        const _SetupRow(
                          icon: Icons.group_outlined,
                          text: 'Invite trainers & add clients',
                        ),
                        const SizedBox(height: 12),
                        const _SetupRow(
                          icon: Icons.calendar_month_outlined,
                          text: 'Schedule and manage courses',
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Company name *',
                            hintText: 'e.g. Acme Training Ltd',
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your company name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _createCompany,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0E8F7A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              _saving ? 'Setting up...' : 'Set up your company',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _LegalText(
                          onOpenTerms: () => _showLegalDialog(
                            context,
                            title: 'Terms of Service',
                          ),
                          onOpenPrivacy: () => _showLegalDialog(
                            context,
                            title: 'Privacy Policy',
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
      ),
    );
  }
}

void _showLegalDialog(
  BuildContext context, {
  required String title,
}) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: const Text('We’ll add the full document here shortly.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _TopTabsPill extends StatelessWidget {
  const _TopTabsPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: const [
          Expanded(
            child: _TopTabItem(
              icon: Icons.home_outlined,
              label: 'Company',
              selected: true,
            ),
          ),
          Expanded(
            child: _TopTabItem(
              icon: Icons.group_outlined,
              label: 'Trainers',
              selected: false,
            ),
          ),
          Expanded(
            child: _TopTabItem(
              icon: Icons.person_outline,
              label: 'Clients',
              selected: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopTabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _TopTabItem({
    required this.icon,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? Colors.white.withValues(alpha: 0.22) : Colors.transparent;
    final fg = Colors.white.withValues(alpha: selected ? 1 : 0.88);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SetupRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EEF5)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF0E8F7A).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF0E8F7A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalText extends StatelessWidget {
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  const _LegalText({
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: 12,
      height: 1.35,
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w500,
    );
    final link = base.copyWith(
      color: const Color(0xFF0E8F7A),
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w700,
    );

    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: base,
          children: [
            const TextSpan(text: 'By continuing you agree to our '),
            TextSpan(
              text: 'Terms of Service',
              style: link,
              recognizer: TapGestureRecognizer()..onTap = onOpenTerms,
            ),
            const TextSpan(text: ' and\n'),
            TextSpan(
              text: 'Privacy Policy',
              style: link,
              recognizer: TapGestureRecognizer()..onTap = onOpenPrivacy,
            ),
            const TextSpan(text: '.'),
          ],
        ),
      ),
    );
  }
}
