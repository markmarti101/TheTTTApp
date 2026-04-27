import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../services/company_directory_service.dart';
import 'add_trainer_screen.dart';
import 'trainer_detail_screen.dart';

class CompanyTrainersScreen extends StatefulWidget {
  const CompanyTrainersScreen({super.key});

  @override
  State<CompanyTrainersScreen> createState() => _CompanyTrainersScreenState();
}

class _CompanyTrainersScreenState extends State<CompanyTrainersScreen> {
  final _service = CompanyDirectoryService();
  final _searchController = TextEditingController();
  List<UserSummary> _trainers = [];
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
          ? List.of(_trainers)
          : _trainers.where((t) {
              final name = (t.displayName ?? '').toLowerCase();
              return name.contains(q) || t.email.toLowerCase().contains(q);
            }).toList();
    });
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final companyId = auth.trainingCompanyId;
    if (companyId == null || companyId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'No training company linked to this admin account.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _service.getTrainers(companyId);
      setState(() {
        _trainers = result;
        _filtered = List.of(result);
        _loading = false;
      });
      _onSearch();
    } catch (e) {
      setState(() {
        _error = 'Failed to load trainers: $e';
        _loading = false;
      });
    }
  }

  Future<void> _goToAddTrainer() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddTrainerScreen()),
    );
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: const Text('Freelance Trainers'),
        actions: [
          if (!_loading && _trainers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              tooltip: 'Add Trainer',
              onPressed: _goToAddTrainer,
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _trainers.isEmpty
                  ? _buildEmptyState()
                  : Column(
                      children: [
                        _buildSearchBar(),
                        Expanded(
                          child: _filtered.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.search_off,
                                          size: 48,
                                          color: Colors.grey.shade300),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No trainers match your search',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF111111),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : RefreshIndicator(
                                  color: AppColors.primary,
                                  onRefresh: _load,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 8, 16, 32),
                                    itemCount: _filtered.length,
                                    itemBuilder: (context, index) {
                                      final t = _filtered[index];
                                      final name = t.displayName ??
                                          t.email.split('@').first;
                                      return _buildTrainerCard(t, name);
                                    },
                                  ),
                                ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search trainers...',
            hintStyle:
                const TextStyle(color: Color(0xFFB0B8C1), fontSize: 14),
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
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group_outlined,
                size: 42,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No trainers yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Invite a freelance trainer to your company.\nThey\'ll be linked automatically when they sign up.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            // Add trainer card
            GestureDetector(
              onTap: _goToAddTrainer,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: 18, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_add_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add a Trainer',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Send an invite by email',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainerCard(UserSummary t, String name) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TrainerDetailScreen(
              trainerId: t.id,
              trainerName: name,
              trainerEmail: t.email,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.primary,
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
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.email,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFFCBD5E1), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
