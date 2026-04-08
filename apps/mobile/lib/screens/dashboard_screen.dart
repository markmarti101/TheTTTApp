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
import 'course_request_screen.dart';
import 'client_requests_screen.dart';

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
      final companyFuture = FirebaseFirestore.instance
          .collection('training_companies')
          .doc(companyId)
          .get();
      final courses = await coursesFuture;
      final requests = await requestsFuture;
      final companyDoc = await companyFuture;

      // Fetch venue names for all courses that have a venueId
      final venueIds = courses
          .map((c) => c.venueId)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
      final venueNames = <String, String>{};
      for (final id in venueIds) {
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
      }

      if (mounted) {
        setState(() {
          _courses = courses;
          _requests = requests;
          _companyName =
              companyDoc.data()?['name'] as String? ?? 'Your Company';
          _venueNames = venueNames;
          _dataLoaded = true;
          _dataLoading = false;
        });
      }
    } catch (_) {
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
    final upcoming = _courses.where((c) => c.startDate.isAfter(now)).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final pastCount =
        _courses.where((c) => !c.startDate.isAfter(now)).length;
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
            const _ComingSoonTab(
              label: 'Delegates',
              icon: Icons.group_outlined,
            ),
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

// ─── Freelancer placeholder ───────────────────────────────────────────────────

class _FreelancerScreen extends StatelessWidget {
  final AuthProvider auth;
  const _FreelancerScreen({required this.auth});

  @override
  Widget build(BuildContext context) {
    final email = auth.user?.email ?? '';
    final name = email.contains('@') ? email.split('@')[0] : 'Trainer';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Welcome, $name',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  TextButton(
                      onPressed: () => auth.signOut(),
                      child: Text('Sign Out',
                          style: TextStyle(color: AppColors.primary))),
                ],
              ),
              const SizedBox(height: 32),
              const Text('Trainer Dashboard',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Job acceptance coming soon.',
                  style: TextStyle(
                      fontSize: 15, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Coming Soon Tab ──────────────────────────────────────────────────────────

class _ComingSoonTab extends StatelessWidget {
  final String label;
  final IconData icon;
  const _ComingSoonTab({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFFCCCCCC)),
            const SizedBox(height: 14),
            Text(label,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Coming soon',
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
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
                  foregroundColor: Colors.red.shade600,
                  side: BorderSide(color: Colors.red.shade200),
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
  const _CourseCard({required this.course, this.venueName});

  @override
  Widget build(BuildContext context) {
    final d = course.startDate;
    const monthNames = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final monthStr = monthNames[d.month - 1];

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
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    '${d.day}',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        height: 1),
                  ),
                  Text(
                    monthStr,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
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
                  _StatusChip(status: course.status),
                ],
              ),
            ),
          ],
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
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF2563EB);
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
