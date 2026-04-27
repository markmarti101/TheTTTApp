import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/theme.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final _service = InvoiceService();
  Invoice? _invoice;
  bool _loading = true;
  bool _acting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final inv = await _service.getInvoice(widget.invoiceId);
      if (!mounted) return;
      setState(() {
        _invoice = inv;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load invoice. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _acting = true);
    try {
      await _service.updateStatus(widget.invoiceId, status);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Invoice?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: const Text(
            'This will permanently delete the invoice. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _acting = true);
    try {
      await _service.deleteInvoice(widget.invoiceId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Action failed. Please try again.')));
      }
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _exportPdf() async {
    final inv = _invoice;
    if (inv == null) return;

    try {
      const teal = PdfColor.fromInt(0xFF3AB99C);
      const dark = PdfColor.fromInt(0xFF1C1C1C);
      const grey = PdfColor.fromInt(0xFF7D7D7D);
      const lightBg = PdfColor.fromInt(0xFFF3F3F3);

      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'INVOICE',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: teal,
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(inv.invoiceNumber,
                          style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: dark)),
                      pw.SizedBox(height: 4),
                      pw.Text('Issued: ${_fmtDate(DateTime.now())}',
                          style:
                              pw.TextStyle(fontSize: 10, color: grey)),
                      pw.Text('Due: ${_fmtDate(inv.dueDate)}',
                          style:
                              pw.TextStyle(fontSize: 10, color: grey)),
                    ],
                  ),
                ],
              ),
              pw.Divider(color: teal, thickness: 1.5),
              pw.SizedBox(height: 20),

              // Course info
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: lightBg,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Course',
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: grey,
                            letterSpacing: 1)),
                    pw.SizedBox(height: 4),
                    pw.Text(inv.courseTitle,
                        style: pw.TextStyle(
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                            color: dark)),
                    if (inv.poNumber != null &&
                        inv.poNumber!.isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pw.Text('PO: ${inv.poNumber}',
                          style:
                              pw.TextStyle(fontSize: 11, color: grey)),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Line item
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: teal),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Description',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Amount',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10),
                            textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          inv.notes?.isNotEmpty == true
                              ? inv.notes!
                              : 'Training services — ${inv.courseTitle}',
                          style: pw.TextStyle(
                              fontSize: 10, color: dark),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                            '£${inv.amount.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                                fontSize: 10, color: dark),
                            textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),

              // Total
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFE8F7F2),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text('TOTAL DUE',
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: grey)),
                      pw.SizedBox(width: 20),
                      pw.Text('£${inv.amount.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: teal)),
                    ],
                  ),
                ),
              ),
              pw.Spacer(),

              // Footer
              pw.Divider(color: lightBg, thickness: 1),
              pw.SizedBox(height: 6),
              pw.Text('Generated by Training Triangle',
                  style: pw.TextStyle(fontSize: 9, color: grey)),
            ],
          ),
        ),
      );

      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: '${inv.invoiceNumber}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF export failed. Please try again.')),
      );
    }
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
        title: Text(
          _invoice?.invoiceNumber ?? 'Invoice',
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_invoice != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined,
                  color: AppColors.primary),
              tooltip: 'Export PDF',
              onPressed: _acting ? null : _exportPdf,
            ),
          if (_invoice?.status == 'draft')
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Color(0xFFDC2626)),
              tooltip: 'Delete',
              onPressed: _acting ? null : _delete,
            ),
        ],
      ),
      body: _loading || _acting
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!))
              : _invoice == null
                  ? const Center(child: Text('Invoice not found'))
                  : _buildBody(_invoice!),
    );
  }

  Widget _buildBody(Invoice inv) {
    final (statusLabel, statusBg, statusFg) = _statusStyle(inv.status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status + amount hero
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2DB89E), Color(0xFF1A9980)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusFg,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '£${inv.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  inv.courseTitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Details card
          _card([
            _row('Invoice No.', inv.invoiceNumber,
                Icons.tag_outlined),
            _divider(),
            _row('Due Date', _fmtDate(inv.dueDate),
                Icons.calendar_today_outlined,
                valueColor: inv.isOverdue
                    ? const Color(0xFFDC2626)
                    : null),
            if (inv.poNumber != null && inv.poNumber!.isNotEmpty) ...[
              _divider(),
              _row('PO Number', inv.poNumber!,
                  Icons.confirmation_number_outlined),
            ],
            if (inv.notes != null && inv.notes!.isNotEmpty) ...[
              _divider(),
              _row('Notes', inv.notes!, Icons.notes_outlined),
            ],
          ]),
          const SizedBox(height: 24),

          // Action buttons
          if (inv.status == 'draft') ...[
            _actionButton(
              label: 'Mark as Sent',
              icon: Icons.send_outlined,
              color: const Color(0xFF2563EB),
              onTap: () => _updateStatus('sent'),
            ),
            const SizedBox(height: 10),
          ],
          if (inv.status == 'sent' || inv.status == 'overdue') ...[
            _actionButton(
              label: 'Mark as Paid',
              icon: Icons.check_circle_outline,
              color: const Color(0xFF16A34A),
              onTap: () => _updateStatus('paid'),
            ),
            const SizedBox(height: 10),
          ],
          if (inv.status == 'paid')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Color(0xFF16A34A), size: 20),
                  SizedBox(width: 10),
                  Text(
                    'This invoice has been paid.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF16A34A),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(children: children),
    );
  }

  Widget _row(String label, String value, IconData icon,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? const Color(0xFF1E293B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, color: Color(0xFFF1F5F9));

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  (String, Color, Color) _statusStyle(String status) {
    return switch (status) {
      'paid' => ('Paid', const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
      'sent' => ('Sent', const Color(0xFFDBEAFE), const Color(0xFF2563EB)),
      'overdue' =>
        ('Overdue', const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
      _ => ('Draft', const Color(0xFFF1F5F9), const Color(0xFF64748B)),
    };
  }
}
