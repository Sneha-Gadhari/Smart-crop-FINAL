import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/api_service.dart';
import 'results_screen.dart';

class WizardScreen extends StatefulWidget {
  const WizardScreen({super.key});
  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  int _step = 0;
  bool _isLoading = false;
  String _loadingMsg = '';
  final PageController _pageController = PageController();

  // ── Soil classification result state ──────────────────────────────
  File?   _soilImageFile;
  String? _detectedSoilType;
  String? _detectedSoilDesc;
  double? _detectedSoilConfidence;
  List<String> _suggestedCrops = [];
  bool _soilAnalyzed = false;

  // ── Maharashtra focus — all 35 districts ──────────────────────────
  static const List<String> _states = ['Maharashtra'];

  static const Map<String, List<String>> _districtMap = {
    'Maharashtra': [
      'Ahilyanagar',
      'Akola',
      'Amravati',
      'Beed',
      'Bhandara',
      'Buldhana',
      'Chandrapur',
      'Chhatrapati Sambhajinagar',
      'Dharashiv',
      'Dhule',
      'Gadchiroli',
      'Gondia',
      'Hingoli',
      'Jalgaon',
      'Jalna',
      'Kolhapur',
      'Latur',
      'Mumbai suburban',
      'Nagpur',
      'Nanded',
      'Nandurbar',
      'Nashik',
      'Palghar',
      'Parbhani',
      'Pune',
      'Raigad',
      'Ratnagiri',
      'Sangli',
      'Satara',
      'Sindhudurg',
      'Solapur',
      'Thane',
      'Wardha',
      'Washim',
      'Yavatmal',
    ],
  };

  // ── Soil type icons matching Pixsoil model classes ─────────────────
  static const Map<String, String> _soilIcons = {
    'Alluvial Soil'   : '🌊',
    'Black Soil'      : '⬛',
    'Chalky Soil'     : '🪨',
    'Clay Soil'       : '🟤',
    'Humus Soil'      : '🌿',
    'Laterite Soil'   : '🧱',
    'Loamy Soil'      : '🌱',
    'Peat Soil'       : '🍂',
    'Red Soil'        : '🔴',
    'Sandy Loam Soil' : '🏜️',
    'Sandy Soil'      : '🏖️',
    // Short names fallback
    'Alluvial'        : '🌊',
    'Black'           : '⬛',
    'Chalky'          : '🪨',
    'Clay'            : '🟤',
    'Humus'           : '🌿',
    'Laterite'        : '🧱',
    'Loamy'           : '🌱',
    'Peat'            : '🍂',
    'Red'             : '🔴',
    'Sandy Loam'      : '🏜️',
    'Sandy'           : '🏖️',
  };

