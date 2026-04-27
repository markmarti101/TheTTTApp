import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../services/requests_service.dart';

class CourseRequestScreen extends StatefulWidget {
  const CourseRequestScreen({super.key});

  @override
  State<CourseRequestScreen> createState() => _CourseRequestScreenState();
}

class _CourseRequestScreenState extends State<CourseRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  // Course details
  final _titleController = TextEditingController();
  final _topicController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _preferredDate;

  // Booking form fields
  final _delegateCountController = TextEditingController();
  final _poNumberController = TextEditingController();
  final _venuePreferenceController = TextEditingController();
  final _cateringNotesController = TextEditingController();
  final _accessibilityNotesController = TextEditingController();
  String? _venueSetup; // 'classroom' | 'theatre' | 'cabaret' | 'boardroom'

  bool _submitting = false;
  final _requestsService = RequestsService();

  @override
  void dispose() {
    _titleController.dispose();
    _topicController.dispose();
    _notesController.dispose();
    _delegateCountController.dispose();
    _poNumberController.dispose();
    _venuePreferenceController.dispose();
    _cateringNotesController.dispose();
    _accessibilityNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickPreferredDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      initialDate: _preferredDate ?? now,
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _preferredDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final trainingCompanyId = auth.trainingCompanyId;

    if (user == null || trainingCompanyId == null || trainingCompanyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No linked training company found for this account.'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final preferredIso = _preferredDate?.toUtc().toIso8601String();
      final delegateText = _delegateCountController.text.trim();

      await _requestsService.createRequest(
        trainingCompanyId: trainingCompanyId,
        clientId: user.uid,
        title: _titleController.text.trim(),
        topic: _topicController.text.trim().isEmpty
            ? null
            : _topicController.text.trim(),
        preferredDateIso: preferredIso,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        delegateCount: delegateText.isNotEmpty ? int.tryParse(delegateText) : null,
        poNumber: _poNumberController.text.trim().isEmpty
            ? null
            : _poNumberController.text.trim(),
        venuePreference: _venuePreferenceController.text.trim().isEmpty
            ? null
            : _venuePreferenceController.text.trim(),
        venueSetup: _venueSetup,
        cateringNotes: _cateringNotesController.text.trim().isEmpty
            ? null
            : _cateringNotesController.text.trim(),
        accessibilityNotes: _accessibilityNotesController.text.trim().isEmpty
            ? null
            : _accessibilityNotesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request submitted.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit request. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: const Text('Request Training'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // ── Course Details ──────────────────────────────────────
              _SectionCard(
                title: 'Course Details',
                icon: Icons.school_outlined,
                children: [
                  _formField(
                    controller: _titleController,
                    label: 'Course title',
                    hint: 'e.g. First Aid at Work',
                    required: true,
                  ),
                  const SizedBox(height: 12),
                  _formField(
                    controller: _topicController,
                    label: 'Topic',
                    hint: 'e.g. Health & Safety',
                  ),
                  const SizedBox(height: 12),
                  // Preferred date
                  GestureDetector(
                    onTap: _pickPreferredDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 18, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 10),
                          Text(
                            _preferredDate != null
                                ? 'Preferred date: ${_fmtDate(_preferredDate!)}'
                                : 'Preferred date (optional)',
                            style: TextStyle(
                              fontSize: 13,
                              color: _preferredDate != null
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          const Spacer(),
                          if (_preferredDate != null)
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _preferredDate = null),
                              child: const Icon(Icons.close,
                                  size: 16, color: Color(0xFFCBD5E1)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _formField(
                    controller: _notesController,
                    label: 'Notes for the training company',
                    hint: 'Any specific requirements or context…',
                    maxLines: 3,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Booking Details ─────────────────────────────────────
              _SectionCard(
                title: 'Booking Details',
                icon: Icons.people_outline,
                children: [
                  _formField(
                    controller: _delegateCountController,
                    label: 'Number of delegates',
                    hint: 'e.g. 12',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _formField(
                    controller: _poNumberController,
                    label: 'PO Number',
                    hint: 'e.g. PO-2026-001',
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Venue Booking Form ──────────────────────────────────
              _SectionCard(
                title: 'Venue & Logistics',
                icon: Icons.location_on_outlined,
                children: [
                  _formField(
                    controller: _venuePreferenceController,
                    label: 'Preferred venue / location',
                    hint: 'e.g. Our office in Manchester',
                  ),
                  const SizedBox(height: 12),
                  // Room setup chips
                  const Text(
                    'Room setup',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      'classroom',
                      'theatre',
                      'cabaret',
                      'boardroom'
                    ].map((setup) {
                      final selected = _venueSetup == setup;
                      return GestureDetector(
                        onTap: () => setState(() =>
                            _venueSetup = selected ? null : setup),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            _capitalise(setup),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? AppColors.primary
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  _formField(
                    controller: _cateringNotesController,
                    label: 'Catering requirements',
                    hint: 'e.g. Tea/coffee, lunch for 12',
                    maxLines: 2,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Accessibility & Requirements ────────────────────────
              _SectionCard(
                title: 'Accessibility & Requirements',
                icon: Icons.accessibility_new_outlined,
                children: [
                  _formField(
                    controller: _accessibilityNotesController,
                    label: 'Accessibility or dietary requirements',
                    hint:
                        'e.g. Wheelchair access needed, vegetarian meals required',
                    maxLines: 3,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  child: Text(_submitting ? 'Submitting…' : 'Submit Request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          required ? '$label *' : label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: required
              ? (v) =>
                  v == null || v.trim().isEmpty ? 'Please enter $label' : null
              : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
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
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDC2626))),
          ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime dt) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                      letterSpacing: 0.3),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
