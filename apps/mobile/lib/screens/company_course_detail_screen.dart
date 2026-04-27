import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../models/course.dart';
import '../models/document.dart';
import '../models/invoice.dart';
import '../models/venue.dart';
import '../providers/auth_provider.dart';
import '../services/audit_log_service.dart';
import '../services/courses_service.dart';
import '../services/document_service.dart';
import '../services/invoice_service.dart';
import '../services/notification_service.dart';
import '../services/venues_service.dart';
import 'invoice_detail_screen.dart';

class CompanyCourseDetailScreen extends StatefulWidget {
  final String courseId;

  const CompanyCourseDetailScreen({super.key, required this.courseId});

  @override
  State<CompanyCourseDetailScreen> createState() =>
      _CompanyCourseDetailScreenState();
}

class _CompanyCourseDetailScreenState
    extends State<CompanyCourseDetailScreen> {
  final _coursesService = CoursesService();
  final _venuesService = VenuesService();
  final _documentService = DocumentService();
  final _invoiceService = InvoiceService();

  Course? _course;
  Venue? _venue;
  String? _clientDisplay;
  String? _trainerDisplay;
  List<CourseDocument> _documents = [];
  Invoice? _invoice;

  bool _loading = true;
  String? _error;
  bool _assigningVenue = false;
  bool _markingComplete = false;
  bool _settingPoNumber = false;
  bool _uploadingDoc = false;
  bool _creatingInvoice = false;

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
      final course = await _coursesService.getCourse(widget.courseId);
      if (course == null) {
        setState(() {
          _loading = false;
          _error = 'Course not found.';
        });
        return;
      }

      Venue? venue;
      if (course.venueId != null && course.venueId!.isNotEmpty) {
        final vDoc = await FirebaseFirestore.instance
            .collection('venues')
            .doc(course.venueId)
            .get();
        if (vDoc.exists) {
          venue = Venue.fromFirestore(vDoc.id, vDoc.data()!);
        }
      }

      String? clientDisplay;
      final clientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(course.clientId)
          .get();
      if (clientDoc.exists) {
        final data = clientDoc.data() as Map<String, dynamic>;
        clientDisplay =
            (data['displayName'] as String?) ?? (data['email'] as String?);
      }

      String? trainerDisplay;
      final trainerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(course.trainerId)
          .get();
      if (trainerDoc.exists) {
        final data = trainerDoc.data() as Map<String, dynamic>;
        trainerDisplay =
            (data['displayName'] as String?) ?? (data['email'] as String?);
      }

      List<CourseDocument> documents = [];
      try {
        documents = await _documentService.getDocumentsByCourse(course.id);
      } catch (_) {}

      Invoice? invoice;
      try {
        invoice = await _invoiceService.getInvoiceByCourse(course.id);
      } catch (_) {}

      setState(() {
        _course = course;
        _venue = venue;
        _clientDisplay = clientDisplay ?? course.clientId;
        _trainerDisplay = trainerDisplay ?? course.trainerId;
        _documents = documents;
        _invoice = invoice;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load course.';
        _loading = false;
      });
    }
  }

  Future<void> _confirmMarkComplete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Mark as Completed?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: const Text(
          'This will mark the course as completed and the client will be able to view their certificate and leave feedback.',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Mark Complete',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final uid = context.read<AuthProvider>().user?.uid ?? '';
    setState(() => _markingComplete = true);
    try {
      await _coursesService.markCourseCompleted(widget.courseId);
      final course = _course;
      if (course != null) {
        final notifs = NotificationService();
        await notifs.send(
          recipientId: course.clientId,
          title: 'Course completed',
          body: '"${course.title}" has been marked as completed.',
          type: 'course_completed',
          relatedId: widget.courseId,
        );
        await notifs.send(
          recipientId: course.trainerId,
          title: 'Course completed',
          body: '"${course.title}" has been marked as completed.',
          type: 'course_completed',
          relatedId: widget.courseId,
        );
        await AuditLogService().log(
          companyId: course.trainingCompanyId,
          action: 'course_completed',
          description: 'Course marked as completed — ${course.title}',
          performedBy: uid,
          entityId: widget.courseId,
        );
      }
      await _load();
    } finally {
      if (mounted) setState(() => _markingComplete = false);
    }
  }

  Future<void> _showAssignVenueSheet() async {
    final course = _course;
    if (course == null) return;

    List<Venue> venues = [];
    try {
      venues = await _venuesService.getVenues(course.trainingCompanyId);
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _VenuePickerSheet(
        venues: venues,
        currentVenueId: course.venueId,
        onPick: (venue) async {
          Navigator.pop(context);
          setState(() => _assigningVenue = true);
          try {
            await _coursesService.updateCourseVenue(
                widget.courseId, venue?.id);
            await _load();
          } finally {
            if (mounted) setState(() => _assigningVenue = false);
          }
        },
      ),
    );
  }

  Future<void> _showSetPoNumberDialog() async {
    final controller =
        TextEditingController(text: _course?.poNumber ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Set PO Number',
            style:
                TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g. PO-2026-001',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 1.5)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result == null) return;
    setState(() => _settingPoNumber = true);
    try {
      await _coursesService.updatePoNumber(widget.courseId, result);
      await _load();
    } finally {
      if (mounted) setState(() => _settingPoNumber = false);
    }
  }

  Future<void> _uploadDocument() async {
    final course = _course;
    if (course == null) return;
    final companyId = context.read<AuthProvider>().trainingCompanyId ?? '';
    final uid = context.read<AuthProvider>().user?.uid ?? '';
    setState(() => _uploadingDoc = true);
    try {
      final doc = await _documentService.pickAndUpload(
        courseId: course.id,
        courseNumber: course.courseNumber,
        trainingCompanyId: companyId,
        clientId: course.clientId,
        uploadedBy: uid,
        uploaderRole: 'training_company',
        type: DocumentType.preCoursePackk,
      );
      if (doc != null && mounted) {
        await AuditLogService().log(
          companyId: companyId,
          action: 'document_uploaded',
          description: 'Document uploaded — ${doc.fileName}',
          performedBy: uid,
          entityId: course.id,
        );
        await _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pre-course pack uploaded.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingDoc = false);
    }
  }

  Future<void> _showCreateInvoiceSheet() async {
    final course = _course;
    if (course == null) return;

    final amountController = TextEditingController();
    final notesController = TextEditingController(text: course.poNumber ?? '');
    DateTime dueDate = DateTime.now().add(const Duration(days: 30));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Create Invoice',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20,
                        color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (£)',
                  prefixText: '£ ',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: dueDate,
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365)),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                            primary: AppColors.primary),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setSheet(() => dueDate = picked);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Due: ${dueDate.day}/${dueDate.month}/${dueDate.year}',
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final amt =
                        double.tryParse(amountController.text.trim());
                    if (amt == null || amt <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Please enter a valid amount')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    setState(() => _creatingInvoice = true);
                    try {
                      final id =
                          await _invoiceService.createInvoice(
                        courseId: course.id,
                        courseTitle: course.title,
                        clientId: course.clientId,
                        trainingCompanyId: course.trainingCompanyId,
                        amount: amt,
                        dueDate: dueDate,
                        poNumber: course.poNumber,
                        notes: notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim(),
                      );
                      await AuditLogService().log(
                        companyId: course.trainingCompanyId,
                        action: 'invoice_created',
                        description:
                            'Invoice created — £${amt.toStringAsFixed(2)} for ${course.title}',
                        performedBy:
                            context.read<AuthProvider>().user?.uid ?? '',
                        entityId: id,
                      );
                      await _load();
                      if (mounted) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                InvoiceDetailScreen(invoiceId: id),
                          ),
                        );
                        await _load();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  const Text('Failed to create invoice. Please try again.')),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _creatingInvoice = false);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  child: const Text('Create Invoice'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteDocument(CourseDocument doc) async {
    try {
      await _documentService.deleteDocument(doc);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove document. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading ||
              _assigningVenue ||
              _markingComplete ||
              _settingPoNumber ||
              _uploadingDoc ||
              _creatingInvoice
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _ErrorBody(error: _error!, onRetry: _load)
              : _course == null
                  ? const SizedBox.shrink()
                  : _CourseBody(
                      course: _course!,
                      venue: _venue,
                      clientDisplay: _clientDisplay,
                      trainerDisplay: _trainerDisplay,
                      documents: _documents,
                      invoice: _invoice,
                      onAssignVenue: _showAssignVenueSheet,
                      onMarkComplete: _confirmMarkComplete,
                      onSetPoNumber: _showSetPoNumberDialog,
                      onUploadDocument: _uploadDocument,
                      onDeleteDocument: _deleteDocument,
                      onCreateInvoice: _showCreateInvoiceSheet,
                    ),
    );
  }
}

