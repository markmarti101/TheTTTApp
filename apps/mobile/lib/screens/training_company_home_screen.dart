import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/course.dart';
import '../models/course_request.dart';
import '../models/venue.dart';
import '../providers/auth_provider.dart';
import '../services/courses_service.dart';
import '../services/company_directory_service.dart';
import '../services/requests_service.dart';
import '../services/venues_service.dart';
import 'company_clients_tab.dart';
import 'company_course_detail_screen.dart';
import 'setup_company_screen.dart';
import 'requests_list_screen.dart';
import 'company_trainers_screen.dart';
import 'add_client_screen.dart';
import 'company_venues_screen.dart';
import 'resources_screen.dart';
import 'notifications_screen.dart';
import '../services/notification_service.dart';

enum _CalendarView { month, week, day, byTrainer }

class TrainingCompanyHomeScreen extends StatefulWidget {
  const TrainingCompanyHomeScreen({super.key});

  @override
  State<TrainingCompanyHomeScreen> createState() =>
      _TrainingCompanyHomeScreenState();
}

class _TrainingCompanyHomeScreenState extends State<TrainingCompanyHomeScreen> {
  final _coursesService = CoursesService();
  final _venuesService = VenuesService();
  final _directoryService = CompanyDirectoryService();
  final _requestsService = RequestsService();

  int _tabIndex = 0; // 0 Dashboard, 1 Calendar, 2 Requests, 3 Clients
  int _unreadNotifCount = 0;

  late DateTime _focusedMonth;
  late DateTime _selectedDay;

  String? _companyId;
  String? _companyName;
  String? _userDisplayName;

  bool _loadingMonth = true;

  /// Whether we've already attempted to refresh the companyId from Firestore.
  /// Prevents an infinite retry loop when the user genuinely has no company yet.
  bool _companyIdRefreshAttempted = false;

  /// All courses returned for the company (used for dashboard metrics & upcoming week).
  List<Course> _allCourses = [];
  List<Course> _monthCourses = [];
  List<Venue> _venues = [];
  int _activeTrainers = 0;
  int _activeClients = 0;
  int _pendingBookings = 0;

