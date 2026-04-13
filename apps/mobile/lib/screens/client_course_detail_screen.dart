import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/course.dart';
import '../models/venue.dart';
import '../providers/auth_provider.dart';

class ClientCourseDetailScreen extends StatefulWidget {
  final Course course;
  final String? venueName; // pre-fetched from dashboard, optional fast-path

  const ClientCourseDetailScreen({
    super.key,
    required this.course,
    this.venueName,
  });

  @override
  State<ClientCourseDetailScreen> createState() =>
      _ClientCourseDetailScreenState();
}

class _ClientCourseDetailScreenState extends State<ClientCourseDetailScreen> {
  bool _loading = true;
  String? _trainerDisplay;
  Venue? _venue;

  // Feedback state
  Map<String, dynamic>? _existingFeedback;
  bool _submittingFeedback = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final futures = <Future>[];

      // Trainer name
      futures.add(
        FirebaseFirestore.instance
            .collection('users')
            .doc(widget.course.trainerId)
            .get(),
      );

      // Venue (if needed)
      Future<DocumentSnapshot?>? venueFuture;
      if (widget.venueName == null &&
          widget.course.venueId != null &&
          widget.course.venueId!.isNotEmpty) {
        venueFuture = FirebaseFirestore.instance
            .collection('venues')
            .doc(widget.course.venueId)
            .get()
            .then((d) => d)
            .catchError((_) => null);
      }

      // Existing feedback (for completed courses)
      Future<DocumentSnapshot?>? feedbackFuture;
      if (widget.course.status == 'completed') {
        feedbackFuture = FirebaseFirestore.instance
            .collection('course_feedback')
            .doc(widget.course.id)
            .get()
            .then((d) => d)
            .catchError((_) => null);
      }

      final trainerDoc = await futures[0] as DocumentSnapshot;
      String? trainerDisplay;
      if (trainerDoc.exists) {
        final data = trainerDoc.data() as Map<String, dynamic>;
        trainerDisplay =
            (data['displayName'] as String?) ?? (data['email'] as String?);
      }

      Venue? venue;
      if (venueFuture != null) {
        final vDoc = await venueFuture;
        if (vDoc != null && vDoc.exists) {
          venue = Venue.fromFirestore(vDoc.id, vDoc.data() as Map<String, dynamic>);
        }
      }

      Map<String, dynamic>? existingFeedback;
      if (feedbackFuture != null) {
        final fDoc = await feedbackFuture;
        if (fDoc != null && fDoc.exists) {
          existingFeedback = fDoc.data() as Map<String, dynamic>;
        }
      }

