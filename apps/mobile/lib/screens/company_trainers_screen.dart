import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../services/company_directory_service.dart';

class CompanyTrainersScreen extends StatefulWidget {
  const CompanyTrainersScreen({super.key});

  @override
  State<CompanyTrainersScreen> createState() => _CompanyTrainersScreenState();
}

class _CompanyTrainersScreenState extends State<CompanyTrainersScreen> {
  final _service = CompanyDirectoryService();
  List<UserSummary> _trainers = [];
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
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load trainers: $e';
        _loading = false;
      });
    }
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
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _trainers.length,
                    itemBuilder: (context, index) {
                      final t = _trainers[index];
                      final name = t.displayName ?? t.email.split('@').first;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          subtitle: Text(
                            t.email,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

