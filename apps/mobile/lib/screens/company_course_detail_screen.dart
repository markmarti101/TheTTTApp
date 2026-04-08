import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/course.dart';
import '../models/venue.dart';
import '../services/courses_service.dart';
import '../services/venues_service.dart';

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

  Course? _course;
  Venue? _venue;
  String? _clientDisplay;
  String? _trainerDisplay;

  bool _loading = true;
  String? _error;
  bool _assigningVenue = false;

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

      setState(() {
        _course = course;
        _venue = venue;
        _clientDisplay = clientDisplay ?? course.clientId;
        _trainerDisplay = trainerDisplay ?? course.trainerId;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load course.';
        _loading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading || _assigningVenue
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
                      onAssignVenue: _showAssignVenueSheet,
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
  final VoidCallback onAssignVenue;

  const _CourseBody({
    required this.course,
    required this.venue,
    required this.clientDisplay,
    required this.trainerDisplay,
    required this.onAssignVenue,
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
              if (course.notes != null && course.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _NotesCard(notes: course.notes!),
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
      'pending_trainer' => ('Pending Trainer', const Color(0x33FFFFFF), Colors.white),
      'declined' => ('Declined', const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
      'completed' => ('Completed', const Color(0xFFDBEAFE), const Color(0xFF2563EB)),
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
