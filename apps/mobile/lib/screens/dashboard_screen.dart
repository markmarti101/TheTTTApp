import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../models/course.dart';
import '../models/course_request.dart';
import '../services/courses_service.dart';
import '../services/requests_service.dart';
import '../services/client_invites_service.dart';
import '../services/trainer_invites_service.dart';
import '../services/trainer_profile_service.dart';
import 'course_request_screen.dart';
import 'client_requests_screen.dart';
import 'client_delegates_tab.dart';
import 'client_course_detail_screen.dart';

// ─── Root ─────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _coursesService = CoursesService();
  final _requestsService = RequestsService();

  int _tab = 0;
  bool _dataLoaded = false;
  bool _dataLoading = false;
  List<Course> _courses = [];
  List<CourseRequest> _requests = [];
  String? _companyName;
  Map<String, String> _venueNames = {}; // venueId → "Name · Address"

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (auth.role == 'client' &&
        (auth.trainingCompanyId?.isNotEmpty == true) &&
        !_dataLoaded &&
        !_dataLoading) {
      _loadData(auth);
    }
  }

  Future<void> _loadData(AuthProvider auth) async {
    setState(() => _dataLoading = true);
    final uid = auth.user!.uid;
    final companyId = auth.trainingCompanyId!;
    try {
      final coursesFuture = _coursesService.getCoursesByClient(uid);
      final requestsFuture = _requestsService.getRequestsByClient(uid);
      final courses = await coursesFuture;
      final requests = await requestsFuture;

      // Fetch company name separately — permission may not be ready yet.
      String? fetchedCompanyName;
      try {
        final snap = await FirebaseFirestore.instance
            .collection('training_companies')
            .doc(companyId)
            .get();
        fetchedCompanyName = snap.data()?['name'] as String?;
      } catch (_) {}

      // Fetch venue names for all courses that have a venueId
      final venueIds = courses
          .map((c) => c.venueId)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
      final venueNames = <String, String>{};
      for (final id in venueIds) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('venues')
              .doc(id)
              .get();
          if (doc.exists) {
            final data = doc.data()!;
            final name = (data['name'] as String?) ?? '';
            final address = (data['address'] as String?) ?? '';
            venueNames[id] = address.isNotEmpty ? '$name · $address' : name;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _courses = courses;
          _requests = requests;
          _companyName = fetchedCompanyName ?? 'Your Company';
          _venueNames = venueNames;
          _dataLoaded = true;
          _dataLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('[DashboardScreen] _loadData error: $e\n$st');
      // Mark as loaded even on error so the UI doesn't spin forever.
      if (mounted) setState(() { _dataLoading = false; _dataLoaded = true; });
    }
  }

  Future<void> _refresh(AuthProvider auth) async {
    setState(() => _dataLoaded = false);
    await _loadData(auth);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final role = auth.role ?? '';

    if (role == 'freelance_trainer') {
      return _FreelancerScreen(auth: auth);
    }

    if (auth.trainingCompanyId == null || auth.trainingCompanyId!.isEmpty) {
      return _UnlinkedClientScreen(auth: auth);
    }

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final upcoming = _courses
        .where((c) =>
            c.startDate.isAfter(thirtyDaysAgo) &&
            c.status != 'completed' &&
            c.status != 'declined' &&
            c.status != 'trainer_declined')
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final past = _courses
        .where((c) => c.status == 'completed')
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    final pastCount = past.length;
    final activeRequests = _requests
        .where((r) => r.status == 'pending' || r.status == 'reviewed')
        .toList();
    final isNew = _dataLoaded && _courses.isEmpty && _requests.isEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _tab == 0
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(
          index: _tab,
          children: [
            _HomeTab(
              auth: auth,
              upcoming: upcoming,
              past: past,
              pastCount: pastCount,
              activeRequests: activeRequests,
              companyName: _companyName,
              isNew: isNew,
              dataLoaded: _dataLoaded,
              dataLoading: _dataLoading,
              venueNames: _venueNames,
              onRefresh: () => _refresh(auth),
              onGoToBookings: () => setState(() => _tab = 1),
            ),
            ClientRequestsScreen(
              requests: _requests,
              loading: _dataLoading && !_dataLoaded,
              onRefresh: () => _refresh(auth),
            ),
            ClientDelegatesTab(clientId: auth.user!.uid),
            _ProfileTab(auth: auth),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: const Color(0xFFBBBBBB),
          backgroundColor: Colors.white,
          elevation: 12,
          selectedLabelStyle: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: activeRequests.isNotEmpty
                  ? Badge(
                      label: Text('${activeRequests.length}'),
                      child: const Icon(Icons.calendar_today_outlined),
                    )
                  : const Icon(Icons.calendar_today_outlined),
              activeIcon: const Icon(Icons.calendar_today),
              label: 'Bookings',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.group_outlined),
              activeIcon: Icon(Icons.group),
              label: 'Delegates',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Home Tab ─────────────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  final AuthProvider auth;
  final List<Course> upcoming;
  final List<Course> past;
  final int pastCount;
  final List<CourseRequest> activeRequests;
  final String? companyName;
  final bool isNew;
  final bool dataLoaded;
  final bool dataLoading;
  final Map<String, String> venueNames;
  final VoidCallback onRefresh;
  final VoidCallback onGoToBookings;

  const _HomeTab({
    required this.auth,
    required this.upcoming,
    required this.past,
    required this.pastCount,
    required this.activeRequests,
    required this.companyName,
    required this.isNew,
    required this.dataLoaded,
    required this.dataLoading,
    required this.venueNames,
    required this.onRefresh,
    required this.onGoToBookings,
  });

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _displayName {
    final email = auth.user?.email ?? '';
    return email.contains('@') ? email.split('@')[0] : 'there';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => onRefresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsRow(),
                  if (dataLoading)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ),
                    )
                  else if (isNew)
                    _buildEmptyState(context)
                  else
                    _buildActiveContent(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _displayName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 2),
                    ),
                    child: Center(
                      child: Text(
                        _displayName.isNotEmpty
                            ? _displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Company pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.business,
                          color: Colors.white, size: 13),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      companyName ?? '...',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.check_circle,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 13),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          _StatCard(
              value: upcoming.length,
              label: 'Upcoming',
              color: AppColors.primary),
          const SizedBox(width: 10),
          _StatCard(
              value: activeRequests.length,
              label: 'Pending',
              color: const Color(0xFFF59E0B)),
          const SizedBox(width: 10),
          _StatCard(
              value: pastCount,
              label: 'Completed',
              color: const Color(0xFF64748B)),
        ],
      ),
    );
  }

  Widget _buildActiveContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (upcoming.isNotEmpty) ...[
          _SectionHeader(
            title: 'Upcoming Courses',
            onSeeAll: onGoToBookings,
          ),
          ...upcoming.take(3).map((c) => _CourseCard(
                course: c,
                venueName: venueNames[c.venueId ?? ''],
                onReturn: onRefresh,
              )),
        ],
        if (activeRequests.isNotEmpty) ...[
          _SectionHeader(
            title: 'My Requests',
            onSeeAll: onGoToBookings,
          ),
          ...activeRequests
              .take(3)
              .map((r) => _RequestCard(request: r)),
        ],
        if (past.isNotEmpty) ...[
          const _SectionHeader(title: 'Past Courses'),
          ...past.take(5).map((c) => _CourseCard(
                course: c,
                venueName: venueNames[c.venueId ?? ''],
                onReturn: onRefresh,
                showFeedbackBadge: true,
              )),
        ],
        _buildQuickActions(context, muted: false),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF0F0F0)),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Icon(Icons.inbox_outlined,
                      color: AppColors.primary, size: 32),
                ),
                const SizedBox(height: 14),
                const Text(
                  'No upcoming sessions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your confirmed bookings will appear here\nonce your training company schedules them.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CourseRequestScreen()),
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
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined, size: 28, color: Colors.white),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Request your first session',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Submit a training request to get started',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,
                      color: Colors.white.withValues(alpha: 0.8), size: 16),
                ],
              ),
            ),
          ),
        ),
        _buildQuickActions(context, muted: true),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, {required bool muted}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.calendar_month_outlined,
                  title: 'Request Training',
                  subtitle: 'Book a new session',
                  primary: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CourseRequestScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Opacity(
                  opacity: muted ? 0.45 : 1.0,
                  child: _ActionTile(
                    icon: Icons.group_outlined,
                    title: 'Delegates',
                    subtitle: 'Manage your team',
                    primary: false,
                    onTap: () {},
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Opacity(
                  opacity: muted ? 0.45 : 1.0,
                  child: _ActionTile(
                    icon: Icons.description_outlined,
                    title: 'Documents',
                    subtitle: 'Certs & reports',
                    primary: false,
                    onTap: () {},
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Opacity(
                  opacity: muted ? 0.45 : 1.0,
                  child: _ActionTile(
                    icon: Icons.history_outlined,
                    title: 'History',
                    subtitle: 'Past bookings',
                    primary: false,
                    onTap: () {},
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Unlinked Client Screen ───────────────────────────────────────────────────

class _UnlinkedClientScreen extends StatefulWidget {
  final AuthProvider auth;
  const _UnlinkedClientScreen({required this.auth});

  @override
  State<_UnlinkedClientScreen> createState() => _UnlinkedClientScreenState();
}

class _UnlinkedClientScreenState extends State<_UnlinkedClientScreen> {
  final _invitesService = ClientInvitesService();
  bool _claiming = false;
  String? _claimMessage;

  Future<void> _claimInvite() async {
    final email = widget.auth.user?.email;
    final uid = widget.auth.user?.uid;
    if (email == null || uid == null) return;
    setState(() {
      _claiming = true;
      _claimMessage = null;
    });
    try {
      final invite = await _invitesService.claimInviteForEmail(
        uid: uid,
        email: email,
      );
      if (!mounted) return;
      if (invite == null) {
        setState(() {
          _claimMessage =
              'No pending invite found for $email. Ask your training company to add you first.';
          _claiming = false;
        });
        return;
      }
      await widget.auth.linkClientToCompany(
          uid, invite['companyId'] as String);
      if (mounted) setState(() => _claiming = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _claimMessage = 'Something went wrong. Please try again.';
          _claiming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.auth.user?.email ?? '';
    final displayName =
        email.contains('@') ? email.split('@')[0] : 'there';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => widget.auth.signOut(),
                      child: Text(
                        'Sign Out',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.link_off_rounded,
                            color: AppColors.primary, size: 36),
                        const SizedBox(height: 12),
                        const Text(
                          'Not linked to a company',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111111)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your training company needs to add your email address first. Once they have, tap below to link your account.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        if (_claimMessage != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _claimMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  _claimMessage!.startsWith('No pending')
                                      ? Colors.orange.shade700
                                      : Colors.red.shade600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                _claiming ? null : _claimInvite,
                            icon: _claiming
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : const Icon(Icons.link_rounded),
                            label: Text(_claiming
                                ? 'Linking...'
                                : 'Link to My Training Company'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
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
}

// ─── Freelancer Dashboard ─────────────────────────────────────────────────────

class _FreelancerScreen extends StatefulWidget {
  final AuthProvider auth;
  const _FreelancerScreen({required this.auth});

  @override
  State<_FreelancerScreen> createState() => _FreelancerScreenState();
}

class _FreelancerScreenState extends State<_FreelancerScreen> {
  final _coursesService = CoursesService();
  final _profileService = TrainerProfileService();
  final _trainerInvitesService = TrainerInvitesService();

  int _tab = 0;
  bool _loading = true;
  List<Course> _invitations = [];
  List<Course> _upcoming = [];
  List<Course> _allCourses = [];
  Map<String, String> _venueNames = {};
  final Set<String> _actionLoading = {};
  List<TrainerQualification> _qualifications = [];
  ComplianceData _compliance = ComplianceData();
  String? _companyName;
  List<Map<String, dynamic>> _pendingCompanyInvites = [];
  final Set<String> _inviteActionLoading = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = widget.auth.user?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final courses = await _coursesService.getCoursesByTrainer(uid);
      final now = DateTime.now();

      final invitations = courses
          .where((c) => c.status == 'pending_trainer')
          .toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));

      final upcoming = courses
          .where((c) => c.status == 'confirmed' && c.endDate.isAfter(now))
          .toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));

      final venueIds = courses
          .map((c) => c.venueId)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
      final venueNames = <String, String>{};
      for (final id in venueIds) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('venues')
              .doc(id)
              .get();
          if (doc.exists) {
            venueNames[id] = (doc.data()?['name'] as String?) ?? '';
          }
        } catch (_) {}
      }

      final qualifications =
          await _profileService.getQualifications(uid);
      final compliance = await _profileService.getCompliance(uid);

      String? companyName;
      final companyId = widget.auth.trainingCompanyId;
      if (companyId != null && companyId.isNotEmpty) {
        try {
          final companyDoc = await FirebaseFirestore.instance
              .collection('training_companies')
              .doc(companyId)
              .get();
          companyName = companyDoc.data()?['name'] as String?;
        } catch (_) {}
      }

      // Fetch pending company invites (only when not yet linked to a company).
      List<Map<String, dynamic>> pendingCompanyInvites = [];
      if ((companyId == null || companyId.isEmpty) &&
          widget.auth.user?.email != null) {
        try {
          pendingCompanyInvites = await _trainerInvitesService
              .getPendingInvitesForEmail(widget.auth.user!.email!);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _allCourses = courses;
          _invitations = invitations;
          _upcoming = upcoming;
          _venueNames = venueNames;
          _qualifications = qualifications;
          _compliance = compliance;
          _companyName = companyName;
          _pendingCompanyInvites = pendingCompanyInvites;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept(String courseId) async {
    setState(() => _actionLoading.add(courseId));
    try {
      await _coursesService.acceptJob(courseId);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _actionLoading.remove(courseId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to accept. Please try again.')),
        );
      }
    }
  }

  Future<void> _decline(String courseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline Job'),
        content: const Text('Are you sure you want to decline this job?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE53935)),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _actionLoading.add(courseId));
    try {
      await _coursesService.declineJob(courseId);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _actionLoading.remove(courseId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to decline. Please try again.')),
        );
      }
    }
  }

  String _resolveFirstName() {
    final dn = widget.auth.user?.displayName?.trim();
    if (dn != null && dn.isNotEmpty) {
      return dn.split(RegExp(r'\s+')).first;
    }
    final email = widget.auth.user?.email ?? '';
    if (email.contains('@')) {
      final local = email.split('@').first;
      final match = RegExp(r'^([a-zA-Z]+)').firstMatch(local);
      if (match != null) {
        final n = match.group(1)!;
        return n[0].toUpperCase() + n.substring(1).toLowerCase();
      }
    }
    return 'Trainer';
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Good morning';
    if (h >= 12 && h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: [
            _buildJobsTab(),
            _buildTrainerCalendarTab(),
            _buildTrainerProfileTab(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: const Color(0xFFBBBBBB),
        backgroundColor: Colors.white,
        elevation: 12,
        selectedLabelStyle:
            const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        items: [
          BottomNavigationBarItem(
            icon: _invitations.isNotEmpty
                ? Badge(
                    label: Text('${_invitations.length}'),
                    child: const Icon(Icons.work_outline),
                  )
                : const Icon(Icons.work_outline),
            activeIcon: const Icon(Icons.work),
            label: 'Jobs',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildJobsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        Expanded(
          child: _loading
              ? const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primary))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: _buildBody(),
                ),
        ),
      ],
    );
  }

  Widget _buildTrainerCalendarTab() {
    final sorted = [..._allCourses]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    const monthsShort = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];

    // Group by year-month
    final grouped = <String, List<Course>>{};
    for (final c in sorted) {
      final key = '${months[c.startDate.month - 1]} ${c.startDate.year}';
      grouped.putIfAbsent(key, () => []).add(c);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: const Text(
            'Calendar',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.text),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary))
              : sorted.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 48,
                                color: const Color(0xFFCCCCCC)),
                            const SizedBox(height: 12),
                            Text(
                              'No courses scheduled',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView(
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        children: grouped.entries.map((entry) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: 16, bottom: 8),
                                child: Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: AppColors.textSecondary
                                        .withValues(alpha: 0.85),
                                  ),
                                ),
                              ),
                              ...entry.value.map((c) {
                                final s = c.startDate;
                                final time =
                                    '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';
                                final venue = c.venueId != null
                                    ? _venueNames[c.venueId]
                                    : null;
                                final isPending =
                                    c.status == 'pending_trainer';
                                final statusLabel =
                                    isPending ? 'Pending' : 'Confirmed';
                                final statusColor = isPending
                                    ? AppColors.primary
                                    : const Color(0xFF1B6B4A);
                                final statusBg = isPending
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : const Color(0xFFE8F7F2);

                                return Container(
                                  margin:
                                      const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.04),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 74,
                                        decoration: BoxDecoration(
                                          color: isPending
                                              ? AppColors.primary
                                              : AppColors.primary,
                                          borderRadius:
                                              const BorderRadius.only(
                                            topLeft: Radius.circular(14),
                                            bottomLeft:
                                                Radius.circular(14),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '${s.day}',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                              color: isPending
                                                  ? AppColors.primary
                                                  : AppColors.primary,
                                            ),
                                          ),
                                          Text(
                                            monthsShort[s.month - 1],
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                          width: 1,
                                          height: 44,
                                          color:
                                              const Color(0xFFF0F0F0)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      c.title,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Color(
                                                            0xFF111111),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 7,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: statusBg,
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(
                                                                  20),
                                                    ),
                                                    child: Text(
                                                      statusLabel,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: statusColor,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                      Icons
                                                          .access_time_outlined,
                                                      size: 12,
                                                      color: AppColors
                                                          .textSecondary),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    time,
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: AppColors
                                                            .textSecondary),
                                                  ),
                                                  if (venue != null &&
                                                      venue.isNotEmpty) ...[
                                                    const SizedBox(
                                                        width: 10),
                                                    Icon(
                                                        Icons
                                                            .location_on_outlined,
                                                        size: 12,
                                                        color: AppColors
                                                            .textSecondary),
                                                    const SizedBox(width: 3),
                                                    Expanded(
                                                      child: Text(
                                                        venue,
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color: AppColors
                                                                .textSecondary),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildTrainerProfileTab() {
    final auth = widget.auth;
    final email = auth.user?.email ?? '';
    final name = _resolveFirstName();
    final initials = name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.isNotEmpty
            ? '${name[0]}${name[0]}'.toUpperCase()
            : '?';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Profile',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF0F0F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Freelance Trainer',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Company link card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF0F0F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _companyName != null
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _companyName != null
                          ? Icons.business_outlined
                          : Icons.link_off_outlined,
                      size: 18,
                      color: _companyName != null
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
                          _companyName != null ? 'Linked Company' : 'No Company Linked',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _companyName ?? 'You haven\'t been invited yet',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _companyName != null
                                ? AppColors.text
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_companyName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F7F2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B6B4A),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF0F0F0)),
              ),
              child: Column(
                children: [
                  _profileStatRow(
                    Icons.work_outline,
                    'Total Jobs',
                    '${_allCourses.length}',
                  ),
                  Divider(height: 1, color: const Color(0xFFF0F0F0)),
                  _profileStatRow(
                    Icons.pending_outlined,
                    'Pending Invitations',
                    '${_invitations.length}',
                  ),
                  Divider(height: 1, color: const Color(0xFFF0F0F0)),
                  _profileStatRow(
                    Icons.check_circle_outline,
                    'Upcoming Confirmed',
                    '${_upcoming.length}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildQualificationsSection(),
            const SizedBox(height: 16),
            _buildComplianceSection(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => auth.signOut(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Sign Out',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualificationsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Qualifications',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111)),
                ),
              ),
              GestureDetector(
                onTap: _showAddQualificationSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '+ Add',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_qualifications.isEmpty)
            Text(
              'No qualifications added yet.\nAdd your certifications, DBS, and insurance details.',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5),
            )
          else
            ..._qualifications.map((q) {
              final expiry = DateTime.tryParse(q.expiryDate);
              final now = DateTime.now();
              final isExpired =
                  expiry != null && expiry.isBefore(now);
              final isExpiringSoon = expiry != null &&
                  !isExpired &&
                  expiry.isBefore(
                      now.add(const Duration(days: 60)));
              final iconColor = isExpired
                  ? const Color(0xFFDC2626)
                  : isExpiringSoon
                      ? const Color(0xFFD97706)
                      : AppColors.primary;
              final bgColor = isExpired
                  ? const Color(0xFFFFF1F2)
                  : isExpiringSoon
                      ? const Color(0xFFFFFBEB)
                      : const Color(0xFFF8FAFC);
              final borderColor = isExpired
                  ? const Color(0xFFFECACA)
                  : isExpiringSoon
                      ? const Color(0xFFFDE68A)
                      : const Color(0xFFE2E8F0);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified_outlined,
                        size: 18, color: iconColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(q.title,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111111))),
                          if (q.issuer != null &&
                              q.issuer!.isNotEmpty)
                            Text(q.issuer!,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8))),
                          Text(
                            'Expires: ${_fmtDate(q.expiryDate)}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: iconColor),
                          ),
                        ],
                      ),
                    ),
                    if (isExpired)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('EXPIRED',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFDC2626))),
                      )
                    else if (isExpiringSoon)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('SOON',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFD97706))),
                      ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        final uid =
                            widget.auth.user?.uid ?? '';
                        await _profileService
                            .deleteQualification(uid, q.id);
                        await _load();
                      },
                      child: const Icon(Icons.close,
                          size: 16, color: Color(0xFFCBD5E1)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Compliance helpers ────────────────────────────────────────────────────

  bool _isExpired(String? iso) {
    if (iso == null || iso.isEmpty) return false;
    final dt = DateTime.tryParse(iso);
    return dt != null && dt.isBefore(DateTime.now());
  }

  bool _isExpiringSoon(String? iso) {
    if (iso == null || iso.isEmpty) return false;
    final dt = DateTime.tryParse(iso);
    if (dt == null) return false;
    final now = DateTime.now();
    return !dt.isBefore(now) && dt.isBefore(now.add(const Duration(days: 60)));
  }

  /// Returns a warning message if any compliance document is expired/expiring.
  String? _complianceAlertMessage() {
    final issues = <String>[];
    final dbs = _compliance.dbs;
    final ins = _compliance.insurance;
    if (dbs == null || (dbs.certificateNumber == null && dbs.expiryDate == null)) {
      issues.add('DBS not recorded');
    } else if (_isExpired(dbs.expiryDate)) {
      issues.add('DBS expired');
    } else if (_isExpiringSoon(dbs.expiryDate)) {
      issues.add('DBS expiring soon');
    }
    if (ins == null || (ins.provider == null && ins.expiryDate == null)) {
      issues.add('Insurance not recorded');
    } else if (_isExpired(ins.expiryDate)) {
      issues.add('Insurance expired');
    } else if (_isExpiringSoon(ins.expiryDate)) {
      issues.add('Insurance expiring soon');
    }
    if (issues.isEmpty) return null;
    return issues.join(' · ');
  }

  Widget _buildComplianceAlertBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 18, color: Color(0xFFD97706)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _tab = 2),
            child: const Text(
              'Update',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD97706),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Compliance section (Profile tab) ────────────────────────────────────

  String _dbsSummary() {
    final dbs = _compliance.dbs;
    if (dbs == null) return 'Not recorded';
    if (dbs.certificateNumber != null && dbs.certificateNumber!.isNotEmpty) {
      return dbs.certificateNumber!;
    }
    return 'Recorded';
  }

  String _insuranceSummary() {
    final ins = _compliance.insurance;
    if (ins == null) return 'Not recorded';
    if (ins.provider != null && ins.provider!.isNotEmpty) {
      return ins.provider!;
    }
    return 'Recorded';
  }

  Widget _buildComplianceSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Compliance',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111)),
          ),
          const SizedBox(height: 14),
          _buildComplianceRow(
            icon: Icons.security_outlined,
            label: 'DBS Certificate',
            summary: _dbsSummary(),
            expiryDate: _compliance.dbs?.expiryDate,
            onEdit: _showEditDBSDialog,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1, color: Color(0xFFF0F0F0)),
          ),
          _buildComplianceRow(
            icon: Icons.policy_outlined,
            label: 'Insurance',
            summary: _insuranceSummary(),
            expiryDate: _compliance.insurance?.expiryDate,
            onEdit: _showEditInsuranceDialog,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'CPD Log',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569)),
                ),
              ),
              GestureDetector(
                onTap: _showAddCPDDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '+ Add',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_compliance.cpd.isEmpty)
            Text(
              'No CPD entries yet.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            )
          else
            ..._compliance.cpd.map(_buildCPDRow),
        ],
      ),
    );
  }

  Widget _buildComplianceRow({
    required IconData icon,
    required String label,
    required String summary,
    required String? expiryDate,
    required VoidCallback onEdit,
  }) {
    final expired = _isExpired(expiryDate);
    final soon = _isExpiringSoon(expiryDate);
    final iconColor = expired
        ? const Color(0xFFDC2626)
        : soon
            ? const Color(0xFFD97706)
            : AppColors.primary;

    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111111))),
              const SizedBox(height: 2),
              Text(summary,
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              if (expiryDate != null && expiryDate.isNotEmpty)
                Text(
                  '${expired ? 'Expired' : 'Expires'}: ${_fmtDate(expiryDate)}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: iconColor),
                ),
            ],
          ),
        ),
        if (expired)
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('EXPIRED',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFDC2626))),
          )
        else if (soon)
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('SOON',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD97706))),
          ),
        GestureDetector(
          onTap: onEdit,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Edit',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCPDRow(CPDEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.school_outlined,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111111))),
                Row(
                  children: [
                    if (entry.provider != null &&
                        entry.provider!.isNotEmpty)
                      Text(
                        entry.provider!,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    if (entry.provider != null &&
                        entry.provider!.isNotEmpty)
                      const Text(' · ',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8))),
                    Text(
                      _fmtDate(entry.completedDate),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                    if (entry.hours != null)
                      Text(
                        ' · ${entry.hours}h',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              final uid = widget.auth.user?.uid ?? '';
              await _profileService.deleteCPDEntry(uid, entry.id);
              await _load();
            },
            child: const Icon(Icons.close,
                size: 16, color: Color(0xFFCBD5E1)),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDBSDialog() async {
    final uid = widget.auth.user?.uid ?? '';
    final certCtrl = TextEditingController(
        text: _compliance.dbs?.certificateNumber ?? '');
    DateTime? expiryDate = DateTime.tryParse(
        _compliance.dbs?.expiryDate ?? '');

    final result =
        await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
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
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text('DBS Certificate',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _sheetField(certCtrl, 'Certificate Number',
                  'e.g. 001234567890'),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: expiryDate ??
                        DateTime.now()
                            .add(const Duration(days: 365)),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2040),
                    builder: (c, child) => Theme(
                      data: ThemeData.light().copyWith(
                        colorScheme: const ColorScheme.light(
                            primary: AppColors.primary),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setSheetState(() => expiryDate = picked);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 18, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 10),
                      Text(
                        expiryDate != null
                            ? 'Expires: ${_fmtDate(expiryDate!.toIso8601String())}'
                            : 'Select expiry date',
                        style: TextStyle(
                          fontSize: 13,
                          color: expiryDate != null
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx, {
                      'cert': certCtrl.text.trim(),
                      'expiry': expiryDate
                              ?.toIso8601String()
                              .substring(0, 10) ??
                          '',
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(14)),
                  ),
                  child: const Text('Save',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;
    try {
      await _profileService.setDBS(
          uid,
          DBSRecord(
            certificateNumber: result['cert'] as String?,
            expiryDate: result['expiry'] as String?,
          ));
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('DBS details saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save DBS: $e')),
        );
      }
    }
  }

  Future<void> _showEditInsuranceDialog() async {
    final uid = widget.auth.user?.uid ?? '';
    final providerCtrl = TextEditingController(
        text: _compliance.insurance?.provider ?? '');
    final policyCtrl = TextEditingController(
        text: _compliance.insurance?.policyNumber ?? '');
    DateTime? expiryDate = DateTime.tryParse(
        _compliance.insurance?.expiryDate ?? '');

    final result =
        await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
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
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Insurance',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _sheetField(providerCtrl, 'Insurance Provider',
                  'e.g. Hiscox'),
              const SizedBox(height: 12),
              _sheetField(policyCtrl, 'Policy Number',
                  'e.g. POL-001234'),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: expiryDate ??
                        DateTime.now()
                            .add(const Duration(days: 365)),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2040),
                    builder: (c, child) => Theme(
                      data: ThemeData.light().copyWith(
                        colorScheme: const ColorScheme.light(
                            primary: AppColors.primary),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setSheetState(() => expiryDate = picked);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 18, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 10),
                      Text(
                        expiryDate != null
                            ? 'Expires: ${_fmtDate(expiryDate!.toIso8601String())}'
                            : 'Select expiry date',
                        style: TextStyle(
                          fontSize: 13,
                          color: expiryDate != null
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx, {
                      'provider': providerCtrl.text.trim(),
                      'policy': policyCtrl.text.trim(),
                      'expiry': expiryDate
                              ?.toIso8601String()
                              .substring(0, 10) ??
                          '',
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(14)),
                  ),
                  child: const Text('Save',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;
    try {
      await _profileService.setInsurance(
          uid,
          InsuranceRecord(
            provider: (result['provider'] as String?)?.isEmpty ?? true
                ? null
                : result['provider'] as String,
            policyNumber: (result['policy'] as String?)?.isEmpty ?? true
                ? null
                : result['policy'] as String,
            expiryDate: (result['expiry'] as String?)?.isEmpty ?? true
                ? null
                : result['expiry'] as String,
          ));
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insurance details saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save insurance: $e')),
        );
      }
    }
  }

  Future<void> _showAddCPDDialog() async {
    final uid = widget.auth.user?.uid ?? '';
    final titleCtrl = TextEditingController();
    final providerCtrl = TextEditingController();
    final hoursCtrl = TextEditingController();
    DateTime? completedDate;

    final result =
        await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
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
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add CPD Entry',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _sheetField(titleCtrl, 'Activity Title',
                  'e.g. Safeguarding Level 2'),
              const SizedBox(height: 12),
              _sheetField(providerCtrl, 'Provider (optional)',
                  'e.g. NSPCC'),
              const SizedBox(height: 12),
              _sheetField(hoursCtrl, 'Hours (optional)',
                  'e.g. 6'),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    builder: (c, child) => Theme(
                      data: ThemeData.light().copyWith(
                        colorScheme: const ColorScheme.light(
                            primary: AppColors.primary),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setSheetState(() => completedDate = picked);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 18, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 10),
                      Text(
                        completedDate != null
                            ? 'Completed: ${_fmtDate(completedDate!.toIso8601String())}'
                            : 'Select completion date',
                        style: TextStyle(
                          fontSize: 13,
                          color: completedDate != null
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty || completedDate == null) return;
                    Navigator.pop(ctx, {
                      'title': title,
                      'provider': providerCtrl.text.trim(),
                      'hours': hoursCtrl.text.trim(),
                      'completed': completedDate!
                          .toIso8601String()
                          .substring(0, 10),
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(14)),
                  ),
                  child: const Text('Add Entry',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;
    final hours = double.tryParse(result['hours'] as String? ?? '');
    final entry = CPDEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: result['title'] as String,
      provider: (result['provider'] as String?)?.isEmpty ?? true
          ? null
          : result['provider'] as String,
      completedDate: result['completed'] as String,
      hours: hours,
    );
    await _profileService.addCPDEntry(uid, entry);
    await _load();
  }

  Future<void> _showAddQualificationSheet() async {
    final uid = widget.auth.user?.uid ?? '';
    final titleCtrl = TextEditingController();
    final issuerCtrl = TextEditingController();
    DateTime? expiryDate;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
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
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add Qualification',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _sheetField(titleCtrl, 'Qualification Title',
                  'e.g. First Aid at Work'),
              const SizedBox(height: 12),
              _sheetField(issuerCtrl, 'Issuing Body (optional)',
                  'e.g. Red Cross'),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now()
                        .add(const Duration(days: 365)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2040),
                    builder: (c, child) => Theme(
                      data: ThemeData.light().copyWith(
                        colorScheme: const ColorScheme.light(
                            primary: AppColors.primary),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setSheetState(() => expiryDate = picked);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: Color(0xFF94A3B8)),
                      const SizedBox(width: 10),
                      Text(
                        expiryDate != null
                            ? 'Expires: ${_fmtDate(expiryDate!.toIso8601String())}'
                            : 'Select expiry date',
                        style: TextStyle(
                          fontSize: 13,
                          color: expiryDate != null
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final title =
                        titleCtrl.text.trim();
                    if (title.isEmpty ||
                        expiryDate == null) return;
                    final issuer = issuerCtrl.text.trim();
                    Navigator.pop(ctx, {
                      'title': title,
                      'issuer': issuer.isEmpty ? null : issuer,
                      'expiry': expiryDate!
                          .toIso8601String()
                          .substring(0, 10),
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(14)),
                  ),
                  child: const Text('Add Qualification',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // Do not dispose here — showModalBottomSheet resolves before the exit
    // animation finishes, so the sheet's TextField still holds a listener.
    // The controllers are GC-collected once this function returns.

    if (result == null) return;
    final qual = TrainerQualification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: result['title'] as String,
      issuer: result['issuer'] as String?,
      expiryDate: result['expiry'] as String,
    );
    await _profileService.addQualification(uid, qual);
    await _load();
  }

  Widget _sheetField(TextEditingController ctrl,
      String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569))),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                fontSize: 13, color: Color(0xFFCBD5E1)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }

  String _fmtDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    const m = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }

  Widget _profileStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _resolveFirstName(),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Freelance Trainer',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => widget.auth.signOut(),
            child: Text(
              'Sign Out',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final hasContent = _pendingCompanyInvites.isNotEmpty ||
        _invitations.isNotEmpty ||
        _upcoming.isNotEmpty;

    if (!hasContent) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
            child: Column(
              children: [
                Icon(Icons.work_outline,
                    size: 52, color: const Color(0xFFCCCCCC)),
                const SizedBox(height: 16),
                const Text(
                  'No jobs yet',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF333333)),
                ),
                const SizedBox(height: 8),
                Text(
                  'When a training company assigns you to a course,\nyou\'ll see it here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        if (_complianceAlertMessage() != null) ...[
          _buildComplianceAlertBanner(_complianceAlertMessage()!),
          const SizedBox(height: 12),
        ],
        if (_pendingCompanyInvites.isNotEmpty) ...[
          _sectionHeader('COMPANY INVITATIONS',
              _pendingCompanyInvites.length, AppColors.primary),
          const SizedBox(height: 10),
          ..._pendingCompanyInvites.map(_buildCompanyInviteCard),
          const SizedBox(height: 20),
        ],
        if (_invitations.isNotEmpty) ...[
          _sectionHeader('JOB INVITATIONS', _invitations.length,
              AppColors.primary),
          const SizedBox(height: 10),
          ..._invitations.map(_buildInvitationCard),
          const SizedBox(height: 20),
        ],
        if (_upcoming.isNotEmpty) ...[
          _sectionHeader(
              'UPCOMING JOBS', _upcoming.length, AppColors.primary),
          const SizedBox(height: 10),
          ..._upcoming.map(_buildJobCard),
        ],
      ],
    );
  }

  Widget _buildCompanyInviteCard(Map<String, dynamic> invite) {
    final inviteId = invite['id'] as String;
    final companyName =
        (invite['companyName'] as String?) ?? 'A Training Company';
    final isLoading = _inviteActionLoading.contains(inviteId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.business_outlined,
                      size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Company Invitation',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        companyName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111111),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$companyName has invited you to join their trainer network.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            setState(() =>
                                _inviteActionLoading.add(inviteId));
                            try {
                              await _trainerInvitesService
                                  .declineInvite(inviteId);
                              await _load();
                            } catch (_) {
                            } finally {
                              if (mounted) {
                                setState(() =>
                                    _inviteActionLoading.remove(inviteId));
                              }
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Decline',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            setState(() =>
                                _inviteActionLoading.add(inviteId));
                            try {
                              await widget.auth.acceptTrainerInvite(
                                inviteId,
                                invite['companyId'] as String,
                              );
                              await _load();
                            } catch (_) {
                            } finally {
                              if (mounted) {
                                setState(() =>
                                    _inviteActionLoading.remove(inviteId));
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Accept & Join',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String label, int count, Color color) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: AppColors.textSecondary.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildInvitationCard(Course course) {
    final isActing = _actionLoading.contains(course.id);
    final start = course.startDate;
    final venue =
        course.venueId != null ? _venueNames[course.venueId] : null;
    final time =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final dateLabel =
        '${_dayShort(start.weekday)} ${start.day} ${months[start.month - 1]} ${start.year} · $time';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 1.2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        course.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111111),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Awaiting response',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  course.courseNumber,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                _iconRow(Icons.calendar_today_outlined, dateLabel),
                const SizedBox(height: 4),
                _iconRow(
                  Icons.location_on_outlined,
                  (venue != null && venue.isNotEmpty)
                      ? venue
                      : 'Venue TBD',
                  faded: venue == null || venue.isEmpty,
                ),
                const SizedBox(height: 14),
                if (isActing)
                  const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primary),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _decline(course.id),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(
                                color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(
                                vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                          child: const Text('Decline',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _accept(course.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                          child: const Text('Accept',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700)),
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

  Widget _buildJobCard(Course course) {
    final start = course.startDate;
    final venue =
        course.venueId != null ? _venueNames[course.venueId] : null;
    final time =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${start.day}',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
              ),
              Text(
                months[start.month - 1],
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Container(
              width: 1, height: 48, color: const Color(0xFFF0F0F0)),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          course.title,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111111)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        course.courseNumber,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time_outlined,
                          size: 12,
                          color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text(time,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                      if (venue != null && venue.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.location_on_outlined,
                            size: 12,
                            color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            venue,
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconRow(IconData icon, String text, {bool faded = false}) {
    return Row(
      children: [
        Icon(icon,
            size: 13,
            color: faded
                ? const Color(0xFFBBBBBB)
                : AppColors.textSecondary),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: faded
                  ? const Color(0xFFBBBBBB)
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _dayShort(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(weekday - 1).clamp(0, 6)];
  }
}

// ─── Profile Tab ──────────────────────────────────────────────────────────────

class _ProfileTab extends StatelessWidget {
  final AuthProvider auth;
  const _ProfileTab({required this.auth});

  @override
  Widget build(BuildContext context) {
    final email = auth.user?.email ?? '';
    final name = email.contains('@') ? email.split('@')[0] : 'User';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text('Profile',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF0F0F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        Text(email,
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => auth.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared sub-widgets ───────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  const _StatCard(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111111))),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text('See all',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Course course;
  final String? venueName;
  final VoidCallback? onReturn;
  final bool showFeedbackBadge;
  const _CourseCard({
    required this.course,
    this.venueName,
    this.onReturn,
    this.showFeedbackBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final d = course.startDate;
    const monthNames = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final monthStr = monthNames[d.month - 1];
    final isPast = showFeedbackBadge;
    final dateColor = isPast ? const Color(0xFF94A3B8) : AppColors.primary;
    final dateBg = isPast
        ? const Color(0xFFF1F5F9)
        : AppColors.primary.withValues(alpha: 0.08);
    final dateBorder = isPast
        ? const Color(0xFFE2E8F0)
        : AppColors.primary.withValues(alpha: 0.2);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientCourseDetailScreen(
                course: course,
                venueName: venueName,
              ),
            ),
          );
          onReturn?.call();
        },
        child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: dateBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dateBorder),
              ),
              child: Column(
                children: [
                  Text(
                    '${d.day}',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: dateColor,
                        height: 1),
                  ),
                  Text(
                    monthStr,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: dateColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111111))),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          venueName != null
                              ? venueName!
                              : course.venueId != null
                                  ? 'Venue assigned'
                                  : 'Location TBC',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF94A3B8)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _StatusChip(status: course.status),
                      if (isPast) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_outline_rounded,
                                  size: 10,
                                  color: AppColors.primary),
                              const SizedBox(width: 3),
                              Text(
                                'Leave feedback',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final CourseRequest request;
  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    String submittedLabel = '';
    try {
      final dt = DateTime.parse(request.createdAt);
      const months = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      submittedLabel =
          'Submitted ${dt.day} ${months[dt.month - 1]}';
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9EC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Center(
                  child: Icon(Icons.assignment_outlined, size: 20, color: Color(0xFFD97706))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111111))),
                  const SizedBox(height: 2),
                  Text(submittedLabel,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(status: request.status),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'pending':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        label = 'Pending';
        break;
      case 'reviewed':
        bg = const Color(0xFFCCFBF1);
        fg = const Color(0xFF0D9488);
        label = 'Reviewed';
        break;
      case 'approved':
      case 'pending_trainer':
      case 'scheduled':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF059669);
        label = status == 'pending_trainer' ? 'Confirmed' : 'Approved';
        break;
      case 'declined':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        label = 'Declined';
        break;
      default:
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF6B7280);
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 5,
              height: 5,
              decoration:
                  BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  letterSpacing: 0.3)),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: primary
              ? const LinearGradient(
                  colors: [Color(0xFF2DB89E), Color(0xFF1A9980)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: primary ? null : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primary
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 20,
                  color: primary ? Colors.white : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: primary
                        ? Colors.white
                        : const Color(0xFF111111))),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 11,
                    color: primary
                        ? Colors.white.withValues(alpha: 0.75)
                        : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