  _CalendarView _calendarView = _CalendarView.month;
  List<UserSummary> _trainers = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = now;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    final nextCompanyId = auth.trainingCompanyId;
    if (nextCompanyId != _companyId) {
      _companyId = nextCompanyId;
      _companyName = null;
      _prefetchCompanyName();
      _loadMonthData();
    }
    final uid = auth.user?.uid;
    if (uid != null) _loadUnreadNotifCount(uid);
  }

  /// Reads registered company title from common Firestore field names.
  String? _parseCompanyName(DocumentSnapshot doc) {
    if (!doc.exists) return null;
    final raw = doc.data();
    if (raw is! Map<String, dynamic>) return null;
    for (final key in <String>[
      'name',
      'companyName',
      'businessName',
      'title',
      'legalName',
    ]) {
      final v = raw[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  String? get _resolvedCompanyName {
    final n = _companyName?.trim();
    return (n != null && n.isNotEmpty) ? n : null;
  }

  Future<void> _prefetchCompanyName() async {
    final id = _companyId;
    if (id == null || id.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('training_companies')
          .doc(id)
          .get();
      if (!mounted) return;
      final name = _parseCompanyName(snap);
      if (name != null) {
        setState(() => _companyName = name);
      }
    } catch (_) {}
  }

  Future<void> _loadUnreadNotifCount(String uid) async {
    try {
      final count = await NotificationService().getUnreadCount(uid);
      if (mounted) setState(() => _unreadNotifCount = count);
    } catch (_) {}
  }

  Future<void> _loadMonthData() async {
    if (_companyId == null || _companyId!.isEmpty) {
      setState(() {
        _loadingMonth = false;
        _allCourses = [];
        _monthCourses = [];
        _venues = [];
        _userDisplayName = null;
      });
      return;
    }

    setState(() {
      _loadingMonth = true;
    });

    try {
      final companyId = _companyId!;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final results = await Future.wait([
        _coursesService.getCoursesByCompanyOrdered(companyId, limit: 200),
        _venuesService.getVenues(companyId),
        FirebaseFirestore.instance
            .collection('training_companies')
            .doc(companyId)
            .get(),
        _directoryService.getClients(companyId),
        _directoryService.getTrainers(companyId),
        _requestsService.getRequestsByCompany(companyId),
        if (uid != null)
          FirebaseFirestore.instance.collection('users').doc(uid).get()
        else
          Future<DocumentSnapshot<Map<String, dynamic>>?>.value(null),
      ]);

      final allCourses = results[0] as List<Course>;
      final venues = results[1] as List<Venue>;
      final companyDoc = results[2] as DocumentSnapshot;
      final clients = results[3] as List<UserSummary>;
      final trainers = results[4] as List<UserSummary>;
      final requests = results[5] as List<CourseRequest>;
      final userDoc = results[6] as DocumentSnapshot<Map<String, dynamic>>?;
      String? userDisplayName;
      if (userDoc != null && userDoc.exists) {
        userDisplayName = userDoc.data()?['displayName'] as String?;
      }
      final companyName = _parseCompanyName(companyDoc);

      final filtered = allCourses.where((c) {
        return c.startDate.year == _focusedMonth.year &&
            c.startDate.month == _focusedMonth.month;
      }).toList()..sort((a, b) => a.startDate.compareTo(b.startDate));

      setState(() {
        _allCourses = allCourses;
        _venues = venues;
        _monthCourses = filtered;
        _companyName = companyName;
        _userDisplayName = userDisplayName;
        _activeClients = clients.length;
        _activeTrainers = trainers.length;
        _trainers = trainers;
        _pendingBookings = requests.where((r) => r.status == 'pending').length;
        _loadingMonth = false;
      });
    } catch (_) {
      setState(() {
        _loadingMonth = false;
        _allCourses = [];
        _monthCourses = [];
        _venues = [];
        _activeClients = 0;
        _activeTrainers = 0;
        _pendingBookings = 0;
        _userDisplayName = null;
        // Keep _companyName so the header still shows the last loaded company name.
      });
    }
  }

  Map<String, Venue> get _venuesById => {for (final v in _venues) v.id: v};

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final companyId = auth.trainingCompanyId;

    if (companyId == null || companyId.isEmpty) {
      // First time seeing null companyId → try refreshing from Firestore once.
      // This handles cases where the provider didn't resolve it on login
      // (transient network issue, race condition, etc.).
      if (!_companyIdRefreshAttempted) {
        _companyIdRefreshAttempted = true;
        // Schedule the refresh after this frame to avoid calling setState during build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          auth.refreshTrainingCompanyId();
        });
        // Show a loading spinner while we retry.
        return const Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }
      // Refresh was attempted and companyId is still null → truly no company.
      return const SetupCompanyScreen();
    }

    // Company found — reset the flag so a future sign-out/sign-in retries again.
    _companyIdRefreshAttempted = false;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, auth),
            Expanded(
              child: _tabIndex == 0
                  ? _buildDashboardTab()
                  : _tabIndex == 1
                  ? _buildCalendarTab()
                  : _tabIndex == 2
                  ? const RequestsListScreen(embedded: true)
                  : const CompanyClientsTab(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _tabIndex,
        onTap: (i) {
          setState(() => _tabIndex = i);
          if (i == 0) _loadMonthData();
        },
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: _requestsNavIcon(false),
            activeIcon: _requestsNavIcon(true),
            label: 'Requests',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            activeIcon: Icon(Icons.groups),
            label: 'Clients',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuthProvider auth) {
    if (_tabIndex == 0) {
      return _buildDashboardGreetingHeader(context, auth);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          Expanded(child: _buildHeaderBarCompanyTitle()),
          _buildNotifBell(auth),
          const SizedBox(width: 8),
          _userInitialsAvatar(auth),
        ],
      ),
    );
  }

  String _timeBasedGreeting() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Good morning';
    if (h >= 12 && h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _fullMonthYear(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[(d.month - 1).clamp(0, 11)]} ${d.year}';
  }

  /// Derives a first name from the email local part, without digits or symbols
  /// (e.g. `Marko400` → `Marko`, `mark345` → `Mark`).
  String _firstNameFromEmailLocalPart(String localPart) {
    if (localPart.isEmpty) return '';
    final segment = localPart
        .split(RegExp(r'[._-]'))
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    if (segment.isEmpty) return '';
    final leadMatch = RegExp(r'^([a-zA-Z]+)').firstMatch(segment);
    final String core;
    if (leadMatch != null && leadMatch.group(1)!.isNotEmpty) {
      core = leadMatch.group(1)!;
    } else {
      final noDigits = segment.replaceAll(RegExp(r'\d'), '');
      core = noDigits.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    }
    if (core.isEmpty) return '';
    return core[0].toUpperCase() +
        (core.length > 1 ? core.substring(1).toLowerCase() : '');
  }

  String _resolveFirstName(AuthProvider auth) {
    final fromProfile = _userDisplayName?.trim();
    if (fromProfile != null && fromProfile.isNotEmpty) {
      var first = fromProfile.split(RegExp(r'\s+')).first;
      if (RegExp(r'\d').hasMatch(first)) {
        final cleaned = _firstNameFromEmailLocalPart(first);
        if (cleaned.isNotEmpty) first = cleaned;
      }
      return first;
    }
    final dn = auth.user?.displayName?.trim();
    if (dn != null && dn.isNotEmpty) {
      var first = dn.split(RegExp(r'\s+')).first;
      if (RegExp(r'\d').hasMatch(first)) {
        final cleaned = _firstNameFromEmailLocalPart(first);
        if (cleaned.isNotEmpty) first = cleaned;
      }
      return first;
    }
    final email = auth.user?.email ?? '';
    if (email.contains('@')) {
      final local = email.split('@').first;
      final cleaned = _firstNameFromEmailLocalPart(local);
      if (cleaned.isNotEmpty) return cleaned;
    }
    return 'there';
  }

  String _resolveInitials(AuthProvider auth) {
    String cleanToken(String token) {
      if (RegExp(r'\d').hasMatch(token)) {
        final c = _firstNameFromEmailLocalPart(token);
        if (c.isNotEmpty) return c;
      }
      return token;
    }

    final fromProfile = _userDisplayName?.trim();
    if (fromProfile != null && fromProfile.isNotEmpty) {
      final parts = fromProfile
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .map(cleanToken)
          .toList();
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      if (parts.isNotEmpty && parts[0].length >= 2) {
        return parts[0].substring(0, 2).toUpperCase();
      }
      if (parts.isNotEmpty) {
        return '${parts[0][0]}${parts[0][0]}'.toUpperCase();
      }
    }
    final dn = auth.user?.displayName?.trim();
    if (dn != null && dn.isNotEmpty) {
      final parts = dn
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .map(cleanToken)
          .toList();
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      if (parts.isNotEmpty && parts[0].length >= 2) {
        return parts[0].substring(0, 2).toUpperCase();
      }
    }
    final email = auth.user?.email ?? '';
    final local = email.split('@').first;
    final cleaned = _firstNameFromEmailLocalPart(local);
    if (cleaned.isNotEmpty) {
      if (cleaned.length >= 2) {
        return cleaned.substring(0, 2).toUpperCase();
      }
      return '${cleaned[0]}${cleaned[0]}'.toUpperCase();
    }
    if (local.isNotEmpty) {
      return '${local[0]}${local[0]}'.toUpperCase();
    }
    return '?';
  }

  Widget _buildNotifBell(AuthProvider auth) {
    return GestureDetector(
      onTap: () async {
        final uid = auth.user?.uid ?? '';
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NotificationsScreen(userId: uid),
          ),
        );
        _loadUnreadNotifCount(uid);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined,
              size: 24, color: Color(0xFF475569)),
          if (_unreadNotifCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  shape: BoxShape.circle,
                ),
                constraints:
                    const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  _unreadNotifCount > 99 ? '99+' : '$_unreadNotifCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _userInitialsAvatar(AuthProvider auth) {
    return CircleAvatar(
      backgroundColor: AppColors.primary,
      radius: 22,
      child: Text(
        _resolveInitials(auth),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildHeaderBarCompanyTitle() {
    final name = _resolvedCompanyName;
    if (name != null) {
      return Text(
        name,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      );
    }
    if (_loadingMonth) {
      return const SizedBox(
        height: 24,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildDrawerCompanyTitle() {
    const style = TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: 16,
      color: AppColors.text,
    );
    final name = _resolvedCompanyName;
    if (name != null) {
      return Text(
        name,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    if (_loadingMonth) {
      return const SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppColors.primary,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildGreetingCompanyMonthLine() {
    final monthYear = _fullMonthYear(DateTime.now());
    const lineStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.primary,
    );
    final name = _resolvedCompanyName;
    if (name != null) {
      return Text('$name · $monthYear', style: lineStyle);
    }
    if (_loadingMonth) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text('· $monthYear', style: lineStyle)),
        ],
      );
    }
    return Text(monthYear, style: lineStyle);
  }

  Widget _buildDashboardGreetingHeader(
    BuildContext context,
    AuthProvider auth,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _timeBasedGreeting(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _resolveFirstName(auth),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                _buildGreetingCompanyMonthLine(),
              ],
            ),
          ),
          Row(
            children: [
              _buildNotifBell(auth),
              const SizedBox(width: 8),
              _userInitialsAvatar(auth),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: AppColors.card),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: _buildDrawerCompanyTitle(),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Trainers'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CompanyTrainersScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Venues'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CompanyVenuesScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Resources'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ResourcesScreen(companyId: _companyId ?? ''),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout_outlined),
            title: const Text('Sign out'),
            onTap: () => context.read<AuthProvider>().signOut(),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarTab() {
    if (_loadingMonth) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    return Column(
      children: [
        _buildCalendarViewToggle(),
        Expanded(child: _buildCalendarBody()),
      ],
    );
  }

  Widget _buildCalendarViewToggle() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _calendarToggleBtn('Month', _CalendarView.month),
          _calendarToggleBtn('Week', _CalendarView.week),
          _calendarToggleBtn('Day', _CalendarView.day),
          _calendarToggleBtn('Trainer', _CalendarView.byTrainer),
        ],
      ),
    );
  }

  Widget _calendarToggleBtn(String label, _CalendarView view) {
    final isActive = _calendarView == view;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _calendarView = view),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarBody() {
    switch (_calendarView) {
      case _CalendarView.month:
        return _buildMonthBody(showUpcomingList: false);
      case _CalendarView.week:
        return _buildWeekView();
      case _CalendarView.day:
        return _buildDayView();
      case _CalendarView.byTrainer:
        return _buildByTrainerView();
    }
  }

  Widget _buildDashboardTab() {
    if (_loadingMonth) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final upcomingWeek = _allCourses.where((course) {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final endOfWindow = startOfToday.add(const Duration(days: 7));
      return !course.startDate.isBefore(startOfToday) &&
          course.startDate.isBefore(endOfWindow) &&
          course.endDate.isAfter(DateTime.now()) &&
          course.status != 'completed' &&
          course.status != 'declined' &&
          course.status != 'trainer_declined';
    }).toList()..sort((a, b) => a.startDate.compareTo(b.startDate));

    final now = DateTime.now();
    final coursesThisMonth = _countCoursesStartingInMonth(now.year, now.month);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricsGrid(coursesThisMonth: coursesThisMonth),
          const SizedBox(height: 20),
          _buildQuickActions(),
          const SizedBox(height: 20),
          _buildNeedsAttentionCard(),
          const SizedBox(height: 20),
          _buildUpcomingSection(upcomingWeek),
        ],
      ),
    );
  }

  static const Color _dashOrange = Color(0xFFE67E22);
  static const Color _dashBorder = Color(0xFFE0E0E0);

  int _countCoursesStartingInMonth(int year, int month) {
    return _allCourses
        .where((c) => c.startDate.year == year && c.startDate.month == month)
        .length;
  }

  String _coursesTrendSubtitle() {
    final now = DateTime.now();
    final thisC = _countCoursesStartingInMonth(now.year, now.month);
    final prev = DateTime(now.year, now.month - 1);
    final lastC = _countCoursesStartingInMonth(prev.year, prev.month);
    final d = thisC - lastC;
    if (d > 0) return '↑ $d more than last month';
    if (d < 0) return '↓ ${-d} fewer than last month';
    return 'Same as last month';
  }

  Widget _requestsNavIcon(bool selected) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Icon(Icons.assignment_outlined, color: color),
        if (_pendingBookings > 0)
          Positioned(
            right: -5,
            top: -4,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFE53935),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMetricsGrid({required int coursesThisMonth}) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.12,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: [
        _buildMetricTile(
          icon: Icons.calendar_today_outlined,
          iconColor: AppColors.primary,
          title: 'Courses this month',
          value: '$coursesThisMonth',
          valueColor: AppColors.primary,
          subtitle: _coursesTrendSubtitle(),
          subtitleColor: const Color(0xFF9E9E9E),
          accentLeft: false,
        ),
        _buildMetricTile(
          icon: Icons.groups_outlined,
          iconColor: AppColors.primary,
          title: 'Active trainers',
          value: '$_activeTrainers',
          valueColor: AppColors.primary,
          subtitle: 'Same as last month',
          subtitleColor: const Color(0xFF9E9E9E),
          accentLeft: false,
        ),
        _buildMetricTile(
          icon: Icons.description_outlined,
          iconColor: _dashOrange,
          title: 'Pending requests',
          value: '$_pendingBookings',
          valueColor: _dashOrange,
          subtitle: _pendingBookings > 0 ? 'Needs review' : 'All caught up',
          subtitleColor: _pendingBookings > 0
              ? _dashOrange
              : const Color(0xFF9E9E9E),
          accentLeft: true,
        ),
        _buildMetricTile(
          icon: Icons.business_center_outlined,
          iconColor: AppColors.primary,
          title: 'Active clients',
          value: '$_activeClients',
          valueColor: AppColors.primary,
          subtitle: 'Companies you work with',
          subtitleColor: const Color(0xFF9E9E9E),
          accentLeft: false,
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required Color valueColor,
    required String subtitle,
    required Color subtitleColor,
    required bool accentLeft,
  }) {
    final inner = Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF7D7D7D),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 36,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
        ],
      ),
    );

    if (accentLeft) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _dashBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: _dashOrange),
              Expanded(child: inner),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _dashBorder),
      ),
      child: inner,
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RequestsListScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Course'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddClientScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: const Text('Add Client'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _tabIndex = 1),
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: const Text('Schedule'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUpcomingSection(List<Course> upcomingWeek) {
    final visibleCourses = upcomingWeek.toList();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _dashBorder),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Upcoming this week',
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.05,
                    color: Color(0xFF1C1C1C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _tabIndex = 1),
                child: const Text(
                  'View all →',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (visibleCourses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'No courses in the next 7 days.',
                style: TextStyle(color: Color(0xFF6F6F6F), fontSize: 13),
              ),
            )
          else
            ...visibleCourses.asMap().entries.map(
              (entry) => Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key == visibleCourses.length - 1 ? 0 : 10,
                ),
                child: _buildUpcomingCourseTile(
                  course: entry.value,
                  index: entry.key,
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _courseIsPendingStatus(Course course) {
    final s = course.status.toLowerCase();
    return s == 'pending_trainer' || s == 'pending' || s == 'pending_client';
  }

  String _courseStatusLabel(Course course) =>
      _courseIsPendingStatus(course) ? 'Pending' : 'Confirmed';

  Widget _buildUpcomingCourseTile({
    required Course course,
    required int index,
  }) {
    final start = course.startDate;
    final venue = course.venueId == null ? null : _venuesById[course.venueId];
    final minute = start.minute.toString().padLeft(2, '0');
    final hour = start.hour % 12 == 0 ? 12 : start.hour % 12;
    final amPm = start.hour >= 12 ? 'pm' : 'am';
    final locationLabel = venue?.name ?? 'No venue set';
    final badgeColor = index.isEven
        ? AppColors.primary
        : const Color(0xFFE67E22);
    final pending = _courseIsPendingStatus(course);

    return Material(
      color: const Color(0xFFF3F3F3),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _focusedMonth = DateTime(start.year, start.month, 1);
                  _selectedDay = DateTime(start.year, start.month, start.day);
                  _tabIndex = 1;
                });
                _loadMonthData();
              },
              child: Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${start.day}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _monthShort(start.month).toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CompanyCourseDetailScreen(courseId: course.id),
                      ),
                    );
                    if (mounted) _loadMonthData();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Color(0xFF2B2B2B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$hour:$minute$amPm · $locationLabel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF636363),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: pending
                                ? const Color(0xFFFFF4E0)
                                : const Color(0xFFE8F7F2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _courseStatusLabel(course),
                            style: TextStyle(
                              color: pending
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFF1B6B4A),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeedsAttentionCard() {
    final missingVenueSessions = _allCourses.where((c) {
      final missing = c.venueId == null || c.venueId!.isEmpty;
      return missing && c.endDate.isAfter(DateTime.now());
    }).length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5AC50)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFE67E22),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Needs attention',
                style: TextStyle(
                  fontSize: 17,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5D3508),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _needsAttentionRow(
            icon: Icons.description_outlined,
            text: _pendingBookings == 1
                ? '1 request awaiting review'
                : '$_pendingBookings requests awaiting review',
            actionLabel: 'Review →',
            onAction: () => setState(() => _tabIndex = 2),
          ),
          if (missingVenueSessions > 0) ...[
            const SizedBox(height: 10),
            _needsAttentionRow(
              icon: Icons.schedule_outlined,
              text: missingVenueSessions == 1
                  ? '1 session without a venue assigned'
                  : '$missingVenueSessions sessions without a venue assigned',
              actionLabel: 'Fix →',
              onAction: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CompanyVenuesScreen(),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _needsAttentionRow({
    required IconData icon,
    required String text,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFB06C09), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF6B4420),
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel,
              style: const TextStyle(
                color: _dashOrange,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Week View ────────────────────────────────────────────────────────────

  Widget _buildWeekView() {
    final weekday = _selectedDay.weekday; // 1=Mon, 7=Sun
    final weekStart = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    ).subtract(Duration(days: weekday - 1));
    final weekDays =
        List.generate(7, (i) => weekStart.add(Duration(days: i)));

    final selectedDayCourses = _allCourses
        .where((c) => _isSameDay(c.startDate, _selectedDay))
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWeekNavigator(weekStart),
          const SizedBox(height: 12),
          _buildWeekDayStrip(weekDays),
          const SizedBox(height: 16),
          Text(
            'Courses on ${_selectedDay.day} ${_monthShort(_selectedDay.month)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 10),
          if (selectedDayCourses.isEmpty)
            _buildNoCoursesTile('No courses scheduled for this day.')
          else
            ...selectedDayCourses.map(_buildCourseCard),
        ],
      ),
    );
  }

  Widget _buildWeekNavigator(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final label = weekStart.month == weekEnd.month
        ? '${weekStart.day}–${weekEnd.day} ${_monthShort(weekStart.month)} ${weekStart.year}'
        : '${weekStart.day} ${_monthShort(weekStart.month)} – '
            '${weekEnd.day} ${_monthShort(weekEnd.month)} ${weekEnd.year}';

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => setState(
            () => _selectedDay =
                _selectedDay.subtract(const Duration(days: 7)),
          ),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => setState(
            () =>
                _selectedDay = _selectedDay.add(const Duration(days: 7)),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekDayStrip(List<DateTime> weekDays) {
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(7, (i) {
          final day = weekDays[i];
          final isSelected = _isSameDay(day, _selectedDay);
          final isToday = day == today;
          final courseCount =
              _allCourses.where((c) => _isSameDay(c.startDate, day)).length;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDay = day),
              child: Column(
                children: [
                  Text(
                    dayLabels[i],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.primary
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : (isToday
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : null),
                      borderRadius: BorderRadius.circular(10),
                      border: isToday && !isSelected
                          ? Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              width: 1.2,
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : (isToday
                                ? AppColors.primary
                                : const Color(0xFF374151)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: courseCount > 0
                          ? (isSelected
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.5))
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Day View ─────────────────────────────────────────────────────────────

  Widget _buildDayView() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final dayCourses = _allCourses
        .where((c) => _isSameDay(c.startDate, _selectedDay))
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final isToday = _selectedDay == today;
    final dayLabel = isToday
        ? 'Today, ${_selectedDay.day} ${_monthShort(_selectedDay.month)}'
        : '${dayNames[_selectedDay.weekday - 1]}, '
            '${_selectedDay.day} ${_monthShort(_selectedDay.month)} '
            '${_selectedDay.year}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(
                  () => _selectedDay =
                      _selectedDay.subtract(const Duration(days: 1)),
                ),
              ),
              Expanded(
                child: Text(
                  dayLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(
                  () =>
                      _selectedDay = _selectedDay.add(const Duration(days: 1)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${dayCourses.length} course${dayCourses.length == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          if (dayCourses.isEmpty)
            _buildNoCoursesTile('No courses scheduled for this day.')
          else
            ...dayCourses.map(_buildCourseCard),
        ],
      ),
    );
  }

  // ── By Trainer View ───────────────────────────────────────────────────────

  Widget _buildByTrainerView() {
    final trainerNames = <String, String>{
      for (final t in _trainers) t.id: t.displayName ?? t.email,
    };

    final grouped = <String, List<Course>>{};
    for (final c in _allCourses) {
      grouped.putIfAbsent(c.trainerId, () => []).add(c);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.startDate.compareTo(b.startDate));
    }

    final sortedIds = grouped.keys.toList()
      ..sort((a, b) {
        final nameA = trainerNames[a] ?? '';
        final nameB = trainerNames[b] ?? '';
        if (nameA.isEmpty && nameB.isNotEmpty) return 1;
        if (nameA.isNotEmpty && nameB.isEmpty) return -1;
        return nameA.compareTo(nameB);
      });

    if (sortedIds.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No courses found.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedIds.length,
      itemBuilder: (context, i) {
        final trainerId = sortedIds[i];
        final name = trainerNames[trainerId];
        final trainerCourses = grouped[trainerId]!;
        final initials = name != null && name.isNotEmpty
            ? name
                .trim()
                .split(RegExp(r'\s+'))
                .take(2)
                .map((s) => s[0].toUpperCase())
                .join()
            : '?';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (i > 0) const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  radius: 16,
                  child: Text(
                    initials,
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
                    name ?? 'Unknown Trainer',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                    ),
                  ),
                ),
                Text(
                  '${trainerCourses.length} course${trainerCourses.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...trainerCourses.map(_buildCourseCard),
          ],
        );
      },
    );
  }

  Widget _buildMonthBody({required bool showUpcomingList}) {
    // Count courses per day for the badge
    final courseCountByDay = <String, int>{};
    for (final c in _monthCourses) {
      final key = _dayKey(c.startDate);
      courseCountByDay[key] = (courseCountByDay[key] ?? 0) + 1;
    }

    final selectedDayCourses = _monthCourses
        .where((c) => _isSameDay(c.startDate, _selectedDay))
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMonthSelector(),
          const SizedBox(height: 10),
          CompanyMonthCalendar(
            focusedMonth: _focusedMonth,
            selectedDay: _selectedDay,
            courseCountByDayKey: courseCountByDay,
            onDaySelected: (day) => setState(() => _selectedDay = day),
          ),
          if (!showUpcomingList) ...[
            const SizedBox(height: 16),
            Text(
              'Courses on ${_selectedDay.day} ${_monthShort(_selectedDay.month)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 10),
            if (selectedDayCourses.isEmpty)
              _buildNoCoursesTile('No courses scheduled for this day.')
            else
              ...selectedDayCourses.map(_buildCourseCard),
          ] else ...[
            const SizedBox(height: 16),
            Text(
              'Upcoming this month',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 10),
            if (_monthCourses.isEmpty)
              _buildNoCoursesTile('No courses scheduled for this month.')
            else
              ..._monthCourses.map(_buildCourseCard),
          ],
        ],
      ),
    );
  }

  Widget _buildNoCoursesTile(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Row(
        children: [
          Icon(Icons.event_busy_outlined,
              size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            message,
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    final now = DateTime.now();
    final isCurrentMonth = _focusedMonth.year == now.year &&
        _focusedMonth.month == now.month;
    final monthLabel =
        '${_monthShort(_focusedMonth.month)} ${_focusedMonth.year}';

    return Row(
      children: [
        IconButton(
          onPressed: () {
            final prev = DateTime(
                _focusedMonth.year, _focusedMonth.month - 1, 1);
            setState(() {
              _focusedMonth = prev;
              _selectedDay = prev;
            });
            _loadMonthData();
          },
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            monthLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ),
        // Today button — only visible when not on the current month
        if (!isCurrentMonth)
          GestureDetector(
            onTap: () {
              final today = DateTime(now.year, now.month, now.day);
              setState(() {
                _focusedMonth = DateTime(now.year, now.month, 1);
                _selectedDay = today;
              });
              _loadMonthData();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'Today',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        IconButton(
          onPressed: () {
            final next = DateTime(
                _focusedMonth.year, _focusedMonth.month + 1, 1);
            setState(() {
              _focusedMonth = next;
              _selectedDay = next;
            });
            _loadMonthData();
          },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildCourseCard(Course course) {
    final venue = course.venueId == null ? null : _venuesById[course.venueId];
    final start = course.startDate;
    final delegateCount = course.delegateIds?.length ?? 0;
    final capacity = venue?.capacity;
    final time =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CompanyCourseDetailScreen(courseId: course.id),
          ),
        );
        if (mounted) _loadMonthData();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left teal accent bar
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
            // Date column
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${start.day}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  _monthShort(start.month),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Divider
            Container(
                width: 1, height: 48, color: const Color(0xFFF0F0F0)),
            const SizedBox(width: 12),
            // Info
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
                              color: Color(0xFF111111),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          course.courseNumber,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                          ),
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
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (venue != null) ...[
                          Icon(Icons.location_on_outlined,
                              size: 12,
                              color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              venue.name,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (capacity != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.event_seat_outlined,
                              size: 12,
                              color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Text(
                            '$delegateCount / $capacity delegates',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dayKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _monthShort(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[(month - 1).clamp(0, 11)];
  }
}

class CompanyMonthCalendar extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final Map<String, int> courseCountByDayKey;
  final ValueChanged<DateTime> onDaySelected;

  const CompanyMonthCalendar({
    super.key,
    required this.focusedMonth,
    required this.selectedDay,
    required this.courseCountByDayKey,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final first = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final leadingBlankCount = first.weekday - 1; // Monday = 1

    const totalCells = 42; // 6-week grid
    final cells = List<DateTime?>.generate(totalCells, (i) {
      final dayIndex = i - leadingBlankCount;
      if (dayIndex < 0 || dayIndex >= daysInMonth) return null;
      return DateTime(focusedMonth.year, focusedMonth.month, dayIndex + 1);
    });

    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Weekday headers
          Row(
            children: weekdays
                .map(
                  (w) => Expanded(
                    child: Text(
                      w,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          // Day grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemBuilder: (context, i) {
              final day = cells[i];
              if (day == null) return const SizedBox.shrink();

              final key =
                  '${day.year.toString().padLeft(4, '0')}-'
                  '${day.month.toString().padLeft(2, '0')}-'
                  '${day.day.toString().padLeft(2, '0')}';
              final count = courseCountByDayKey[key] ?? 0;
              final isSelected = day.year == selectedDay.year &&
                  day.month == selectedDay.month &&
                  day.day == selectedDay.day;
              final isToday = day == today;

              // Visual state priority: selected > today > normal
              Color? bgColor;
              Border? border;
              Color textColor;

              if (isSelected) {
                bgColor = AppColors.primary;
                border = null;
                textColor = Colors.white;
              } else if (isToday) {
                bgColor = AppColors.primary.withValues(alpha: 0.12);
                border = Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    width: 1.2);
                textColor = AppColors.primary;
              } else {
                bgColor = null;
                border = null;
                textColor = const Color(0xFF374151);
              }

              return GestureDetector(
                onTap: () => onDaySelected(day),
                child: Center(
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Day circle
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(10),
                            border: border,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                        // Course count badge (bottom-right)
                        if (count > 0)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: count > 1 ? 14 : 8,
                              height: count > 1 ? 14 : 8,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: count > 1
                                  ? Text(
                                      '$count',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected
                                            ? AppColors.primary
                                            : Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
