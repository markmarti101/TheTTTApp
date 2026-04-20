import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/theme.dart';
import '../services/reports_service.dart';

class ReportsScreen extends StatefulWidget {
  final String companyId;
  const ReportsScreen({super.key, required this.companyId});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  final _service = ReportsService();

  late TabController _tabController;

  DateTime? _from;
  DateTime? _to;

  bool _loading = false;
  String? _error;

  CompanySummary? _summary;
  List<TrainerReport> _trainerRows = [];
  List<ClientReport> _clientRows = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getCompanySummary(widget.companyId, from: _from, to: _to),
        _service.getPerTrainerReport(widget.companyId, from: _from, to: _to),
        _service.getPerClientReport(widget.companyId, from: _from, to: _to),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as CompanySummary;
        _trainerRows = results[1] as List<TrainerReport>;
        _clientRows = results[2] as List<ClientReport>;
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

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() {
        _from = range.start;
        _to = range.end;
      });
      _load();
    }
  }

  void _clearFilter() {
    setState(() {
      _from = null;
      _to = null;
    });
    _load();
  }

  Future<void> _exportPdf() async {
    final s = _summary;
    if (s == null) return;

    try {

    final periodLabel = _from != null && _to != null
        ? '${_formatDate(_from!)} – ${_formatDate(_to!)}'
        : 'All time';

    final doc = pw.Document();

    // Colour constants matching the app theme
    const teal = PdfColor.fromInt(0xFF3AB99C);
    const dark = PdfColor.fromInt(0xFF1C1C1C);
    const grey = PdfColor.fromInt(0xFF7D7D7D);
    const lightBg = PdfColor.fromInt(0xFFF3F3F3);
    const green = PdfColor.fromInt(0xFF16A34A);
    const blue = PdfColor.fromInt(0xFF2563EB);
    const red = PdfColor.fromInt(0xFFDC2626);

    pw.Widget headerCell(String text, {PdfColor color = teal}) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: teal,
          child: pw.Text(
            text,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
          ),
        );

    pw.Widget dataCell(String text, {bool bold = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: dark,
            ),
          ),
        );

    pw.Widget metricBox(
        String value, String label, PdfColor valueColor) =>
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: lightBg,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                  color: valueColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                label,
                style: pw.TextStyle(fontSize: 9, color: grey),
              ),
            ],
          ),
        );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Training Report',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: teal,
                  ),
                ),
                pw.Text(
                  'Generated ${_formatDate(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 9, color: grey),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Period: $periodLabel',
              style: pw.TextStyle(fontSize: 10, color: grey),
            ),
            pw.Divider(color: teal, thickness: 1.5),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (context) => [
          // ── Summary metrics ──────────────────────────────────────────
          pw.Text(
            'OVERVIEW',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: grey,
              letterSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: metricBox('${s.totalCourses}', 'Total Courses', teal),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: metricBox('${s.completedCourses}', 'Completed', green),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: metricBox('${s.upcomingCourses}', 'Upcoming', blue),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: metricBox('${s.cancelledCourses}', 'Cancelled', red),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFE8F7F2),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  '${s.totalDelegates}',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: teal,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Text(
                  'Total delegates trained',
                  style: pw.TextStyle(fontSize: 10, color: grey),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ── Trainer breakdown ─────────────────────────────────────────
          if (_trainerRows.isNotEmpty) ...[
            pw.Text(
              'TRAINER BREAKDOWN',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: grey,
                letterSpacing: 1.2,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  children: [
                    headerCell('Trainer'),
                    headerCell('Total'),
                    headerCell('Done'),
                    headerCell('Upcoming'),
                    headerCell('Delegates'),
                  ],
                ),
                ..._trainerRows.asMap().entries.map((e) {
                  final r = e.value;
                  final bg = e.key.isEven ? PdfColors.white : lightBg;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: [
                      dataCell(r.trainerName, bold: true),
                      dataCell('${r.totalCourses}'),
                      dataCell('${r.completedCourses}'),
                      dataCell('${r.upcomingCourses}'),
                      dataCell('${r.totalDelegates}'),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),
          ],

          // ── Client breakdown ──────────────────────────────────────────
          if (_clientRows.isNotEmpty) ...[
            pw.Text(
              'CLIENT BREAKDOWN',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: grey,
                letterSpacing: 1.2,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  children: [
                    headerCell('Client'),
                    headerCell('Total'),
                    headerCell('Done'),
                    headerCell('Upcoming'),
                    headerCell('Delegates'),
                  ],
                ),
                ..._clientRows.asMap().entries.map((e) {
                  final r = e.value;
                  final bg = e.key.isEven ? PdfColors.white : lightBg;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: [
                      dataCell(r.clientName, bold: true),
                      dataCell('${r.totalCourses}'),
                      dataCell('${r.completedCourses}'),
                      dataCell('${r.upcomingCourses}'),
                      dataCell('${r.totalDelegates}'),
                    ],
                  );
                }),
              ],
            ),
          ],
        ],
      ),
    );

      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: 'training_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF export failed: $e')),
      );
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

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
          'Reports',
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primary),
            tooltip: 'Export as PDF',
            onPressed: _loading || _summary == null ? null : _exportPdf,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Trainers'),
            Tab(text: 'Clients'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _error != null
                    ? _buildError()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(),
                          _buildTrainersTab(),
                          _buildClientsTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final hasFilter = _from != null && _to != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: const Color(0xFFE0E0E0))),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range_outlined,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: _pickDateRange,
              child: Text(
                hasFilter
                    ? '${_formatDate(_from!)} – ${_formatDate(_to!)}'
                    : 'All time  (tap to filter)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: hasFilter ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          if (hasFilter)
            GestureDetector(
              onTap: _clearFilter,
              child: const Icon(Icons.close, size: 18, color: Color(0xFF9E9E9E)),
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFE53935), size: 40),
            const SizedBox(height: 12),
            Text(
              'Failed to load reports',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Overview Tab ──────────────────────────────────────────────────────────

  Widget _buildOverviewTab() {
    final s = _summary;
    if (s == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('SUMMARY'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            children: [
              _summaryCard('Total Courses', '${s.totalCourses}', AppColors.primary),
              _summaryCard('Completed', '${s.completedCourses}', const Color(0xFF16A34A)),
              _summaryCard('Upcoming', '${s.upcomingCourses}', const Color(0xFF2563EB)),
              _summaryCard('Cancelled', '${s.cancelledCourses}', const Color(0xFFDC2626)),

            ],
          ),
          const SizedBox(height: 16),
          _buildDelegatesBanner(s.totalDelegates),
          const SizedBox(height: 20),
          _sectionLabel('COMPLETION RATE'),
          const SizedBox(height: 10),
          _buildCompletionBar(s),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF7D7D7D),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDelegatesBanner(int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.groups_outlined, color: AppColors.primary, size: 28),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$total',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  height: 1,
                ),
              ),
              const Text(
                'Total delegates trained',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionBar(CompanySummary s) {
    final pct = s.totalCourses == 0
        ? 0.0
        : s.completedCourses / s.totalCourses;
    final pctLabel = '${(pct * 100).round()}%';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Courses completed',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.text,
                ),
              ),
              Text(
                pctLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: const Color(0xFFE0E0E0),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${s.completedCourses} of ${s.totalCourses} courses',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9E9E9E),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Trainers Tab ──────────────────────────────────────────────────────────

  Widget _buildTrainersTab() {
    if (_trainerRows.isEmpty) {
      return _buildEmptyState('No trainer data for this period.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _trainerRows.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _trainerCard(_trainerRows[i]),
    );
  }

  Widget _trainerCard(TrainerReport r) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  _initials(r.trainerName),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r.trainerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _pill('${r.totalCourses} courses', AppColors.primary),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statChip(Icons.check_circle_outline, '${r.completedCourses}',
                  'done', const Color(0xFF16A34A)),
              const SizedBox(width: 8),
              _statChip(Icons.upcoming_outlined, '${r.upcomingCourses}',
                  'upcoming', const Color(0xFF2563EB)),
              const SizedBox(width: 8),
              _statChip(Icons.groups_outlined, '${r.totalDelegates}',
                  'delegates', AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  // ── Clients Tab ───────────────────────────────────────────────────────────

  Widget _buildClientsTab() {
    if (_clientRows.isEmpty) {
      return _buildEmptyState('No client data for this period.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _clientRows.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _clientCard(_clientRows[i]),
    );
  }

  Widget _clientCard(ClientReport r) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
                child: Text(
                  _initials(r.clientName),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r.clientName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _pill('${r.totalCourses} courses', const Color(0xFF2563EB)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statChip(Icons.check_circle_outline, '${r.completedCourses}',
                  'done', const Color(0xFF16A34A)),
              const SizedBox(width: 8),
              _statChip(Icons.upcoming_outlined, '${r.upcomingCourses}',
                  'upcoming', const Color(0xFF2563EB)),
              const SizedBox(width: 8),
              _statChip(Icons.groups_outlined, '${r.totalDelegates}',
                  'delegates', AppColors.textSecondary),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_outlined,
                size: 48, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              '$value ',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: color.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (name.length >= 2) return name.substring(0, 2).toUpperCase();
    return name.toUpperCase();
  }
}