// ─── Body ──────────────────────────────────────────────────────────────────────

class _CourseBody extends StatelessWidget {
  final Course course;
  final Venue? venue;
  final String? clientDisplay;
  final String? trainerDisplay;
  final List<CourseDocument> documents;
  final Invoice? invoice;
  final VoidCallback onAssignVenue;
  final VoidCallback onMarkComplete;
  final VoidCallback onSetPoNumber;
  final VoidCallback onUploadDocument;
  final Future<void> Function(CourseDocument) onDeleteDocument;
  final VoidCallback onCreateInvoice;

  const _CourseBody({
    required this.course,
    required this.venue,
    required this.clientDisplay,
    required this.trainerDisplay,
    required this.documents,
    required this.invoice,
    required this.onAssignVenue,
    required this.onMarkComplete,
    required this.onSetPoNumber,
    required this.onUploadDocument,
    required this.onDeleteDocument,
    required this.onCreateInvoice,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _HeroSliverAppBar(course: course),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _ScheduleCard(course: course),
              const SizedBox(height: 12),
              _PeopleCard(
                clientDisplay: clientDisplay ?? course.clientId,
                trainerDisplay: trainerDisplay ?? course.trainerId,
              ),
              const SizedBox(height: 12),
              _VenueCard(venue: venue, onAssign: onAssignVenue),
              const SizedBox(height: 12),
              _PONumberCard(
                  poNumber: course.poNumber, onSet: onSetPoNumber),
              const SizedBox(height: 12),
              _InvoiceCard(
                invoice: invoice,
                onCreateInvoice: onCreateInvoice,
              ),
              if (course.notes != null && course.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _NotesCard(notes: course.notes!),
              ],
              const SizedBox(height: 12),
              _DocumentsCard(
                documents: documents,
                onUpload: onUploadDocument,
                onDelete: onDeleteDocument,
              ),
              if (course.status != 'completed' && course.status != 'declined') ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onMarkComplete,
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text('Mark as Completed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ],
              if (course.status == 'completed') ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'This course has been marked as completed.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D9488),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

// ─── Sliver App Bar / Hero Header ─────────────────────────────────────────────

class _HeroSliverAppBar extends StatelessWidget {
  final Course course;
  const _HeroSliverAppBar({required this.course});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2DB89E), Color(0xFF1A9980)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _StatusBadge(status: course.status),
                  const SizedBox(height: 8),
                  Text(
                    course.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Course #${course.courseNumber}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Schedule Card ─────────────────────────────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final Course course;
  const _ScheduleCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final duration = course.endDate.difference(course.startDate);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final durationStr = hours > 0
        ? (minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h')
        : '${minutes}m';

    return _InfoCard(
      title: 'Schedule',
      children: [
        _InfoRow(
          icon: Icons.play_circle_outline,
          label: 'Start',
          value: _formatDateTime(course.startDate),
        ),
        const _Divider(),
        _InfoRow(
          icon: Icons.stop_circle_outlined,
          label: 'End',
          value: _formatDateTime(course.endDate),
        ),
        const _Divider(),
        _InfoRow(
          icon: Icons.timelapse_outlined,
          label: 'Duration',
          value: durationStr,
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[(dt.month - 1).clamp(0, 11)];
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.day} $month ${dt.year}  ·  $time';
  }
}

// ─── People Card ───────────────────────────────────────────────────────────────

class _PeopleCard extends StatelessWidget {
  final String clientDisplay;
  final String trainerDisplay;
  const _PeopleCard(
      {required this.clientDisplay, required this.trainerDisplay});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'People',
      children: [
        _InfoRow(
          icon: Icons.person_outline,
          label: 'Client',
          value: clientDisplay,
        ),
        const _Divider(),
        _InfoRow(
          icon: Icons.school_outlined,
          label: 'Trainer',
          value: trainerDisplay,
        ),
      ],
    );
  }
}

// ─── Venue Card ────────────────────────────────────────────────────────────────

class _VenueCard extends StatelessWidget {
  final Venue? venue;
  final VoidCallback onAssign;
  const _VenueCard({required this.venue, required this.onAssign});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Venue',
      trailing: TextButton(
        onPressed: onAssign,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          venue == null ? 'Assign' : 'Change',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
      children: venue == null
          ? [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'No venue assigned',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
            ]
          : [
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Name',
                value: venue!.name,
              ),
              if (venue!.address.isNotEmpty) ...[
                const _Divider(),
                _InfoRow(
                  icon: Icons.map_outlined,
                  label: 'Address',
                  value: venue!.address,
                ),
              ],
              if (venue!.capacity != null) ...[
                const _Divider(),
                _InfoRow(
                  icon: Icons.people_outline,
                  label: 'Capacity',
                  value: '${venue!.capacity} people',
                ),
              ],
            ],
    );
  }
}

// ─── Notes Card ────────────────────────────────────────────────────────────────

class _NotesCard extends StatelessWidget {
  final String notes;
  const _NotesCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Notes',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            notes,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── PO Number Card ────────────────────────────────────────────────────────────

class _PONumberCard extends StatelessWidget {
  final String? poNumber;
  final VoidCallback onSet;
  const _PONumberCard({required this.poNumber, required this.onSet});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'PO Number',
      trailing: TextButton(
        onPressed: onSet,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          poNumber == null || poNumber!.isEmpty ? 'Set' : 'Edit',
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary),
        ),
      ),
      children: [
        poNumber != null && poNumber!.isNotEmpty
            ? _InfoRow(
                icon: Icons.confirmation_number_outlined,
                label: 'PO No.',
                value: poNumber!,
              )
            : const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'No PO number assigned',
                    style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
      ],
    );
  }
}

