import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/course.dart';
import '../services/trainer_profile_service.dart';
import 'paperwork_screen.dart';

class TrainerCourseDetailScreen extends StatefulWidget {
  final Course course;
  final String trainerId;
  final String? venueName;

  const TrainerCourseDetailScreen({
    super.key,
    required this.course,
    required this.trainerId,
    this.venueName,
  });

  @override
  State<TrainerCourseDetailScreen> createState() =>
      _TrainerCourseDetailScreenState();
}

class _TrainerCourseDetailScreenState
    extends State<TrainerCourseDetailScreen> {
  final _profileService = TrainerProfileService();

  List<CourseNote> _notes = [];
  bool _loadingNotes = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _loadingNotes = true);
    final notes = await _profileService.getCourseNotes(
        widget.trainerId, widget.course.id);
    if (mounted) setState(() { _notes = notes; _loadingNotes = false; });
  }

  Future<void> _showAddNoteSheet() async {
    final ctrl = TextEditingController();
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Note',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Write your note here...',
                  hintStyle: const TextStyle(color: Color(0xFFB0BEC5)),
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
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final text = ctrl.text.trim();
                          if (text.isEmpty) return;
                          setSheet(() => saving = true);
                          await _profileService.addCourseNote(
                              widget.trainerId, widget.course.id, text);
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _loadNotes();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save Note',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteNote(String noteId) async {
    await _profileService.deleteCourseNote(
        widget.trainerId, widget.course.id, noteId);
    await _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.course;
    final start = c.startDate;
    final end = c.endDate;

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    final dateLabel =
        '${start.day} ${months[start.month - 1]} ${start.year}';
    final timeLabel =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}'
        ' – '
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';

    final statusLabel = switch (c.status) {
      'confirmed' => 'Confirmed',
      'completed' => 'Completed',
      'pending_trainer' => 'Pending',
      'declined' || 'trainer_declined' => 'Declined',
      _ => c.status,
    };

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
          'Course Details',
          style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w800,
              fontSize: 20),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PaperworkScreen(
                  courseId: c.id,
                  courseNumber: c.courseNumber,
                  courseTitle: c.title,
                  trainingCompanyId: '',
                  trainerId: widget.trainerId,
                ),
              ),
            ),
            icon: const Icon(Icons.description_outlined,
                size: 16, color: AppColors.primary),
            label: const Text(
              'Paperwork',
              style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2DB89E), Color(0xFF1A9980)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.title,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    c.courseNumber,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Details card
            _card([
              _detailRow(Icons.calendar_today_outlined, 'Date', dateLabel),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _detailRow(Icons.access_time_outlined, 'Time', timeLabel),
              if (widget.venueName != null &&
                  widget.venueName!.isNotEmpty) ...[
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _detailRow(Icons.location_on_outlined, 'Venue',
                    widget.venueName!),
              ],
              if (c.notes != null && c.notes!.isNotEmpty) ...[
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _detailRow(
                    Icons.info_outline, 'Info', c.notes!),
              ],
            ]),
            const SizedBox(height: 20),

            // Notes section label
            Row(
              children: [
                _sectionLabel('NOTES'),
                const Spacer(),
                GestureDetector(
                  onTap: _showAddNoteSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '+ Add Note',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Notes list
            _loadingNotes
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    ),
                  )
                : _notes.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: const Color(0xFFE0E0E0)),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.notes_outlined,
                                size: 36,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.4)),
                            const SizedBox(height: 8),
                            Text(
                              'No notes yet',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "+ Add Note" to log something about this course',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.7)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: _notes
                            .map((note) => _noteCard(note))
                            .toList(),
                      ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _noteCard(CourseNote note) {
    final dt = DateTime.tryParse(note.createdAt);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final timeStr = dt != null
        ? '${dt.day} ${months[dt.month - 1]} ${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  note.text,
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.text,
                      height: 1.5),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Note'),
                      content:
                          const Text('Remove this note permanently?'),
                      actions: [
                        TextButton(
                            onPressed: () =>
                                Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        TextButton(
                            onPressed: () =>
                                Navigator.pop(ctx, true),
                            child: const Text('Delete',
                                style: TextStyle(
                                    color: Color(0xFFE53935)))),
                      ],
                    ),
                  );
                  if (confirm == true) _deleteNote(note.id);
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.delete_outline,
                      size: 18, color: Color(0xFFCBD5E1)),
                ),
              ),
            ],
          ),
          if (timeStr.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              timeStr,
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500),
            ),
          ],
        ],
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

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 52,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.text,
                    fontWeight: FontWeight.w600)),
          ),
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
}