      if (mounted) {
        setState(() {
          _trainerDisplay = trainerDisplay;
          _venue = venue;
          _existingFeedback = existingFeedback;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _resolvedVenueName {
    if (widget.venueName != null) return widget.venueName!;
    if (_venue != null) {
      return _venue!.address.isNotEmpty
          ? '${_venue!.name} · ${_venue!.address}'
          : _venue!.name;
    }
    return widget.course.venueId != null ? 'Venue assigned' : 'Location TBC';
  }

  // ── Feedback submission ──────────────────────────────────────────────────────

  Future<void> _submitFeedback(int rating, String comment) async {
    final auth = context.read<AuthProvider>();
    setState(() => _submittingFeedback = true);
    try {
      final data = {
        'courseId': widget.course.id,
        'clientId': auth.user!.uid,
        'trainingCompanyId': widget.course.trainingCompanyId,
        'rating': rating,
        'comment': comment.trim(),
        'submittedAt': DateTime.now().toUtc().toIso8601String(),
      };
      await FirebaseFirestore.instance
          .collection('course_feedback')
          .doc(widget.course.id)
          .set(data);
      if (mounted) {
        setState(() {
          _existingFeedback = data;
          _submittingFeedback = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _submittingFeedback = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary))
                : _buildBody(),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final course = widget.course;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2DB89E), Color(0xFF1A9980)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 18),
                  ),
                  Text(
                    'Course #${course.courseNumber}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  _StatusBadge(status: course.status),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  course.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
              if (course.topic != null && course.topic!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    course.topic!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Body ────────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    final course = widget.course;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        children: [
          _buildScheduleCard(course),
          const SizedBox(height: 12),
          _buildTrainerCard(),
          const SizedBox(height: 12),
          _buildVenueCard(),
          if (course.notes != null && course.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildNotesCard(course.notes!),
          ],
          if (course.status == 'completed') ...[
            const SizedBox(height: 24),
            _buildPostCourseSection(course),
          ],
        ],
      ),
    );
  }

  // ── Post-course section ──────────────────────────────────────────────────────

  Widget _buildPostCourseSection(Course course) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'POST-COURSE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF94A3B8),
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        _buildCertificateCard(course),
        const SizedBox(height: 12),
        _buildFeedbackCard(course),
      ],
    );
  }

  Widget _buildCertificateCard(Course course) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _CertificateScreen(
            course: course,
            trainerDisplay: _trainerDisplay,
            venueName: _resolvedVenueName,
          ),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2DB89E), Color(0xFF1A9980)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.workspace_premium_outlined,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'View Certificate',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tap to view your certificate of completion',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(Course course) {
    final hasFeedback = _existingFeedback != null;
    return _InfoCard(
      title: hasFeedback ? 'Your Feedback' : 'Leave Feedback',
      children: hasFeedback
          ? _buildExistingFeedback()
          : _buildFeedbackPrompt(course),
    );
  }

  List<Widget> _buildExistingFeedback() {
    final rating = (_existingFeedback!['rating'] as num?)?.toInt() ?? 0;
    final comment = (_existingFeedback!['comment'] as String?) ?? '';
    return [
      Row(
        children: List.generate(5, (i) {
          return Icon(
            i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
            color: const Color(0xFFF59E0B),
            size: 24,
          );
        }),
      ),
      if (comment.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(
          comment,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF475569),
            height: 1.5,
          ),
        ),
      ],
      const SizedBox(height: 4),
      const Text(
        'Thank you for your feedback.',
        style: TextStyle(
          fontSize: 12,
          color: Color(0xFF94A3B8),
          fontStyle: FontStyle.italic,
        ),
      ),
    ];
  }

  List<Widget> _buildFeedbackPrompt(Course course) {
    return [
      const Text(
        'How was your experience?',
        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      ),
      const SizedBox(height: 14),
      _submittingFeedback
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showFeedbackSheet(),
                icon: const Icon(Icons.rate_review_outlined, size: 18),
                label: const Text('Rate this Course'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
    ];
  }

  void _showFeedbackSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FeedbackSheet(
        onSubmit: (rating, comment) {
          Navigator.pop(context);
          _submitFeedback(rating, comment);
        },
      ),
    );
  }

  // ── Cards ────────────────────────────────────────────────────────────────────

  Widget _buildScheduleCard(Course course) {
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

  Widget _buildTrainerCard() {
    return _InfoCard(
      title: 'Trainer',
      children: [
        _InfoRow(
          icon: Icons.school_outlined,
          label: 'Assigned',
          value: _trainerDisplay ?? 'Not yet assigned',
        ),
      ],
    );
  }

  Widget _buildVenueCard() {
    final hasVenue = widget.course.venueId != null || widget.venueName != null;
    return _InfoCard(
      title: 'Venue',
      children: [
        _InfoRow(
          icon: Icons.location_on_outlined,
          label: 'Location',
          value: _resolvedVenueName,
        ),
        if (_venue?.capacity != null) ...[
          const _Divider(),
          _InfoRow(
            icon: Icons.people_outline,
            label: 'Capacity',
            value: '${_venue!.capacity} people',
          ),
        ],
        if (!hasVenue) ...[
          const SizedBox(height: 4),
          const Text(
            'Your training company will assign a venue closer to the date.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNotesCard(String notes) {
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

// ─── Certificate Screen ────────────────────────────────────────────────────────

class _CertificateScreen extends StatelessWidget {
  final Course course;
  final String? trainerDisplay;
  final String venueName;

  const _CertificateScreen({
    required this.course,
    required this.trainerDisplay,
    required this.venueName,
  });

  String _formatDate(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final recipientName = auth.user?.email?.split('@')[0] ?? 'Participant';

    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Certificate',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: _buildCertificate(context, recipientName),
        ),
      ),
    );
  }

  Widget _buildCertificate(BuildContext context, String recipientName) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2DB89E), Color(0xFF1A9980)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.workspace_premium,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  'CERTIFICATE OF COMPLETION',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'The Training Triangle',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.8),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Certificate body
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
            child: Column(
              children: [
                const Text(
                  'This is to certify that',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  recipientName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'has successfully completed',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF99F6E4)),
                  ),
                  child: Text(
                    course.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF134E4A),
                      height: 1.3,
                    ),
                  ),
                ),
                if (course.topic != null && course.topic!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    course.topic!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
                const SizedBox(height: 28),

                // Details row
                Row(
                  children: [
                    _CertDetail(
                      label: 'DATE',
                      value: _formatDate(course.startDate),
                    ),
                    const SizedBox(width: 12),
                    _CertDetail(
                      label: 'TRAINER',
                      value: trainerDisplay ?? 'Assigned Trainer',
                    ),
                  ],
                ),

                const SizedBox(height: 28),
                Container(
                  height: 1,
                  color: const Color(0xFFE2E8F0),
                ),
                const SizedBox(height: 20),

                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 80,
                          height: 2,
                          color: const Color(0xFF2DB89E),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Authorised Signature',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      course.courseNumber,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CertDetail extends StatelessWidget {
  final String label;
  final String value;
  const _CertDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFF94A3B8),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Feedback Sheet ───────────────────────────────────────────────────────────

class _FeedbackSheet extends StatefulWidget {
  final void Function(int rating, String comment) onSubmit;
  const _FeedbackSheet({required this.onSubmit});

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  int _rating = 0;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Rate this Course',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'How would you rate your overall experience?',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),

            // Star rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _rating;
                return GestureDetector(
                  onTap: () => setState(() => _rating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: filled
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFCBD5E1),
                      size: 42,
                    ),
                  ),
                );
              }),
            ),
            if (_rating > 0) ...[
              const SizedBox(height: 6),
              Center(
                child: Text(
                  ['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'][_rating],
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Comment field
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Share any comments (optional)',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
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
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _rating == 0
                    ? null
                    : () => widget.onSubmit(
                        _rating, _commentController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                child: const Text('Submit Feedback'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared widgets ────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.children});

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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
              ),
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
  const _InfoRow({required this.icon, required this.label, required this.value});

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
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: Color(0xFFF1F5F9));
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'approved' => ('Approved', const Color(0xFFDCFCE7), const Color(0xFF16A34A)),
      'pending_trainer' => ('Pending Trainer', const Color(0x33FFFFFF), Colors.white),
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
