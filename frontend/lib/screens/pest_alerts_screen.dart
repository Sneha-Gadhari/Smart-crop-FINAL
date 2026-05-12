import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/api_service.dart';

class PestAlertsScreen extends StatefulWidget {
  /// Optional crop hint from results screen (e.g. "Soybean")
  final String? cropHint;
  const PestAlertsScreen({super.key, this.cropHint});
  @override
  State<PestAlertsScreen> createState() => _PestAlertsScreenState();
}

class _PestAlertsScreenState extends State<PestAlertsScreen> {
  List<Map<String, dynamic>> _alerts = [];
  bool _loading = true;
  String _activeFilter = 'All';
  int _expandedIndex = -1;

  // ── Crop selector ─────────────────────────────────────────────────
  static const List<String> _cropOptions = [
    'All', 'Cotton', 'Soybean', 'Rice', 'Wheat', 'Maize', 'Sugarcane',
    'Onion', 'Tomato', 'Potato', 'Pigeonpeas', 'Groundnut', 'Banana',
  ];
  late String _selectedCrop;

  @override
  void initState() {
    super.initState();
    // Use the crop hint from the results screen if available
    _selectedCrop = widget.cropHint ?? 'All';
    if (!_cropOptions.contains(_selectedCrop)) {
      _selectedCrop = 'All';
    }
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    setState(() { _loading = true; });
    final state = context.read<AppState>();
    final district = state.selectedDistrict.isNotEmpty
        ? state.selectedDistrict
        : 'Nagpur';
    final season = state.season.isNotEmpty ? state.season : 'Kharif';

    try {
      final api = context.read<ApiService>();

      if (_selectedCrop == 'All') {
        const allCrops = [
          'Cotton', 'Soybean', 'Rice', 'Wheat', 'Maize', 'Sugarcane',
          'Onion', 'Tomato', 'Potato', 'Pigeonpeas', 'Groundnut', 'Banana',
        ];
        final results = await Future.wait(
          allCrops.map((c) => api
              .getPestAlerts(district, c, season: season)
              .catchError((_) => <String, dynamic>{})),
        );
        final merged = <Map<String, dynamic>>[];
        for (final data in results) {
          final alerts = data['alerts'] as List? ?? [];
          merged.addAll(alerts.cast<Map<String, dynamic>>());
        }
        setState(() { _alerts = merged; _loading = false; });
      } else {
        final data = await api.getPestAlerts(district, _selectedCrop, season: season);
        setState(() {
          _alerts = List<Map<String, dynamic>>.from(data['alerts'] ?? data);
          _loading = false;
        });
      }
    } catch (e) {
      setState(() { _alerts = []; _loading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load alerts: $e'),
            backgroundColor: AppTheme.accentAmber,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredAlerts {
    if (_activeFilter == 'All')       return _alerts;
    if (_activeFilter == 'Weather')   return _alerts.where((a) => a['alert_type'] == 'weather_prediction').toList();
    if (_activeFilter == 'Community') return _alerts.where((a) => a['alert_type'] == 'community').toList();
    if (_activeFilter == 'High')      return _alerts.where((a) => a['severity'] == 'HIGH').toList();
    return _alerts;
  }

  Color _severityColor(String s) {
    switch (s) {
      case 'HIGH':   return AppTheme.accentRed;
      case 'MEDIUM': return AppTheme.accentAmber;
      default:       return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state    = context.watch<AppState>();
    final district = state.selectedDistrict.isEmpty ? 'Nagpur' : state.selectedDistrict;
    final highCount = _alerts.where((a) => a['severity'] == 'HIGH').length;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Text('Pest Alerts — $district'),
            if (highCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: AppTheme.accentRed,
                    borderRadius: BorderRadius.circular(20)),
                child: Text('$highCount HIGH',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_alert_rounded, color: Colors.white),
        label: const Text('Report Sighting',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        onPressed: _showReportBottomSheet,
      ),
      body: Column(
        children: [
          // ── Crop selector + filter tabs ─────────────────────────
          _buildTopBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _filteredAlerts.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _fetchAlerts,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _filteredAlerts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _buildAlertCard(_filteredAlerts[i], i),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Crop dropdown
          Row(
            children: [
              const Text('Crop:',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedCrop,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: _cropOptions
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() { _selectedCrop = val; _expandedIndex = -1; });
                      _fetchAlerts();
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
                onPressed: _fetchAlerts,
                tooltip: 'Refresh alerts',
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Filter tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Weather', 'Community', 'High'].map((f) {
                final selected = _activeFilter == f;
                return GestureDetector(
                  onTap: () => setState(() { _activeFilter = f; _expandedIndex = -1; }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8, bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.primary : AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected ? AppTheme.primary : AppTheme.divider),
                    ),
                    child: Text(f,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : AppTheme.textSecondary)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert, int index) {
    final severity   = alert['severity'] as String? ?? 'MEDIUM';
    final isExpanded = _expandedIndex == index;
    final isWeather  = alert['alert_type'] == 'weather_prediction';
    final days       = alert['days_until_peak'];
    final reportCount= alert['report_count'] as int? ?? 0;

    return GestureDetector(
      onTap: () => setState(() => _expandedIndex = isExpanded ? -1 : index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
          boxShadow: isExpanded
              ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        child: Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                        color: _severityColor(severity),
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            bottomLeft: Radius.circular(16))),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Alert type + time
                          Row(
                            children: [
                              Icon(
                                isWeather
                                    ? Icons.cloud_outlined
                                    : Icons.people_outline_rounded,
                                color: isWeather
                                    ? const Color(0xFF0EA5E9)
                                    : const Color(0xFF7C3AED),
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isWeather ? 'Weather Alert' : 'Community Report',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isWeather
                                        ? const Color(0xFF0EA5E9)
                                        : const Color(0xFF7C3AED)),
                              ),
                              const Spacer(),
                              Text(alert['time_posted'] as String? ?? '',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppTheme.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Pest name + severity badge
                          Row(
                            children: [
                              Expanded(
                                child: Text(alert['pest_name'] as String? ?? '',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: _severityColor(severity).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: _severityColor(severity).withOpacity(0.3))),
                                child: Text(severity,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _severityColor(severity))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Crop + peak days
                          Text(
                            'Crop: ${alert['crop']}${days != null ? '  •  Peak risk in $days days' : ''}',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          // Trigger reason
                          Text(alert['trigger_reason'] as String? ?? '',
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.textPrimary,
                                  height: 1.4)),
                          // Community count badge
                          if (!isWeather && reportCount > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.people_outline_rounded,
                                    size: 13, color: AppTheme.primary),
                                const SizedBox(width: 4),
                                Text('$reportCount farmer(s) reported in district',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Expand chevron
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            // Expanded detail section
            if (isExpanded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _expandedSection('🚨 Immediate Action',
                        alert['action'] as String? ?? ''),
                    const SizedBox(height: 12),
                    _expandedSection('🌿 Organic Alternative',
                        alert['organic'] as String? ?? ''),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text('Share Alert with Nearby Farmers'),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _expandedSection(String title, String content) {
    if (content.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 6),
        Text(content,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
      ],
    );
  }

  Widget _buildEmptyState() {
    final state    = context.read<AppState>();
    final district = state.selectedDistrict.isEmpty ? 'your district' : state.selectedDistrict;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: AppTheme.primary, size: 60),
          const SizedBox(height: 16),
          const Text('No Active Alerts',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text(
            'No pest threats detected for\n$_selectedCrop in $district right now.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
            onPressed: _fetchAlerts,
          ),
        ],
      ),
    );
  }

  void _showReportBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportSightingSheet(
        initialCrop: _selectedCrop,
        onSubmitted: _fetchAlerts,  // Refresh after reporting
      ),
    );
  }
}

// ── Report Sighting Bottom Sheet ───────────────────────────────────
class _ReportSightingSheet extends StatefulWidget {
  final String initialCrop;
  final VoidCallback onSubmitted;
  const _ReportSightingSheet({required this.initialCrop, required this.onSubmitted});
  @override
  State<_ReportSightingSheet> createState() => _ReportSightingSheetState();
}

class _ReportSightingSheetState extends State<_ReportSightingSheet> {
  late String _crop;
  String _severity = 'MEDIUM';
  bool _submitting = false;
  final _pestController = TextEditingController();

  static const List<String> _crops = [
    'Cotton', 'Soybean', 'Rice', 'Wheat', 'Maize', 'Sugarcane',
    'Onion', 'Tomato', 'Potato', 'Pigeonpeas', 'Groundnut', 'Banana',
  ];

  @override
  void initState() {
    super.initState();
    _crop = _crops.contains(widget.initialCrop) ? widget.initialCrop : 'Cotton';
  }

  @override
  void dispose() {
    _pestController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pestName = _pestController.text.trim();
    if (pestName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the pest name or description')),
      );
      return;
    }

    setState(() => _submitting = true);

    final state    = context.read<AppState>();
    final district = state.selectedDistrict.isNotEmpty
        ? state.selectedDistrict
        : 'Nagpur';

    try {
      final api    = context.read<ApiService>();
      final result = await api.reportSighting(
        district: district,
        crop    : _crop,
        pest    : pestName,
        severity: _severity,
      );

      if (mounted) {
        Navigator.pop(context);
        final alerted = result['farmers_alerted'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Sighting reported — $alerted farmer(s) in $district notified'),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onSubmitted();  // Refresh the alerts list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: $e'),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          const Text('Report Pest Sighting',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          const Text('Help fellow farmers in your district',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 20),

          // Pest name field
          TextFormField(
            controller: _pestController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Pest Name / Description',
                hintText: 'e.g. Whitefly, Fall Armyworm, Brown Planthopper…'),
          ),
          const SizedBox(height: 14),

          // Affected crop dropdown
          DropdownButtonFormField<String>(
            value: _crop,
            decoration: const InputDecoration(labelText: 'Affected Crop'),
            items: _crops.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _crop = v!),
          ),
          const SizedBox(height: 14),

          // Severity selector
          const Text('Severity',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Row(
            children: ['LOW', 'MEDIUM', 'HIGH'].map((s) {
              Color c;
              if (s == 'LOW')        c = AppTheme.primary;
              else if (s == 'MEDIUM') c = AppTheme.accentAmber;
              else                   c = AppTheme.accentRed;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _severity = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: EdgeInsets.only(right: s != 'HIGH' ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _severity == s ? c.withOpacity(0.12) : AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _severity == s ? c : AppTheme.divider,
                          width: _severity == s ? 2 : 1),
                    ),
                    child: Text(s,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _severity == s ? c : AppTheme.textSecondary)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Report'),
            ),
          ),
        ],
      ),
    );
  }
}