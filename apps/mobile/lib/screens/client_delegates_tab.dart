import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/theme.dart';
import '../models/delegate.dart';
import '../services/delegates_service.dart';

class ClientDelegatesTab extends StatefulWidget {
  final String clientId;
  const ClientDelegatesTab({super.key, required this.clientId});

  @override
  State<ClientDelegatesTab> createState() => _ClientDelegatesTabState();
}

class _ClientDelegatesTabState extends State<ClientDelegatesTab> {
  final _service = DelegatesService();

  List<Delegate> _delegates = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final delegates = await _service.getDelegates(widget.clientId);
      if (mounted) setState(() { _delegates = delegates; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(Delegate delegate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Delegate',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text(
          'Remove ${delegate.name} from your delegates?',
          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove',
                style: TextStyle(
                    color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.removeDelegate(widget.clientId, delegate.id);
    await _load();
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DelegateFormSheet(
        title: 'Add Delegate',
        onSave: (name, email, accessibility, dietary) async {
          Navigator.pop(context);
          setState(() => _saving = true);
          try {
            await _service.addDelegate(
              widget.clientId,
              name: name,
              email: email,
              accessibilityNeeds: accessibility,
              dietaryRequirements: dietary,
            );
            await _load();
          } finally {
            if (mounted) setState(() => _saving = false);
          }
        },
      ),
    );
  }

  void _showEditSheet(Delegate delegate) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DelegateFormSheet(
        title: 'Edit Delegate',
        initialName: delegate.name,
        initialEmail: delegate.email,
        initialAccessibility: delegate.accessibilityNeeds,
        initialDietary: delegate.dietaryRequirements,
        onSave: (name, email, accessibility, dietary) async {
          Navigator.pop(context);
          setState(() => _saving = true);
          try {
            await _service.updateDelegate(
              widget.clientId,
              delegate.id,
              name: name,
              email: email,
              accessibilityNeeds: accessibility,
              dietaryRequirements: dietary,
            );
            await _load();
          } finally {
            if (mounted) setState(() => _saving = false);
          }
        },
      ),
    );
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    final delegates = List<Delegate>.from(_delegates)
      ..sort((a, b) => a.name.compareTo(b.name));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Text(
            'Delegate List',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Exported ${DateTime.now().toLocal().toString().split('.')[0]}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF2DB89E)),
                children: ['Name', 'Email', 'Accessibility', 'Dietary']
                    .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          child: pw.Text(
                            h,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ))
                    .toList(),
              ),
              // Data rows
              ...delegates.map((d) => pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: delegates.indexOf(d).isEven
                          ? PdfColors.white
                          : const PdfColor.fromInt(0xFFF8FAFC),
                    ),
                    children: [
                      d.name,
                      d.email,
                      d.accessibilityNeeds ?? '—',
                      d.dietaryRequirements ?? '—',
                    ]
                        .map((cell) => pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              child: pw.Text(
                                cell,
                                style: const pw.TextStyle(fontSize: 9),
                              ),
                            ))
                        .toList(),
                  )),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            '${delegates.length} delegate${delegates.length == 1 ? '' : 's'} total',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'delegates_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _loading || _saving
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary))
                    : _delegates.isEmpty
                        ? _buildEmptyState()
                        : _buildList(),
              ),
            ],
          ),
          if (_delegates.isNotEmpty && !_loading && !_saving)
            Positioned(
              bottom: 24,
              right: 20,
              child: FloatingActionButton(
                onPressed: _showAddSheet,
                backgroundColor: AppColors.primary,
                elevation: 4,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Delegates',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (_delegates.isNotEmpty)
                GestureDetector(
                  onTap: _exportPdf,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.download_outlined,
                            size: 14, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Export',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (_delegates.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '${_delegates.length} member${_delegates.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        itemCount: _delegates.length,
        separatorBuilder: (context, i) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _DelegateCard(
          delegate: _delegates[i],
          onEdit: () => _showEditSheet(_delegates[i]),
          onRemove: () => _remove(_delegates[i]),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.group_outlined,
                  size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'No delegates yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add the members of your team who\nwill be attending training.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _showAddSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Add First Delegate',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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

// ─── Delegate Card ─────────────────────────────────────────────────────────────

class _DelegateCard extends StatelessWidget {
  final Delegate delegate;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  const _DelegateCard({
    required this.delegate,
    required this.onEdit,
    required this.onRemove,
  });

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFF2DB89E),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFFF59E0B),
      Color(0xFF10B981),
      Color(0xFFEF4444),
      Color(0xFFF97316),
      Color(0xFF14B8A6),
    ];
    final hash = name.codeUnits.fold(0, (a, b) => a + b);
    return colors[hash % colors.length];
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final color = _avatarColor(delegate.name);
    final hasFlags = delegate.hasAccessibility || delegate.hasDietary;

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _initials(delegate.name),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        delegate.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        delegate.email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: AppColors.primary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            if (hasFlags) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (delegate.hasAccessibility)
                    _FlagChip(
                      icon: Icons.accessible_outlined,
                      label: delegate.accessibilityNeeds!,
                      color: const Color(0xFF8B5CF6),
                    ),
                  if (delegate.hasDietary)
                    _FlagChip(
                      icon: Icons.restaurant_outlined,
                      label: delegate.dietaryRequirements!,
                      color: const Color(0xFFF59E0B),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FlagChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _FlagChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Delegate Form Sheet (Add / Edit) ─────────────────────────────────────────

class _DelegateFormSheet extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialEmail;
  final String? initialAccessibility;
  final String? initialDietary;
  final Future<void> Function(
      String name, String email, String? accessibility, String? dietary) onSave;

  const _DelegateFormSheet({
    required this.title,
    this.initialName,
    this.initialEmail,
    this.initialAccessibility,
    this.initialDietary,
    required this.onSave,
  });

  @override
  State<_DelegateFormSheet> createState() => _DelegateFormSheetState();
}

class _DelegateFormSheetState extends State<_DelegateFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _accessibilityCtrl;
  late final TextEditingController _dietaryCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    _emailCtrl = TextEditingController(text: widget.initialEmail ?? '');
    _accessibilityCtrl =
        TextEditingController(text: widget.initialAccessibility ?? '');
    _dietaryCtrl =
        TextEditingController(text: widget.initialDietary ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _accessibilityCtrl.dispose();
    _dietaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await widget.onSave(
      _nameCtrl.text,
      _emailCtrl.text,
      _accessibilityCtrl.text.trim().isEmpty
          ? null
          : _accessibilityCtrl.text.trim(),
      _dietaryCtrl.text.trim().isEmpty ? null : _dietaryCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close,
                      size: 20, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildField(
                    controller: _nameCtrl,
                    label: 'Full Name',
                    hint: 'e.g. John Smith',
                    icon: Icons.person_outline,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Name is required'
                            : null,
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _emailCtrl,
                    label: 'Email Address',
                    hint: 'e.g. john@company.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _accessibilityCtrl,
                    label: 'Accessibility Needs (optional)',
                    hint: 'e.g. Wheelchair access, hearing loop',
                    icon: Icons.accessible_outlined,
                  ),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _dietaryCtrl,
                    label: 'Dietary Requirements (optional)',
                    hint: 'e.g. Vegetarian, nut allergy',
                    icon: Icons.restaurant_outlined,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Save Delegate',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
            prefixIcon:
                Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}
