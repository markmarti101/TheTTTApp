import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/course_request.dart';
import 'course_request_screen.dart';

/// Bookings tab — shows all of a client's course requests with filter chips.
/// Used as a tab inside DashboardScreen's bottom nav.
class ClientRequestsScreen extends StatefulWidget {
  final List<CourseRequest> requests;
  final bool loading;
  final Future<void> Function() onRefresh;

  const ClientRequestsScreen({
    super.key,
    required this.requests,
    required this.onRefresh,
    this.loading = false,
  });

  @override
  State<ClientRequestsScreen> createState() => _ClientRequestsScreenState();
}

class _ClientRequestsScreenState extends State<ClientRequestsScreen> {
  String _filter = 'all';

  static const _filters = ['all', 'pending', 'reviewed', 'approved', 'declined'];

  List<CourseRequest> get _filtered {
    if (_filter == 'all') return widget.requests;
    return widget.requests.where((r) => r.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        _buildFilterRow(),
        Expanded(
          child: widget.loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: widget.onRefresh,
                  child: _filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) =>
                              _RequestDetailCard(request: _filtered[i]),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Bookings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111111),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CourseRequestScreen()),
                  );
                  widget.onRefresh();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 15),
                      SizedBox(width: 4),
                      Text(
                        'New',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: _filters.map((f) {
                final selected = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected
                            ? _filterColor(f)
                            : _filterColor(f).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        _filterLabel(f),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? Colors.white
                              : _filterColor(f),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 60),
        Center(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.inbox_outlined,
                    color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 14),
              Text(
                _filter == 'all'
                    ? 'No requests yet'
                    : 'No ${_filterLabel(_filter).toLowerCase()} requests',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _filter == 'all'
                    ? 'Tap + New to submit your first request'
                    : 'Try a different filter',
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _filterColor(String f) {
    switch (f) {
      case 'pending':
        return const Color(0xFFD97706);
      case 'reviewed':
        return const Color(0xFF0D9488);
      case 'approved':
        return const Color(0xFF059669);
      case 'declined':
        return const Color(0xFFDC2626);
      default:
        return AppColors.primary;
    }
  }

  String _filterLabel(String f) {
    switch (f) {
      case 'all':
        return 'All';
      case 'pending':
        return 'Pending';
      case 'reviewed':
        return 'Reviewed';
      case 'approved':
        return 'Approved';
      case 'declined':
        return 'Declined';
      default:
        return f;
    }
  }
}

// ─── Detailed request card ────────────────────────────────────────────────────

class _RequestDetailCard extends StatelessWidget {
  final CourseRequest request;
  const _RequestDetailCard({required this.request});

  @override
  Widget build(BuildContext context) {
    String submittedLabel = '';
    String preferredLabel = '';

    try {
      final dt = DateTime.parse(request.createdAt);
      const months = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      submittedLabel = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {}

    if (request.preferredDates != null &&
        request.preferredDates!.isNotEmpty) {
      try {
        final dt = DateTime.parse(request.preferredDates!.first);
        const months = [
          'Jan','Feb','Mar','Apr','May','Jun',
          'Jul','Aug','Sep','Oct','Nov','Dec'
        ];
        preferredLabel = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
      } catch (_) {
        preferredLabel = request.preferredDates!.first;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111)),
                ),
              ),
              _StatusChip(status: request.status),
            ],
          ),
          if (request.topic != null && request.topic!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              request.topic!,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF5F5F5)),
          const SizedBox(height: 10),
          Row(
            children: [
              if (submittedLabel.isNotEmpty)
                _MetaItem(
                    icon: Icons.calendar_today_outlined,
                    label: 'Submitted',
                    value: submittedLabel),
              if (preferredLabel.isNotEmpty) ...[
                const SizedBox(width: 16),
                _MetaItem(
                    icon: Icons.event_outlined,
                    label: 'Preferred',
                    value: preferredLabel),
              ],
            ],
          ),
          if (request.notes != null && request.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                request.notes!,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF64748B), height: 1.4),
              ),
            ),
          ],
          if (request.status == 'declined' &&
              request.declineReason != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: Color(0xFFDC2626)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      request.declineReason!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFDC2626),
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetaItem(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF94A3B8))),
            Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111))),
          ],
        ),
      ],
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
        label = 'Approved';
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(100)),
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