  void _goNext() {
    if (_step < 3) {
      setState(() => _step++);
      _pageController.animateToPage(_step,
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }
  }

  void _goPrev() {
    if (_step > 0) {
      setState(() => _step--);
      _pageController.animateToPage(_step,
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }
  }

  Future<void> _onDistrictSelected(String district, AppState state) async {
    setState(() { _isLoading = true; _loadingMsg = 'Loading district data...'; });
    try {
      final api      = context.read<ApiService>();
      final defaults = await api.getDistrictDefaults(district);
      state.soilType   = defaults['typical_soil_type'] ?? '';
      state.nitrogen   = ((defaults['npk_range']?['N_low'] ?? 60) + (defaults['npk_range']?['N_high'] ?? 80)) / 2.0;
      state.phosphorus = ((defaults['npk_range']?['P_low'] ?? 40) + (defaults['npk_range']?['P_high'] ?? 70)) / 2.0;
      state.potassium  = ((defaults['npk_range']?['K_low'] ?? 80) + (defaults['npk_range']?['K_high'] ?? 120)) / 2.0;
      state.ph         = ((defaults['avg_ph_range']?['low'] ?? 6.5) + (defaults['avg_ph_range']?['high'] ?? 7.5)) / 2.0;
      final primarySeason = defaults['primary_season'] as String?;
      if (primarySeason != null && primarySeason.isNotEmpty) {
        state.season = primarySeason == 'Whole Year' ? 'Kharif' : primarySeason;
      }
      // Fetch live weather right here
      try {
        final weather = await api.getWeather(district);
        state.weatherData = Map<String, dynamic>.from(weather);
      } catch (_) {}
      state.notifyListeners();
    } catch (_) {} finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Pick from camera OR gallery ────────────────────────────────────
  Future<void> _pickAndAnalyzeSoil(AppState state, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      _soilImageFile    = File(picked.path);
      _soilAnalyzed     = false;
      _detectedSoilType = null;
      _detectedSoilDesc = null;
      _isLoading        = true;
      _loadingMsg       = 'Analysing your soil image...';
    });

    try {
      final api    = context.read<ApiService>();
      final result = await api.analyzeSoilImage(_soilImageFile!);

      // Backend returns soil_type (full name) and soil_type_short
      final soilFull  = result['soil_type']       as String? ?? '';
      final soilShort = result['soil_type_short']  as String? ?? soilFull;

      state.updateSoilFromImage(result);

      setState(() {
        _detectedSoilType       = soilFull;
        _detectedSoilDesc       = result['description'] as String?;
        _detectedSoilConfidence = (result['confidence'] as num?)?.toDouble();
        _suggestedCrops         = List<String>.from(result['best_crops'] ?? []);
        _soilAnalyzed           = true;
      });
    } catch (e) {
      setState(() { _soilAnalyzed = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not analyse image: $e\nTry better lighting or enter values manually.'),
            backgroundColor: AppTheme.accentAmber,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitWizard(AppState state) async {
    setState(() { _isLoading = true; _loadingMsg = 'Getting your crop recommendations...'; });
    try {
      final api     = context.read<ApiService>();
      final weather = await api.getWeather(state.selectedDistrict);
      final result  = await api.recommendCrops(
        n: state.nitrogen, p: state.phosphorus,
        k: state.potassium, ph: state.ph,
        temp:       (weather['temperature'] ?? 28).toDouble(),
        humidity:   (weather['humidity'] ?? 70).toDouble(),
        rainfall:   (weather['rainfall'] ?? 800).toDouble(),
        season:     state.season,
        irrigation: state.irrigation,
        landAcres:  state.landAcres,
        budget:     state.hasBudget ? state.budget : null,
        district:   state.selectedDistrict,
        topN:       10,
      );
      state.setResults(
        List<Map<String, dynamic>>.from(result['crops'] ?? []),
        Map<String, dynamic>.from(result['weather'] ?? weather),
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ResultsScreen()),
        );
      }
    } catch (e) {
      // Show error + offer to proceed with mock
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backend error: $e'),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
        state.setResults(_mockCropResults(), _mockWeather());
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ResultsScreen()),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('Step ${_step + 1} of 4'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _step == 0 ? () => Navigator.pop(context) : _goPrev,
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildProgressBar(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1(state),
                    _buildStep2(state),
                    _buildStep3(state),
                    _buildStep4(state),
                  ],
                ),
              ),
            ],
          ),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    const labels = ['Location', 'Soil', 'Season', 'Budget'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        children: [
          Row(
            children: List.generate(4, (i) {
              final active = i <= _step;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: active ? AppTheme.primary : AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (i) => Text(
              labels[i],
              style: TextStyle(
                fontSize: 11,
                fontWeight: i == _step ? FontWeight.w700 : FontWeight.w500,
                color: i <= _step ? AppTheme.primary : AppTheme.textSecondary,
              ),
            )),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Location ───────────────────────────────────────────────
  Widget _buildStep1(AppState state) {
    final districts = _districtMap[state.selectedState] ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader('📍 Your Location',
              'Select your district — we\'ll auto-fill soil and weather data for your area'),
          const SizedBox(height: 24),
          _label('State'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: state.selectedState.isEmpty ? null : state.selectedState,
            hint: const Text('Select State'),
            decoration: const InputDecoration(),
            items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (val) {
              if (val != null) {
                state.selectedState    = val;
                state.selectedDistrict = '';
                state.notifyListeners();
              }
            },
          ),
          const SizedBox(height: 16),
          _label('District'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: state.selectedDistrict.isEmpty ? null : state.selectedDistrict,
            hint: const Text('Select District'),
            decoration: const InputDecoration(),
            isExpanded: true,
            items: districts
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (val) async {
              if (val != null) {
                state.selectedDistrict = val;
                state.notifyListeners();
                await _onDistrictSelected(val, state);
              }
            },
          ),
          if (state.selectedDistrict.isNotEmpty) ...[
            const SizedBox(height: 16),
            _autoFillBanner(state),
          ],
          const SizedBox(height: 32),
          _nextButton('Next: Soil Information →', _goNext,
              enabled: state.selectedDistrict.isNotEmpty),
        ],
      ),
    );
  }

  Widget _autoFillBanner(AppState state) {
    final weather = state.weatherData;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryLight.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 16),
            const SizedBox(width: 8),
            Text('${state.selectedDistrict} data loaded',
                style: const TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Text(
            'Soil: ${state.soilType.isEmpty ? '...' : state.soilType}  •  Season: ${state.season}',
            style: const TextStyle(fontSize: 12, color: AppTheme.primary),
          ),
          const SizedBox(height: 6),
          Text(
            'N: ${state.nitrogen.toStringAsFixed(0)}  P: ${state.phosphorus.toStringAsFixed(0)}  K: ${state.potassium.toStringAsFixed(0)}  pH: ${state.ph.toStringAsFixed(1)}',
            style: const TextStyle(fontSize: 12, color: AppTheme.primary),
          ),
          if (weather != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFBBDEBB)),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.wb_sunny_outlined, color: AppTheme.primary, size: 14),
              const SizedBox(width: 6),
              const Text('Live Weather', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary)),
            ]),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _weatherPill(Icons.thermostat_outlined, '${weather['temperature']}°C', 'Temp'),
              _weatherPill(Icons.water_drop_outlined, '${weather['humidity']}%', 'Humidity'),
              _weatherPill(Icons.grain_rounded, '${weather['rainfall']} mm', 'Rainfall'),
            ]),
          ] else ...[
            const SizedBox(height: 6),
            const Text('Fetching live weather...', style: TextStyle(fontSize: 11, color: AppTheme.primary)),
          ],
        ],
      ),
    );
  }

  Widget _weatherPill(IconData icon, String value, String label) {
    return Column(children: [
      Icon(icon, color: AppTheme.primary, size: 16),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
    ]);
  }

  // ── Step 2: Soil ───────────────────────────────────────────────────
  Widget _buildStep2(AppState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader('🪱 Soil Information',
              'Enter lab values or let AI detect soil type from a photo'),
          const SizedBox(height: 20),

          // ── Path toggle ────────────────────────────────────────────
          Row(
            children: [
              Expanded(child: _soilPathButton(
                  'I have a\nlab report', Icons.assignment_outlined,
                  state.hasLabReport, () {
                state.hasLabReport = true;
                setState(() { _soilAnalyzed = false; _soilImageFile = null; });
                state.notifyListeners();
              })),
              const SizedBox(width: 12),
              Expanded(child: _soilPathButton(
                  'Take / Upload\nsoil photo', Icons.photo_camera_outlined,
                  !state.hasLabReport, () {
                state.hasLabReport = false;
                state.notifyListeners();
              })),
            ],
          ),
          const SizedBox(height: 20),

          // ── Photo path UI ──────────────────────────────────────────
          if (!state.hasLabReport) ...[
            _buildPhotoSection(state),
            const SizedBox(height: 16),
          ],

          // ── Sliders ────────────────────────────────────────────────
          _soilSlider('Nitrogen (N)',   state.nitrogen,   0,   145, (v) { state.nitrogen   = v; state.notifyListeners(); }, 'mg/kg'),
          _soilSlider('Phosphorus (P)', state.phosphorus, 0,   145, (v) { state.phosphorus = v; state.notifyListeners(); }, 'mg/kg'),
          _soilSlider('Potassium (K)',  state.potassium,  0,   210, (v) { state.potassium  = v; state.notifyListeners(); }, 'mg/kg'),
          _soilSlider('Soil pH',        state.ph,         3.5, 9.9, (v) { state.ph         = v; state.notifyListeners(); }, 'pH'),
          const SizedBox(height: 8),
          _soilSummaryRow(state),
          const SizedBox(height: 24),
          _nextButton('Next: Season & Water →', _goNext),
        ],
      ),
    );
  }

  // ── Photo section ──────────────────────────────────────────────────
  Widget _buildPhotoSection(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image preview or placeholder
        if (_soilImageFile != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(_soilImageFile!,
                    width: double.infinity, height: 180, fit: BoxFit.cover),
              ),
              Positioned(
                top: 8, right: 8,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _soilImageFile    = null;
                    _soilAnalyzed     = false;
                    _detectedSoilType = null;
                    _detectedSoilDesc = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          )
        else
          Container(
            width: double.infinity, height: 130,
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.primaryLight.withOpacity(0.4), width: 2),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_outlined, color: AppTheme.primary, size: 36),
                SizedBox(height: 8),
                Text('No photo selected',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                SizedBox(height: 4),
                Text('Take a close-up of your soil in natural light',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _photoSourceButton(
                Icons.photo_camera_outlined, 'Camera',
                    () => _pickAndAnalyzeSoil(state, ImageSource.camera),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _photoSourceButton(
                Icons.photo_library_outlined, 'Gallery',
                    () => _pickAndAnalyzeSoil(state, ImageSource.gallery),
              ),
            ),
          ],
        ),

        // ── Soil Classification Result Card ──────────────────────────
        if (_soilAnalyzed && _detectedSoilType != null) ...[
          const SizedBox(height: 16),
          _buildSoilResultCard(),
        ],
      ],
    );
  }

  Widget _photoSourceButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primary, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary)),
          ],
        ),
      ),
    );
  }

  // ── Soil classification result card ───────────────────────────────
    Widget _buildSoilResultCard() {
      final conf    = _detectedSoilConfidence ?? 0.0;
      final emoji   = _soilIcons[_detectedSoilType] ??
          _soilIcons[_detectedSoilType?.split(' ').first] ?? '🌍';

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
                color: AppTheme.primary.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppTheme.primarySurface,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.grass_rounded,
                      color: AppTheme.primary, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Soil Detection Result',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Soil type display
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Detected Soil Type',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(_detectedSoilType!,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.3)),
                      if (_detectedSoilDesc != null && _detectedSoilDesc!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(_detectedSoilDesc!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                height: 1.4)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          /*// Confidence bar
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('Confidence',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('$confInt%',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: confColor)),
            ],
          ),*/
// Suggested crops
          if (_suggestedCrops.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Best crops for this soil',
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: _suggestedCrops.take(6).map((crop) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.2))),
                child: Text(crop,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w500)),
              )).toList(),
            ),
          ],

          // NPK auto-fill notice
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                borderRadius: BorderRadius.circular(8)),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 14),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'N, P, K and pH sliders have been auto-filled based on detected soil type.',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),

          // Low confidence warning
          if (conf < 65) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFE082))),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFF59E0B), size: 14),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'Try retaking in natural daylight on dry soil. Review the values below carefully.',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _soilPathButton(String label, IconData icon, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primarySurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.divider,
              width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? AppTheme.primary : AppTheme.textSecondary,
                size: 22),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppTheme.primary : AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _soilSlider(String label, double value, double min, double max,
      ValueChanged<double> onChanged, String unit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(8)),
                child: Text('${value.toStringAsFixed(1)} $unit',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${min.toStringAsFixed(0)} (Low)',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              Text('${max.toStringAsFixed(0)} (High)',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _soilSummaryRow(AppState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SoilValueChip('N',  state.nitrogen.toStringAsFixed(0)),
          _SoilValueChip('P',  state.phosphorus.toStringAsFixed(0)),
          _SoilValueChip('K',  state.potassium.toStringAsFixed(0)),
          _SoilValueChip('pH', state.ph.toStringAsFixed(1)),
        ],
      ),
    );
  }

  // ── Step 3: Season ─────────────────────────────────────────────────
  Widget _buildStep3(AppState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader('🌤 Season & Irrigation', 'Tell us about your growing conditions'),
          const SizedBox(height: 24),
          _label('Crop Season'),
          const SizedBox(height: 12),
          ...['Kharif', 'Rabi', 'Zaid'].map((s) {
            final info = {
              'Kharif': ('June–November', 'Soybean, Cotton, Rice, Maize, Pigeonpeas'),
              'Rabi'  : ('November–April', 'Wheat, Chickpea, Onion, Grapes, Lentil'),
              'Zaid'  : ('April–June',     'Watermelon, Muskmelon, Cucumber, Mungbean'),
            }[s]!;
            return _seasonCard(s, info.$1, info.$2, state.season == s, () {
              state.season = s;
              state.notifyListeners();
            });
          }),
          const SizedBox(height: 20),
          _label('Irrigation Availability'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _irrigationCard('Full',    Icons.water_drop_rounded, state.irrigation == 'Full',    () { state.irrigation = 'Full';    state.notifyListeners(); })),
              const SizedBox(width: 10),
              Expanded(child: _irrigationCard('Partial', Icons.water_outlined,     state.irrigation == 'Partial', () { state.irrigation = 'Partial'; state.notifyListeners(); })),
              const SizedBox(width: 10),
              Expanded(child: _irrigationCard('None',    Icons.wb_sunny_outlined,  state.irrigation == 'None',    () { state.irrigation = 'None';    state.notifyListeners(); })),
            ],
          ),
          const SizedBox(height: 20),
          _label('Farm Size (acres)'),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: state.landAcres.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(suffixText: 'acres'),
            onChanged: (v) {
              final parsed = double.tryParse(v);
              if (parsed != null && parsed > 0) {
                state.landAcres = parsed;
                state.notifyListeners();
              }
            },
          ),
          const SizedBox(height: 32),
          _nextButton('Next: Budget →', _goNext),
        ],
      ),
    );
  }

  Widget _seasonCard(String name, String dates, String crops, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primarySurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.divider,
              width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppTheme.primary : Colors.transparent,
                border: Border.all(
                    color: selected ? AppTheme.primary : AppTheme.textSecondary,
                    width: 2),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: selected ? AppTheme.primary : AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text('$dates  •  $crops',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _irrigationCard(String label, IconData icon, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primarySurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.divider,
              width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppTheme.primary : AppTheme.textSecondary, size: 24),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppTheme.primary : AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ── Step 4: Budget ─────────────────────────────────────────────────
  Widget _buildStep4(AppState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stepHeader('💰 Budget (Optional)',
              'Helps us calculate financial risk and profit potential for each crop'),
          const SizedBox(height: 8),
          const Text('We do not store this information.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _label('Budget per Acre'),
              TextButton(
                onPressed: () {
                  state.hasBudget = false;
                  state.notifyListeners();
                  _submitWizard(state);
                },
                child: const Text('Skip →',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.divider)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('₹',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary)),
                    Text(_formatCurrency(state.budget),
                        style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                            letterSpacing: -1)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('per acre',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                Slider(
                  value: state.budget,
                  min: 5000, max: 100000, divisions: 95,
                  label: '₹${_formatCurrency(state.budget)}',
                  onChanged: (v) {
                    state.budget    = v;
                    state.hasBudget = true;
                    state.notifyListeners();
                  },
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('₹5,000',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    Text('₹1,00,000',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome_rounded, size: 20),
              label: const Text('Get My Crop Recommendation'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18)),
              onPressed: () => _submitWizard(state),
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading overlay ────────────────────────────────────────────────
  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(40),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 3),
              const SizedBox(height: 20),
              Text(_loadingMsg,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              const Text('This takes about 2–3 seconds',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────
  Widget _stepHeader(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title,
          style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5)),
      const SizedBox(height: 6),
      Text(subtitle,
          style: const TextStyle(
              fontSize: 14, color: AppTheme.textSecondary, height: 1.4)),
    ],
  );

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
          letterSpacing: 0.1));

  Widget _nextButton(String label, VoidCallback onTap, {bool enabled = true}) =>
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: enabled ? onTap : null,
          style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18)),
          child: Text(label),
        ),
      );

  String _formatCurrency(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
    if (value >= 1000)   return '${(value / 1000).toStringAsFixed(0)},000';
    return value.toStringAsFixed(0);
  }

  // ── Mock data (Maharashtra-realistic) ─────────────────────────────
  List<Map<String, dynamic>> _mockCropResults() => [
    {
      'crop_name': 'Soybean', 'emoji': '🫘', 'confidence': 91.0,
      'risk_score': 32.0, 'risk_level': 'LOW',
      'risk_breakdown': {'weather': 22.0, 'market': 30.0, 'input_cost': 35.0, 'pest': 45.0},
      'explanation': ['Good nitrogen levels support strong soybean growth', 'Kharif season aligns with soybean\'s optimal growing cycle', 'Rainfall meets soybean\'s water requirements', 'Market demand for soybean is currently HIGH'],
      'market_signal': {'price_trend': 'UP', 'demand_level': 'HIGH', 'oversupply_risk': false, 'msp_price': 4600},
      'yield_estimate': '600–1100 kg  (6–11 qtl)', 'revenue_estimate': '₹27,600–₹50,600',
      'input_cost_estimate': '₹11,500',
    },
    {
      'crop_name': 'Cotton', 'emoji': '🌿', 'confidence': 78.0,
      'risk_score': 62.0, 'risk_level': 'HIGH',
      'risk_breakdown': {'weather': 30.0, 'market': 75.0, 'input_cost': 60.0, 'pest': 80.0},
      'explanation': ['Black soil suits cotton\'s water retention needs', 'High K levels support cotton fibre development', 'Long Kharif season matches cotton growth duration', 'High pest pressure — Whitefly and Bollworm monitoring needed'],
      'market_signal': {'price_trend': 'DOWN', 'demand_level': 'MEDIUM', 'oversupply_risk': true, 'msp_price': 6680},
      'yield_estimate': '200–500 kg  (2–5 qtl)', 'revenue_estimate': '₹13,360–₹33,400',
      'input_cost_estimate': '₹22,000',
    },
    {
      'crop_name': 'Pigeonpeas', 'emoji': '🫘', 'confidence': 63.0,
      'risk_score': 25.0, 'risk_level': 'LOW',
      'risk_breakdown': {'weather': 20.0, 'market': 25.0, 'input_cost': 20.0, 'pest': 20.0},
      'explanation': ['Moderate pH suits pigeonpeas cultivation', 'Low input cost makes this economically attractive', 'Government MSP support provides price floor', 'Kharif season aligns with pigeonpeas growing cycle'],
      'market_signal': {'price_trend': 'UP', 'demand_level': 'HIGH', 'oversupply_risk': false, 'msp_price': 7000},
      'yield_estimate': '400–800 kg  (4–8 qtl)', 'revenue_estimate': '₹28,000–₹56,000',
      'input_cost_estimate': '₹10,500',
    },
  ];

  Map<String, dynamic> _mockWeather() => {
    'temperature': 29.5, 'humidity': 72.0, 'rainfall': 820.0,
    'drought_flag': false, 'flood_flag': false, 'condition': 'Partly Cloudy',
  };
}

class _SoilValueChip extends StatelessWidget {
  final String label, value;
  const _SoilValueChip(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primary)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
    ],
  );
}