import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/course.dart';
import '../models/resource.dart';
import '../services/courses_service.dart';
import '../services/resource_service.dart';

class ResourcesScreen extends StatefulWidget {
  final String companyId;
  const ResourcesScreen({super.key, required this.companyId});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  final _service = ResourceService();
  final _coursesService = CoursesService();

  List<Resource> _resources = [];
  List<ResourceAllocation> _allocations = [];
  List<Course> _courses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _service.getResources(widget.companyId),
      _service.getAllocations(widget.companyId),
      _coursesService.getCoursesByCompanyOrdered(widget.companyId),
    ]);
    if (!mounted) return;
    setState(() {
      _resources = results[0] as List<Resource>;
      _allocations = results[1] as List<ResourceAllocation>;
      _courses = (results[2] as List<Course>)
          .where((c) =>
              c.status != 'completed' &&
              c.status != 'declined' &&
              c.status != 'trainer_declined')
          .toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));
      _loading = false;
    });
  }

  int _allocatedFor(String resourceId) => _allocations
      .where((a) => a.resourceId == resourceId)
      .fold(0, (sum, a) => sum + a.quantity);

  List<Resource> get _lowStockResources => _resources.where((r) {
        final available = r.totalStock - _allocatedFor(r.id);
        return available <= r.reorderThreshold;
      }).toList();

  // ── Add / Edit resource sheet ───────────────────────────────────────────────

  Future<void> _showAddEditSheet([Resource? existing]) async {
    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    final stockCtrl = TextEditingController(
        text: existing != null ? '${existing.totalStock}' : '');
    final thresholdCtrl = TextEditingController(
        text: existing != null ? '${existing.reorderThreshold}' : '');
    String category = existing?.category ?? 'book';
    String unit = existing?.unit ?? 'copies';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          return Padding(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    existing == null ? 'Add Resource' : 'Edit Resource',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  // Name
                  _sheetField('Name', nameCtrl, hint: 'e.g. First Aid Manual'),
                  const SizedBox(height: 12),
                  // Category chips
                  const Text('Category',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: ['book', 'equipment', 'material', 'other']
                        .map((c) => ChoiceChip(
                              label: Text(_categoryLabel(c)),
                              selected: category == c,
                              selectedColor:
                                  AppColors.primary.withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: category == c
                                    ? AppColors.primary
                                    : const Color(0xFF64748B),
                              ),
                              onSelected: (_) => setS(() => category = c),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  // Unit chips
                  const Text('Unit',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: ['copies', 'units', 'sets', 'packs']
                        .map((u) => ChoiceChip(
                              label: Text(u),
                              selected: unit == u,
                              selectedColor:
                                  AppColors.primary.withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: unit == u
                                    ? AppColors.primary
                                    : const Color(0xFF64748B),
                              ),
                              onSelected: (_) => setS(() => unit = u),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _sheetField('Total Stock', stockCtrl,
                            hint: '0', numeric: true),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _sheetField(
                            'Reorder Threshold', thresholdCtrl,
                            hint: '0', numeric: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        final stock =
                            int.tryParse(stockCtrl.text.trim()) ?? 0;
                        final threshold =
                            int.tryParse(thresholdCtrl.text.trim()) ?? 0;
                        if (name.isEmpty) return;
                        Navigator.pop(ctx);
                        final now =
                            DateTime.now().toUtc().toIso8601String();
                        if (existing == null) {
                          await _service.addResource(Resource(
                            id: '',
                            trainingCompanyId: widget.companyId,
                            name: name,
                            category: category,
                            totalStock: stock,
                            reorderThreshold: threshold,
                            unit: unit,
                            createdAt: now,
                            updatedAt: now,
                          ));
                        } else {
                          await _service.updateResource(Resource(
                            id: existing.id,
                            trainingCompanyId: existing.trainingCompanyId,
                            name: name,
                            category: category,
                            totalStock: stock,
                            reorderThreshold: threshold,
                            unit: unit,
                            createdAt: existing.createdAt,
                            updatedAt: now,
                          ));
                        }
                        await _load();
                      },
                      child: Text(existing == null ? 'Add Resource' : 'Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _sheetField(String label, TextEditingController ctrl,
      {String hint = '', bool numeric = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569))),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType:
              numeric ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.primary)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
          ),
        ),
      ],
    );
  }

  // ── Allocate sheet ──────────────────────────────────────────────────────────

  Future<void> _showAllocateSheet(Resource resource) async {
    if (_courses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No active courses to allocate to.')),
      );
      return;
    }

    Course? selectedCourse;
    final qtyCtrl = TextEditingController(text: '1');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          return Padding(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Allocate ${resource.name}',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_allocatedFor(resource.id)} / ${resource.totalStock} ${resource.unit} allocated',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                const Text('Course',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569))),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border:
                        Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Course>(
                      value: selectedCourse,
                      isExpanded: true,
                      hint: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Select a course',
                            style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFFCBD5E1))),
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      items: _courses
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c.title,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (c) =>
                          setS(() => selectedCourse = c),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _sheetField('Quantity', qtyCtrl,
                    hint: '1', numeric: true),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: selectedCourse == null
                        ? null
                        : () async {
                            final qty = int.tryParse(
                                    qtyCtrl.text.trim()) ??
                                1;
                            if (qty <= 0) return;
                            Navigator.pop(ctx);
                            await _service.addAllocation(
                              ResourceAllocation(
                                id: '',
                                trainingCompanyId: widget.companyId,
                                resourceId: resource.id,
                                courseId: selectedCourse!.id,
                                courseTitle: selectedCourse!.title,
                                quantity: qty,
                                allocatedAt: DateTime.now()
                                    .toUtc()
                                    .toIso8601String(),
                              ),
                            );
                            await _load();
                          },
                    child: const Text('Allocate'),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // ── Resource detail sheet ───────────────────────────────────────────────────

  Future<void> _showDetailSheet(Resource resource) async {
    final resourceAllocs = _allocations
        .where((a) => a.resourceId == resource.id)
        .toList()
      ..sort((a, b) => b.allocatedAt.compareTo(a.allocatedAt));
    final allocated = _allocatedFor(resource.id);
    final available = resource.totalStock - allocated;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (ctx, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: ListView(
                controller: scrollCtrl,
                children: [
                  Row(
                    children: [
                      _CategoryIcon(category: resource.category, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(resource.name,
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800)),
                            Text(
                              '${_categoryLabel(resource.category)} · ${resource.unit}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAddEditSheet(resource);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Stock summary
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        _StockStat(
                            label: 'Total',
                            value: resource.totalStock,
                            unit: resource.unit,
                            color: const Color(0xFF64748B)),
                        const SizedBox(width: 16),
                        _StockStat(
                            label: 'Allocated',
                            value: allocated,
                            unit: resource.unit,
                            color: const Color(0xFFF59E0B)),
                        const SizedBox(width: 16),
                        _StockStat(
                            label: 'Available',
                            value: available,
                            unit: resource.unit,
                            color: available <= resource.reorderThreshold
                                ? const Color(0xFFDC2626)
                                : AppColors.primary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Allocations',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAllocateSheet(resource);
                        },
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add',
                            style: TextStyle(fontSize: 13)),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary),
                      ),
                    ],
                  ),
                  if (resourceAllocs.isEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'No allocations yet',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    ...resourceAllocs.map((a) => _AllocationRow(
                          allocation: a,
                          unit: resource.unit,
                          onDelete: () async {
                            Navigator.pop(ctx);
                            await _service.removeAllocation(a.id);
                            await _load();
                          },
                        )),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lowStock = _lowStockResources;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
      children: [
        _buildHeader(),
        if (!_loading && lowStock.isNotEmpty) _buildShortageBanner(lowStock),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: _resources.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          physics:
                              const AlwaysScrollableScrollPhysics(),
                          itemCount: _resources.length,
                          itemBuilder: (_, i) {
                            final r = _resources[i];
                            final allocated = _allocatedFor(r.id);
                            return _ResourceCard(
                              resource: r,
                              allocated: allocated,
                              onTap: () => _showDetailSheet(r),
                              onAllocate: () => _showAllocateSheet(r),
                            );
                          },
                        ),
                ),
        ),
      ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFFF5F6FA),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
          const Expanded(
            child: Text(
              'Resources',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF111111)),
            ),
          ),
          if (_resources.isNotEmpty)
          GestureDetector(
            onTap: () => _showAddEditSheet(),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add, color: Colors.white, size: 15),
                  SizedBox(width: 4),
                  Text(
                    'Add',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortageBanner(List<Resource> lowStock) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFF59E0B), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lowStock.length == 1
                  ? '${lowStock.first.name} is low on stock'
                  : '${lowStock.length} resources are low on stock',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF92400E)),
            ),
          ),
        ],
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
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.inventory_2_outlined,
                    color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 14),
              const Text('No resources yet',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Add books, equipment, and materials\nto track stock levels',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => _showAddEditSheet(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text(
                    'Add your first resource',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Resource card ─────────────────────────────────────────────────────────────

class _ResourceCard extends StatelessWidget {
  final Resource resource;
  final int allocated;
  final VoidCallback onTap;
  final VoidCallback onAllocate;

  const _ResourceCard({
    required this.resource,
    required this.allocated,
    required this.onTap,
    required this.onAllocate,
  });

  @override
  Widget build(BuildContext context) {
    final available = resource.totalStock - allocated;
    final isLow = available <= resource.reorderThreshold;
    final isOver = available < 0;
    final fillRatio = resource.totalStock == 0
        ? 0.0
        : (allocated / resource.totalStock).clamp(0.0, 1.0);

    final barColor = isOver
        ? const Color(0xFFDC2626)
        : isLow
            ? const Color(0xFFF59E0B)
            : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
        child: Column(
          children: [
            Row(
              children: [
                _CategoryIcon(category: resource.category),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(resource.name,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111111))),
                      const SizedBox(height: 2),
                      Text(
                        _categoryLabel(resource.category),
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                if (isLow || isOver)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isOver
                          ? const Color(0xFFFEE2E2)
                          : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      isOver ? 'Over-allocated' : 'Low stock',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isOver
                              ? const Color(0xFFDC2626)
                              : const Color(0xFFF59E0B)),
                    ),
                  ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onAllocate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'Allocate',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Stock bar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fillRatio,
                          minHeight: 6,
                          backgroundColor:
                              const Color(0xFFF1F5F9),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$allocated allocated · $available available · ${resource.totalStock} total ${resource.unit}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Allocation row ────────────────────────────────────────────────────────────

class _AllocationRow extends StatelessWidget {
  final ResourceAllocation allocation;
  final String unit;
  final VoidCallback onDelete;

  const _AllocationRow({
    required this.allocation,
    required this.unit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allocation.courseTitle.isNotEmpty
                      ? allocation.courseTitle
                      : 'Course',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${allocation.quantity} $unit',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: Color(0xFFDC2626)),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── Stock stat ────────────────────────────────────────────────────────────────

class _StockStat extends StatelessWidget {
  final String label;
  final int value;
  final String unit;
  final Color color;

  const _StockStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8))),
        const SizedBox(height: 2),
        Text(
          '$value',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1),
        ),
        Text(unit,
            style: const TextStyle(
                fontSize: 10, color: Color(0xFF94A3B8))),
      ],
    );
  }
}

// ── Category icon ─────────────────────────────────────────────────────────────

class _CategoryIcon extends StatelessWidget {
  final String category;
  final double size;
  const _CategoryIcon({required this.category, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (category) {
      'book' => (Icons.menu_book_outlined, const Color(0xFF6366F1)),
      'equipment' => (Icons.build_outlined, const Color(0xFF0891B2)),
      'material' => (Icons.layers_outlined, const Color(0xFF059669)),
      _ => (Icons.inventory_2_outlined, const Color(0xFF64748B)),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _categoryLabel(String c) => switch (c) {
      'book' => 'Book',
      'equipment' => 'Equipment',
      'material' => 'Material',
      _ => 'Other',
    };
