import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/course_request.dart';
import '../providers/auth_provider.dart';
import '../services/requests_service.dart';
import '../services/trainers_service.dart';

class RequestDetailScreen extends StatefulWidget {
  final String requestId;

  const RequestDetailScreen({super.key, required this.requestId});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final _requestsService = RequestsService();
  final _trainersService = TrainersService();

  CourseRequest? _request;
  List<TrainerOption> _trainers = [];
  bool _loading = true;
  bool _actionLoading = false;
  String? _loadError;

  String _trainerId = '';
  DateTime? _scheduledAt;
  final _declineReasonController = TextEditingController();
  final _trainerIdController = TextEditingController();

  bool _showApprove = false;
  bool _showDecline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _declineReasonController.dispose();
    _trainerIdController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final companyId = auth.trainingCompanyId;

    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _requestsService.getRequest(widget.requestId),
        companyId != null
            ? _trainersService.getTrainers(companyId)
            : Future.value(<TrainerOption>[]),
      ]);

      final req = results[0] as CourseRequest?;
      final trainers = results[1] as List<TrainerOption>;

      if (req != null && req.status == 'pending') {
        await _requestsService.markRequestReviewed(widget.requestId);
        _request = CourseRequest(
          id: req.id,
          trainingCompanyId: req.trainingCompanyId,
          clientId: req.clientId,
          title: req.title,
          topic: req.topic,
          preferredDates: req.preferredDates,
          notes: req.notes,
          status: 'reviewed',
          declineReason: req.declineReason,
          createdAt: req.createdAt,
          updatedAt: req.updatedAt,
        );
      } else {
        _request = req;
      }

      setState(() {
        _trainers = trainers;
        _trainerId = trainers.isNotEmpty ? trainers.first.id : '';
        _trainerIdController.text = _trainerId;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  bool get _canAct {
    if (_request == null) return false;
    final auth = context.read<AuthProvider>();
    return (_request!.status == 'pending' || _request!.status == 'reviewed') &&
        auth.trainingCompanyId == _request!.trainingCompanyId;
  }

  Future<void> _handleApprove() async {
    if (_trainerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter a trainer ID')),
      );
      return;
    }
    if (_scheduledAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time')),
      );
      return;
    }

    setState(() => _actionLoading = true);
    try {
      await _requestsService.approveRequest(
        widget.requestId,
        _trainerId,
        _scheduledAt!,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _handleDecline() async {
    final reason = _declineReasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason')),
      );
      return;
    }

    setState(() => _actionLoading = true);
    try {
      await _requestsService.declineRequest(widget.requestId, reason);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request declined')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Request Details'),
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _request == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _loadError ?? 'Request not found',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Back'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _request!.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      if (_request!.topic != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Topic: ${_request!.topic}',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Status: ${_request!.status}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (_request!.preferredDates != null &&
                          _request!.preferredDates!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Preferred: ${_request!.preferredDates!.join(", ")}',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      if (_request!.notes != null && _request!.notes!.isNotEmpty)
                        ...[
                          const SizedBox(height: 8),
                          Text(
                            'Notes: ${_request!.notes}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      if (_request!.declineReason != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Declined: ${_request!.declineReason}',
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 14,
                          ),
                        ),
                      ],
                      if (_canAct && !_showApprove && !_showDecline) ...[
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () =>
                                  setState(() => _showApprove = true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Approve'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () =>
                                  setState(() => _showDecline = true),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                side: const BorderSide(
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                              child: const Text('Decline'),
                            ),
                          ],
                        ),
                      ],
                      if (_showApprove) _buildApproveForm(),
                      if (_showDecline) _buildDeclineForm(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildApproveForm() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Approve & create course',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Trainer', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          if (_trainers.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _trainerId.isEmpty ? null : _trainerId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _trainers
                  .map((t) => DropdownMenuItem(
                        value: t.id,
                        child: Text(t.displayName ?? t.email),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _trainerId = v ?? '';
                  _trainerIdController.text = _trainerId;
                });
              },
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _trainerIdController,
            decoration: InputDecoration(
              labelText:
                  _trainers.isEmpty ? 'Trainer ID (required)' : 'Or type trainer ID',
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _trainerId = v),
          ),
          const SizedBox(height: 16),
          const Text('Scheduled date & time',
              style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _scheduledAt != null
                  ? '${_scheduledAt!.day}/${_scheduledAt!.month}/${_scheduledAt!.year} ${_scheduledAt!.hour}:${_scheduledAt!.minute.toString().padLeft(2, '0')}'
                  : 'Tap to select',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null && mounted) {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null && mounted) {
                  setState(() {
                    _scheduledAt = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time.hour,
                      time.minute,
                    );
                  });
                }
              }
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton(
                onPressed: _actionLoading ? null : _handleApprove,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(_actionLoading ? 'Creating...' : 'Create course'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => setState(() => _showApprove = false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeclineForm() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Decline request',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _declineReasonController,
            decoration: const InputDecoration(
              labelText: 'Reason (required)',
              hintText: 'e.g. No availability for requested dates',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton(
                onPressed: _actionLoading ? null : _handleDecline,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                ),
                child: Text(_actionLoading ? 'Declining...' : 'Decline'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => setState(() => _showDecline = false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
