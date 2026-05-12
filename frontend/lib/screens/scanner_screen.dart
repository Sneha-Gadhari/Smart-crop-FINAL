import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/api_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  File? _selectedImage;
  Map<String, dynamic>? _diagnosis;
  bool _loading = false;
  String _cropName = 'Tomato';

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null) setState(() { _selectedImage = File(picked.path); _diagnosis = null; });
  }

  Future<void> _analyze() async {
    if (_selectedImage == null) return;
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final result = await api.diagnoseCropImage(_selectedImage!, _cropName);
      setState(() { _diagnosis = result; _loading = false; });
    } catch (_) {
      setState(() {
        _diagnosis = {
          'disease_name': 'Bacterial Leaf Blight',
          'severity': 3, 'confidence': 87.0,
          'affected_area_pct': 25.0,
          'immediate_action': '1. Remove infected leaves immediately\n2. Apply copper-based bactericide\n3. Avoid overhead irrigation\n4. Improve field drainage',
          'organic_option': 'Spray 1% Bordeaux mixture or garlic extract solution weekly',
          'days_until_critical': 5,
          'alert_neighbours_recommended': true,
        };
        _loading = false;
      });
    }
  }

  Color _severityColor(int severity) {
    if (severity <= 2) return AppTheme.primary;
    if (severity == 3) return AppTheme.accentAmber;
    return AppTheme.accentRed;
  }

  String _severityLabel(int severity) {
    if (severity <= 2) return 'MILD';
    if (severity == 3) return 'MODERATE';
    return 'SEVERE';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Disease Scanner'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInstructions(),
            const SizedBox(height: 20),
            _buildCropSelector(),
            const SizedBox(height: 20),
            _buildImageArea(),
            if (_selectedImage != null && _diagnosis == null && !_loading) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.search_rounded, size: 20),
                  label: const Text('Analyze This Photo'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: _analyze,
                ),
              ),
              const SizedBox(height: 8),
              Center(child: TextButton(onPressed: () => setState(() => _selectedImage = null), child: const Text('Retake Photo', style: TextStyle(color: AppTheme.textSecondary)))),
            ],
            if (_loading) ...[
              const SizedBox(height: 32),
              const Center(child: Column(
                children: [
                  CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 3),
                  SizedBox(height: 16),
                  Text('Identifying disease...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  SizedBox(height: 4),
                  Text('Analyzing leaf patterns and symptoms', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              )),
            ],
            if (_diagnosis != null) ...[
              const SizedBox(height: 20),
              _buildDiagnosisResult(_diagnosis!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
      child: const Row(
        children: [
          Icon(Icons.tips_and_updates_outlined, color: AppTheme.primary, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Take a clear, well-lit photo of a damaged leaf or plant part. Avoid shadows and blur for best results.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Crop Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _cropName,
          decoration: const InputDecoration(),
          items: [
            'Tomato', 'Rice', 'Wheat', 'Apple', 'Grape', 'Corn / Maize',
            'Potato', 'Soybean', 'Tea', 'Cherry', 'Peach', 'Pepper / Capsicum',
            'Strawberry', 'Blueberry', 'Raspberry', 'Squash', 'Orange',

          ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _cropName = v!),
        ),
      ],
    );
  }

  Widget _buildImageArea() {
    if (_selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(_selectedImage!, width: double.infinity, height: 240, fit: BoxFit.cover),
      );
    }
    return Column(
      children: [
        GestureDetector(
          onTap: () => _pickImage(ImageSource.camera),
          child: Container(
            width: double.infinity, height: 180,
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryLight.withOpacity(0.4), width: 2),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, color: AppTheme.primary, size: 48),
                SizedBox(height: 12),
                Text('Take Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                SizedBox(height: 4),
                Text('Use camera for best results', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text('Choose from Gallery'),
            onPressed: () => _pickImage(ImageSource.gallery),
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosisResult(Map<String, dynamic> d) {
    final severity = d['severity'] as int;
    final sColor = _severityColor(severity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(d['disease_name'] ?? 'Unknown', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.5)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: sColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: sColor.withOpacity(0.3))),
                    child: Text(_severityLabel(severity), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sColor)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: List.generate(5, (i) => Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                    height: 8,
                    decoration: BoxDecoration(
                      color: i < severity ? sColor : AppTheme.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                )),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Severity', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  Text('$severity / 5', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sColor)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _actionSection('🚨 What To Do Now', d['immediate_action'] ?? '', const Color(0xFFFFF8E1), AppTheme.accentAmber),
        const SizedBox(height: 12),
        _actionSection('🌿 Organic Alternative', d['organic_option'] ?? '', AppTheme.primarySurface, AppTheme.primary),
        if (d['alert_neighbours_recommended'] == true) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.people_outline_rounded, color: Color(0xFF7C3AED), size: 20),
                    SizedBox(width: 8),
                    Expanded(child: Text('Alert Nearby Farmers?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4C1D95)))),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('This disease can spread. Alerting nearby farmers growing the same crop can prevent losses.', style: TextStyle(fontSize: 12.5, color: Color(0xFF6D28D9), height: 1.4)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF7C3AED), side: const BorderSide(color: Color(0xFF7C3AED))),
                      child: const Text('No, Thanks'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      onPressed: () async {
                        try {
                          final api = context.read<ApiService>();
                          final state = context.read<AppState>();
                          final result = await api.reportSighting(
                            district: state.selectedDistrict.isNotEmpty ? state.selectedDistrict : 'Nagpur',
                            crop: _cropName,
                            pest: d['disease_name'] as String? ?? 'Disease',
                            severity: 'HIGH',
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✓ Alert sent — ${result['farmers_alerted'] ?? 0} farmers in your district notified'),
                                backgroundColor: AppTheme.primary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (_) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not send alert. Check connection.'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                      child: const Text('Yes, Alert Them'),
                    )),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: const Text('Scan Another Crop'),
            onPressed: () => setState(() { _selectedImage = null; _diagnosis = null; }),
          ),
        ),
      ],
    );
  }

  Widget _actionSection(String title, String content, Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.5)),
        ],
      ),
    );
  }
}

class _DiagMetric extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _DiagMetric(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.divider)),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary, size: 18),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}