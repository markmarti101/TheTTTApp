import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';
import 'invoice_detail_screen.dart';

class InvoicesScreen extends StatefulWidget {
  final String companyId;
  const InvoicesScreen({super.key, required this.companyId});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen>
    with SingleTickerProviderStateMixin {
  final _service = InvoiceService();
  late TabController _tabs;

  List<Invoice> _all = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invoices = await _service.getInvoicesByCompany(widget.companyId);
      if (!mounted) return;
      // auto-mark overdue
      final updated = invoices.map((inv) {
        if (inv.isOverdue && inv.status == 'sent') {
          return Invoice.fromFirestore(inv.id, {
            'invoiceNumber': inv.invoiceNumber,
            'courseId': inv.courseId,
            'courseTitle': inv.courseTitle,
            'clientId': inv.clientId,
            'trainingCompanyId': inv.trainingCompanyId,
            'amount': inv.amount,
            'status': 'overdue',
            'dueDate': inv.dueDate.toIso8601String(),
            'poNumber': inv.poNumber,
            'notes': inv.notes,
            'createdAt': inv.createdAt,
            'updatedAt': inv.updatedAt,
          });
        }
        return inv;
      }).toList();
      setState(() {
        _all = updated;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load invoices. Please try again.';
        _loading = false;
      });
    }
  }

  List<Invoice> get _unpaid =>
      _all.where((i) => i.status == 'draft' || i.status == 'sent').toList();
  List<Invoice> get _overdue => _all.where((i) => i.status == 'overdue').toList();
  List<Invoice> get _paid => _all.where((i) => i.status == 'paid').toList();

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
          'Invoices',
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(text: 'All (${_all.length})'),
            Tab(text: 'Unpaid (${_unpaid.length})'),
            Tab(text: 'Overdue (${_overdue.length})'),
            Tab(text: 'Paid (${_paid.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _buildList(_all),
                    _buildList(_unpaid),
                    _buildList(_overdue),
                    _buildList(_paid),
                  ],
                ),
    );
  }

  Widget _buildList(List<Invoice> invoices) {
    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 48,
                color: AppColors.textSecondary.withValues(alpha: 0.35)),
            const SizedBox(height: 12),
            const Text(
              'No invoices here',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: invoices.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _InvoiceCard(
          invoice: invoices[i],
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    InvoiceDetailScreen(invoiceId: invoices[i].id),
              ),
            );
            _load();
          },
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              color: Color(0xFFE53935), size: 40),
          const SizedBox(height: 12),
          const Text('Failed to load invoices',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.text)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;
  const _InvoiceCard({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusBg, statusFg) = _statusStyle(invoice.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_outlined,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.courseTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    invoice.invoiceNumber,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Due ${_fmtDate(invoice.dueDate)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: invoice.status == 'overdue'
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF9E9E9E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '£${invoice.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusFg,
                    ),
                  ),
                ),
              ],
            ),
          ],
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
      'overdue' => ('Overdue', const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
      _ => ('Draft', const Color(0xFFF1F5F9), const Color(0xFF64748B)),
    };
  }
}
