import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../models/venue.dart';
import '../providers/auth_provider.dart';
import '../services/venues_service.dart';
import 'add_venue_screen.dart';

class CompanyVenuesScreen extends StatefulWidget {
  const CompanyVenuesScreen({super.key});

  @override
  State<CompanyVenuesScreen> createState() => _CompanyVenuesScreenState();
}

class _CompanyVenuesScreenState extends State<CompanyVenuesScreen> {
  final _service = VenuesService();

  List<Venue> _venues = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final companyId = auth.trainingCompanyId;
    if (companyId == null || companyId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No training company linked.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.getVenues(companyId);
      setState(() {
        _venues = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load venues.';
        _loading = false;
      });
    }
  }

  Future<void> _openAddVenue() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddVenueScreen()),
    );
    if (added == true) _load();
  }

  Future<void> _deleteVenue(Venue venue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete venue?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Remove "${venue.name}" from your venues. This cannot be undone.',
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteVenue(venue.id);
      setState(() => _venues.removeWhere((v) => v.id == venue.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${venue.name}" removed.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete venue.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      floatingActionButton: !_loading && _error == null && _venues.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: _openAddVenue,
              child: const Icon(Icons.add_location_alt_outlined),
            )
          : null,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      size: 16, color: Color(0xFF111111)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Venues',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111111),
                      ),
                    ),
                    if (!_loading && _error == null)
                      Text(
                        '${_venues.length} ${_venues.length == 1 ? 'venue' : 'venues'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
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

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined,
                  size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              TextButton(
                  onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_venues.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.location_on_outlined,
                    size: 36, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              const Text(
                'No venues yet',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111)),
              ),
              const SizedBox(height: 6),
              Text(
                'Add your training venues here.\nThey\'ll appear as options when approving requests.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _openAddVenue,
                icon: const Icon(Icons.add_location_alt_outlined,
                    size: 16),
                label: const Text('Add First Venue'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _venues.length,
        itemBuilder: (_, i) => _VenueCard(
          venue: _venues[i],
          onDelete: () => _deleteVenue(_venues[i]),
        ),
      ),
    );
  }
}

// ─── Venue card ───────────────────────────────────────────────────────────────

class _VenueCard extends StatelessWidget {
  final Venue venue;
  final VoidCallback onDelete;

  const _VenueCard({required this.venue, required this.onDelete});

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.location_on_outlined,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    venue.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    venue.address,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (venue.capacity != null || venue.detailsDocumentUrl != null) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (venue.capacity != null)
                          _badge(
                            icon: Icons.people_outline,
                            label: 'Capacity: ${venue.capacity}',
                            bgColor: const Color(0xFFF0FDF4),
                            fgColor: const Color(0xFF059669),
                          ),
                        if (venue.detailsDocumentUrl != null &&
                            venue.detailsDocumentUrl!.isNotEmpty)
                          GestureDetector(
                            onTap: () =>
                                _openUrl(venue.detailsDocumentUrl!),
                            child: _badge(
                              icon: Icons.description_outlined,
                              label: 'Venue details',
                              bgColor: AppColors.primary.withValues(alpha: 0.08),
                              fgColor: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline,
                    size: 16, color: Color(0xFFDC2626)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color fgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fgColor),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: fgColor)),
        ],
      ),
    );
  }
}