// ─── Shared widgets ────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Widget> children;
  const _InfoCard(
      {required this.title, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                    letterSpacing: 0.3,
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
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
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: Color(0xFFF1F5F9));
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'approved' => ('Approved', const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
      'confirmed' => ('Confirmed', const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
      'pending_trainer' => ('Pending Trainer', const Color(0x33FFFFFF), Colors.white),
      'trainer_declined' => ('Trainer Declined', const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
      'declined' => ('Declined', const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
      'completed' => ('Completed', const Color(0xFFCCFBF1), const Color(0xFF0D9488)),
      _ => (status, const Color(0xFFF1F5F9), const Color(0xFF64748B)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

// ─── Documents Card ────────────────────────────────────────────────────────────

class _DocumentsCard extends StatelessWidget {
  final List<CourseDocument> documents;
  final VoidCallback onUpload;
  final Future<void> Function(CourseDocument) onDelete;

  const _DocumentsCard({
    required this.documents,
    required this.onUpload,
    required this.onDelete,
  });

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Pre-Course Pack',
      trailing: TextButton.icon(
        onPressed: onUpload,
        icon: const Icon(Icons.upload_file_outlined, size: 14),
        label: const Text('Upload'),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      children: documents.isEmpty
          ? [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'No documents uploaded yet',
                    style: TextStyle(
                        fontSize: 14, color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
            ]
          : documents
              .map(
                (doc) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                            Icons.insert_drive_file_outlined,
                            color: AppColors.primary,
                            size: 17),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.fileName,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              DocumentType.label(doc.type),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _openUrl(doc.downloadUrl),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('View',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => onDelete(doc),
                        child: const Icon(Icons.close,
                            size: 16, color: Color(0xFFCBD5E1)),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
    );
  }
}

// ─── Invoice Card ──────────────────────────────────────────────────────────────

class _InvoiceCard extends StatelessWidget {
  final Invoice? invoice;
  final VoidCallback onCreateInvoice;
  const _InvoiceCard(
      {required this.invoice, required this.onCreateInvoice});

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    if (inv == null) {
      return _InfoCard(
        title: 'Invoice',
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'No invoice created yet',
                  style: TextStyle(
                      fontSize: 14, color: Color(0xFF94A3B8)),
                ),
                TextButton.icon(
                  onPressed: onCreateInvoice,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Create'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final (statusLabel, statusBg, statusFg) = switch (inv.status) {
      'paid' => (
          'Paid',
          const Color(0xFFDCFCE7),
          const Color(0xFF16A34A)
        ),
      'sent' => (
          'Sent',
          const Color(0xFFDBEAFE),
          const Color(0xFF2563EB)
        ),
      'overdue' => (
          'Overdue',
          const Color(0xFFFEE2E2),
          const Color(0xFFDC2626)
        ),
      _ => ('Draft', const Color(0xFFF1F5F9), const Color(0xFF64748B)),
    };

    return _InfoCard(
      title: 'Invoice',
      trailing: TextButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InvoiceDetailScreen(invoiceId: inv.id),
            ),
          );
        },
        style: TextButton.styleFrom(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'View →',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary),
        ),
      ),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inv.invoiceNumber,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Due ${_fmtDate(inv.dueDate)}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  '£${inv.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text),
                ),
                const SizedBox(width: 8),
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
                        color: statusFg),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _ErrorBody extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorBody({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          foregroundColor: AppColors.text,
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF94A3B8))),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Retry',
                        style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Venue Picker Sheet ────────────────────────────────────────────────────────

class _VenuePickerSheet extends StatelessWidget {
  final List<Venue> venues;
  final String? currentVenueId;
  final void Function(Venue?) onPick;

  const _VenuePickerSheet({
    required this.venues,
    required this.currentVenueId,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Venue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111111),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 20),
                color: const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
        if (venues.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No venues added yet.\nAdd venues from the Venues screen.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
              ),
            ),
          )
        else ...[
          if (currentVenueId != null)
            _VenueOption(
              name: 'Remove venue assignment',
              address: '',
              isSelected: false,
              isRemove: true,
              onTap: () => onPick(null),
            ),
          ...venues.map((v) => _VenueOption(
                name: v.name,
                address: v.address,
                isSelected: v.id == currentVenueId,
                isRemove: false,
                onTap: () => onPick(v),
              )),
          const SizedBox(height: 12),
        ],
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ],
    );
  }
}

class _VenueOption extends StatelessWidget {
  final String name;
  final String address;
  final bool isSelected;
  final bool isRemove;
  final VoidCallback onTap;

  const _VenueOption({
    required this.name,
    required this.address,
    required this.isSelected,
    required this.isRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isRemove
                    ? const Color(0xFFFEE2E2)
                    : isSelected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isRemove
                    ? Icons.location_off_outlined
                    : Icons.location_on_outlined,
                size: 18,
                color: isRemove
                    ? const Color(0xFFDC2626)
                    : isSelected
                        ? AppColors.primary
                        : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isRemove
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF111111),
                    ),
                  ),
                  if (address.isNotEmpty)
                    Text(
                      address,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF94A3B8)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
