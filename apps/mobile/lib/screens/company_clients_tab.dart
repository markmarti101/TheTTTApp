import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../services/company_directory_service.dart';
import 'add_client_screen.dart';
import 'edit_client_screen.dart';

class CompanyClientsTab extends StatefulWidget {
  const CompanyClientsTab({super.key});

  @override
  State<CompanyClientsTab> createState() => _CompanyClientsTabState();
}

class _CompanyClientsTabState extends State<CompanyClientsTab> {
  final _service = CompanyDirectoryService();
  final _searchController = TextEditingController();

  List<UserSummary> _clients = [];
  List<UserSummary> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.of(_clients)
          : _clients.where((c) {
              final name = (c.displayName ?? '').toLowerCase();
              return name.contains(q) || c.email.toLowerCase().contains(q);
            }).toList();
    });
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final companyId = auth.trainingCompanyId;
    if (companyId == null || companyId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No training company linked to this account.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.getClients(companyId);
      setState(() {
        _clients = result;
        _filtered = List.of(result);
        _loading = false;
      });
      _onSearch();
    } catch (e) {
      setState(() {
        _error = 'Failed to load clients.';
        _loading = false;
      });
    }
  }

  Future<void> _openAddClient() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddClientScreen()),
    );
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Clients',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111111),
                      ),
                    ),
                    if (!_loading && _error == null)
                      Text(
                        '${_clients.length} ${_clients.length == 1 ? 'client' : 'clients'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _openAddClient,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add_alt_1,
                          color: Colors.white, size: 15),
                      SizedBox(width: 6),
                      Text(
                        'Add Client',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (!_loading && _error == null && _clients.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search clients...',
                  hintStyle: const TextStyle(
                      color: Color(0xFFB0B8C1), fontSize: 14),
                  prefixIcon: const Icon(Icons.search,
                      color: Color(0xFFB0B8C1), size: 18),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            _onSearch();
                          },
                          child: const Icon(Icons.close,
                              color: Color(0xFFB0B8C1), size: 18),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
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
                  style:
                      TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              TextButton(
                  onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_clients.isEmpty) return _buildEmptyState();

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No clients match your search',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.88,
        ),
        itemCount: _filtered.length,
        itemBuilder: (_, i) => _ClientGridCard(
          client: _filtered[i],
          onTap: () async {
            if (_filtered[i].status == 'pending') return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    EditClientScreen(clientId: _filtered[i].id),
              ),
            );
            _load();
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
              child: Icon(Icons.people_outline,
                  size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'No clients yet',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111111)),
            ),
            const SizedBox(height: 6),
            Text(
              'Add your first client to get started.\nThey\'ll receive an invite to link their account.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openAddClient,
              icon: const Icon(Icons.person_add_alt_1, size: 16),
              label: const Text('Add First Client'),
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
}

// ─── Grid card ────────────────────────────────────────────────────────────────

class _ClientGridCard extends StatelessWidget {
  final UserSummary client;
  final VoidCallback onTap;

  const _ClientGridCard({required this.client, required this.onTap});

  static const _avatarColors = [
    Color(0xFF2DB89E),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
  ];

  Color get _avatarColor {
    final seed =
        client.email.codeUnits.fold(0, (sum, c) => sum + c);
    return _avatarColors[seed % _avatarColors.length];
  }

  String get _initials {
    final name =
        client.displayName ?? client.email.split('@').first;
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get _displayName =>
      client.displayName ?? client.email.split('@').first;

  bool get _isPending => client.status == 'pending';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: _avatarColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _initials,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _avatarColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                _displayName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Status badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isPending
                    ? const Color(0xFFFEF3C7)
                    : const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _isPending
                          ? const Color(0xFFD97706)
                          : const Color(0xFF059669),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isPending ? 'Pending' : 'Active',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _isPending
                          ? const Color(0xFFD97706)
                          : const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
