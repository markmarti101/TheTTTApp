import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/course_request.dart';
import '../providers/auth_provider.dart';
import '../services/requests_service.dart';
import 'request_detail_screen.dart';

class RequestsListScreen extends StatefulWidget {
  const RequestsListScreen({super.key, this.embedded = false});

  /// When true, omits [AppBar] and back actions (for use inside a tab shell).
  final bool embedded;

  @override
  State<RequestsListScreen> createState() => _RequestsListScreenState();
}

class _RequestsListScreenState extends State<RequestsListScreen> {
  final _requestsService = RequestsService();
  List<CourseRequest> _requests = [];
  String _selectedFilter = 'all';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final auth = context.read<AuthProvider>();
    final companyId = auth.trainingCompanyId;
    if (companyId == null) {
      setState(() {
        _loading = false;
        _error = 'No training company linked';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _requestsService.getRequestsByCompany(companyId);
      setState(() {
        _requests = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load requests. Please try again.';
        _loading = false;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF22C55E);
      case 'declined':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Color _statusSoftBg(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFFE9F8EE);
      case 'declined':
        return const Color(0xFFFCEBED);
      case 'reviewed':
        return const Color(0xFFEAF3FD);
      default:
        return const Color(0xFFFFF4E1);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'declined':
        return 'Declined';
      case 'reviewed':
        return 'Reviewed';
      default:
        return 'Pending';
    }
  }

  int _countByStatus(String status) =>
      _requests.where((r) => r.status == status).length;

  List<CourseRequest> get _filteredRequests {
    if (_selectedFilter == 'all') return _requests;
    return _requests.where((r) => r.status == _selectedFilter).toList();
  }

  List<CourseRequest> _group(String status) =>
      _filteredRequests.where((r) => r.status == status).toList();

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          )
        : _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  if (!widget.embedded) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back'),
                    ),
                  ],
                ],
              ),
            ),
          )
        : _requests.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'No requests yet',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
                if (!widget.embedded) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Dashboard'),
                  ),
                ],
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadRequests,
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              children: [
                _buildHeader(),
                const SizedBox(height: 12),
                _buildFilterChips(),
                const SizedBox(height: 14),
                ..._buildGroupedSections(),
              ],
            ),
          );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Course Requests'),
              backgroundColor: AppColors.card,
              foregroundColor: AppColors.text,
              elevation: 0,
            ),
      body: body,
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
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
      return '${dt.day} ${months[(dt.month - 1).clamp(0, 11)]} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  String _timeAgoFromIso(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inDays >= 1)
        return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
      if (diff.inHours >= 1)
        return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
      final mins = diff.inMinutes.clamp(1, 59);
      return '$mins min ago';
    } catch (_) {
      return '';
    }
  }

  String _initialsFromTitle(String title) {
    final parts = title
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) return 'R';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Widget _buildHeader() {
    final needsAttention =
        _countByStatus('pending') + _countByStatus('reviewed');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Course Requests',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
        ),
        Text(
          '$needsAttention require your attention',
          style: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    final chips = <Map<String, String>>[
      {'id': 'all', 'label': 'All', 'count': '${_requests.length}'},
      {
        'id': 'pending',
        'label': 'Pending',
        'count': '${_countByStatus('pending')}',
      },
      {
        'id': 'reviewed',
        'label': 'Reviewed',
        'count': '${_countByStatus('reviewed')}',
      },
      {
        'id': 'approved',
        'label': 'Approved',
        'count': '${_countByStatus('approved')}',
      },
      {
        'id': 'declined',
        'label': 'Declined',
        'count': '${_countByStatus('declined')}',
      },
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips.map((chip) {
          final selected = _selectedFilter == chip['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = chip['id']!),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : const Color(0xFFF2F3F6),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : const Color(0xFFE0E3EA),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      chip['label']!,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.25)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        chip['count']!,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildGroupedSections() {
    final widgets = <Widget>[];
    final groups = <Map<String, dynamic>>[
      {
        'title': 'Needs Action',
        'key': 'pending_reviewed',
        'items': [..._group('pending'), ..._group('reviewed')],
      },
      {
        'title': 'Approved',
        'key': 'approved',
        'items': _group('approved'),
      },
      {
        'title': 'Declined',
        'key': 'declined',
        'items': _group('declined'),
      },
    ];

    for (final g in groups) {
      final items = g['items'] as List<CourseRequest>;
      if (items.isEmpty) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${g['title']} · ${items.length}',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.8),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
      widgets.addAll(items.map(_buildRequestCard));
      widgets.add(const SizedBox(height: 10));
    }

    if (widgets.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('No requests in this filter')),
        ),
      ];
    }
    return widgets;
  }

  Widget _buildRequestCard(CourseRequest r) {
    final status = _statusLabel(r.status);
    final statusColor = _statusColor(r.status);
    final needsAction = r.status == 'pending' || r.status == 'reviewed';
    final preferred = r.preferredDates ?? const <String>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E7EA)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initialsFromTitle(r.title),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Color(0xFF111111),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _statusSoftBg(r.status),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r.topic ?? 'Client request',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.85,
                          ),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        needsAction
                            ? 'Submitted ${_timeAgoFromIso(r.createdAt)}'
                            : (r.status == 'approved'
                                  ? 'Approved ${_timeAgoFromIso(r.updatedAt)}'
                                  : 'Declined ${_timeAgoFromIso(r.updatedAt)}'),
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.75,
                          ),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (preferred.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: preferred.take(3).map((d) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _formatDate(d),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          if ((r.notes ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '"${r.notes!.trim()}"',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
          const Divider(height: 1),
          if (needsAction)
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RequestDetailScreen(
                            requestId: r.id,
                            initialAction: 'approve',
                          ),
                        ),
                      );
                      _loadRequests();
                    },
                    child: const Text(
                      'Approve',
                      style: TextStyle(
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 42, color: const Color(0xFFEAEAEA)),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RequestDetailScreen(
                            requestId: r.id,
                            initialAction: 'decline',
                          ),
                        ),
                      );
                      _loadRequests();
                    },
                    child: const Text(
                      'Decline',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else if (r.status == 'approved')
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RequestDetailScreen(requestId: r.id),
                    ),
                  );
                  _loadRequests();
                },
                child: Text(
                  'View Course →',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RequestDetailScreen(requestId: r.id),
                    ),
                  );
                  _loadRequests();
                },
                child: const Text(
                  'View details',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
