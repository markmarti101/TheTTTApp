import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../models/document.dart';
import '../services/document_service.dart';

class PaperworkScreen extends StatefulWidget {
  final String courseId;
  final String courseNumber;
  final String courseTitle;
  final String trainingCompanyId;
  final String trainerId;

  const PaperworkScreen({
    super.key,
    required this.courseId,
    required this.courseNumber,
    required this.courseTitle,
    required this.trainingCompanyId,
    required this.trainerId,
  });

  @override
  State<PaperworkScreen> createState() => _PaperworkScreenState();
}

class _PaperworkScreenState extends State<PaperworkScreen> {
  final _service = DocumentService();

  List<CourseDocument> _docs = [];
  bool _loading = true;
  final Set<String> _uploading = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final docs = await _service.getDocumentsByCourse(widget.courseId);
      if (mounted) setState(() { _docs = docs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _hasType(String type) => _docs.any((d) => d.type == type);

  Future<void> _upload(String type) async {
    setState(() => _uploading.add(type));
    try {
      final doc = await _service.pickAndUpload(
        courseId: widget.courseId,
        courseNumber: widget.courseNumber,
        trainingCompanyId: widget.trainingCompanyId,
        uploadedBy: widget.trainerId,
        uploaderRole: 'freelance_trainer',
        type: type,
      );
      if (doc != null && mounted) {
        await _load();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${DocumentType.label(type)} uploaded.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading.remove(type));
    }
  }

  Future<void> _delete(CourseDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove document?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text('Remove "${doc.fileName}"?',
            style: const TextStyle(color: Color(0xFF64748B))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteDocument(doc);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove: $e')),
        );
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final missingCount = DocumentType.trainerRequired
        .where((t) => !_hasType(t))
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: const Text('Course Paperwork'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _buildCourseHeader(),
                  const SizedBox(height: 16),
                  if (missingCount > 0) _buildMissingBanner(missingCount),
                  if (missingCount > 0) const SizedBox(height: 12),
                  _buildChecklistSection(),
                  const SizedBox(height: 16),
                  if (_docs.isNotEmpty) _buildAllDocumentsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildCourseHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.folder_outlined,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.courseTitle,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Course #${widget.courseNumber}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissingBanner(int count) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFD97706), size: 18),
          const SizedBox(width: 10),
          Text(
            '$count required ${count == 1 ? 'document' : 'documents'} missing',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E)),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistSection() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              'Required Paperwork',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111111),
                  letterSpacing: 0.3),
            ),
          ),
          ...DocumentType.trainerRequired.map((type) {
            final uploaded = _hasType(type);
            final isUploading = _uploading.contains(type);
            final uploadedDoc = uploaded
                ? _docs.firstWhere((d) => d.type == type)
                : null;
            return _ChecklistRow(
              type: type,
              uploaded: uploaded,
              isUploading: isUploading,
              uploadedDoc: uploadedDoc,
              onUpload: () => _upload(type),
              onOpen: uploadedDoc != null
                  ? () => _openUrl(uploadedDoc.downloadUrl)
                  : null,
              onDelete: uploadedDoc != null
                  ? () => _delete(uploadedDoc)
                  : null,
            );
          }),
          const SizedBox(height: 4),
          // Other docs upload button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: GestureDetector(
              onTap: _uploading.contains(DocumentType.other)
                  ? null
                  : () => _upload(DocumentType.other),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_uploading.contains(DocumentType.other))
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      )
                    else
                      const Icon(Icons.upload_file_outlined,
                          size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Upload other document',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllDocumentsSection() {
    final others = _docs
        .where((d) => !DocumentType.trainerRequired.contains(d.type))
        .toList();
    if (others.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Other Documents',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
              letterSpacing: 0.3),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: _cardDecoration(),
          child: Column(
            children: others
                .map((d) => _DocTile(
                      doc: d,
                      onOpen: () => _openUrl(d.downloadUrl),
                      onDelete: () => _delete(d),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      );
}

// ── Checklist row ─────────────────────────────────────────────────────────────

class _ChecklistRow extends StatelessWidget {
  final String type;
  final bool uploaded;
  final bool isUploading;
  final CourseDocument? uploadedDoc;
  final VoidCallback onUpload;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;

  const _ChecklistRow({
    required this.type,
    required this.uploaded,
    required this.isUploading,
    required this.uploadedDoc,
    required this.onUpload,
    this.onOpen,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final desc = DocumentType.description(type);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: uploaded
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : const Color(0xFFFFF7ED),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  uploaded
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  size: 16,
                  color: uploaded
                      ? AppColors.primary
                      : const Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DocumentType.label(type),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111111)),
                    ),
                    if (uploaded && uploadedDoc != null)
                      Text(
                        uploadedDoc!.fileName,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else if (desc.isNotEmpty)
                      Text(
                        desc,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                  ],
                ),
              ),
              if (isUploading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                )
              else if (uploaded) ...[
                if (onOpen != null)
                  GestureDetector(
                    onTap: onOpen,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('View',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                  ),
                const SizedBox(width: 6),
                if (onDelete != null)
                  GestureDetector(
                    onTap: onDelete,
                    child: const Icon(Icons.close,
                        size: 16, color: Color(0xFFCBD5E1)),
                  ),
              ] else
                GestureDetector(
                  onTap: onUpload,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Text('Upload',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD97706))),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
      ],
    );
  }
}

// ── Doc tile ──────────────────────────────────────────────────────────────────

class _DocTile extends StatelessWidget {
  final CourseDocument doc;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _DocTile({
    required this.doc,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.insert_drive_file_outlined,
                color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.fileName,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111111)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  DocumentType.label(doc.type),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onOpen,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('View',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close,
                size: 16, color: Color(0xFFCBD5E1)),
          ),
        ],
      ),
    );
  }
}
