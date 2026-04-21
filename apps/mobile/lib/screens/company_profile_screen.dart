import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';

class CompanyProfileScreen extends StatefulWidget {
  final String companyId;
  const CompanyProfileScreen({super.key, required this.companyId});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  final _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  // User fields
  String _email = '';
  String _displayName = '';

  // Company fields
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final futures = await Future.wait([
        if (uid != null)
          _firestore.collection('users').doc(uid).get()
        else
          Future<DocumentSnapshot<Map<String, dynamic>>?>.value(null),
        _firestore
            .collection('training_companies')
            .doc(widget.companyId)
            .get(),
      ]);

      final userDoc =
          futures[0] as DocumentSnapshot<Map<String, dynamic>>?;
      final companyDoc =
          futures[1] as DocumentSnapshot<Map<String, dynamic>>;

      if (!mounted) return;

      setState(() {
        _email = FirebaseAuth.instance.currentUser?.email ?? '';
        if (userDoc != null && userDoc.exists) {
          _displayName =
              (userDoc.data()?['displayName'] as String?) ?? '';
        }
        if (companyDoc.exists) {
          final d = companyDoc.data()!;
          _nameCtrl.text = _firstString(d, [
                'name',
                'companyName',
                'businessName',
                'title',
              ]) ??
              '';
          _addressCtrl.text =
              (d['address'] as String?) ?? '';
          _phoneCtrl.text = (d['phone'] as String?) ?? '';
          _websiteCtrl.text = (d['website'] as String?) ?? '';
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String? _firstString(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company name cannot be empty')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _firestore
          .collection('training_companies')
          .doc(widget.companyId)
          .update({
        'name': name,
        'address': _addressCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.isEmpty) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Password reset email sent to $email'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  String _initials() {
    final name = _displayName.trim();
    if (name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      if (name.length >= 2) return name.substring(0, 2).toUpperCase();
      return name[0].toUpperCase();
    }
    if (_email.contains('@')) {
      final local = _email.split('@')[0];
      if (local.length >= 2) return local.substring(0, 2).toUpperCase();
      return local[0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + user info
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2DB89E), Color(0xFF1A9980)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initials(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_displayName.isNotEmpty)
                  Text(
                    _displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  _email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Company details
          _sectionLabel('COMPANY DETAILS'),
          const SizedBox(height: 10),
          _card([
            _field(
              controller: _nameCtrl,
              label: 'Company Name',
              icon: Icons.business_outlined,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _addressCtrl,
              label: 'Address',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _phoneCtrl,
              label: 'Phone',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _field(
              controller: _websiteCtrl,
              label: 'Website',
              icon: Icons.language_outlined,
              keyboardType: TextInputType.url,
            ),
          ]),
          const SizedBox(height: 20),

          // Account section
          _sectionLabel('ACCOUNT'),
          const SizedBox(height: 10),
          _card([
            _infoRow('Email', _email, Icons.email_outlined),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline,
                  color: AppColors.primary, size: 20),
              title: const Text(
                'Change Password',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              trailing: const Icon(Icons.chevron_right,
                  color: Color(0xFFCBD5E1)),
              onTap: _changePassword,
            ),
          ]),
          const SizedBox(height: 20),

          // Sign out
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
                context.read<AuthProvider>().signOut();
              },
              icon: const Icon(Icons.logout_outlined, size: 18),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(
                    color: AppColors.primary, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: AppColors.textSecondary.withValues(alpha: 0.85),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        labelStyle: const TextStyle(
            fontSize: 13, color: Color(0xFF94A3B8)),
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
