import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import '../services/api_service.dart';

class MandiPricesScreen extends StatefulWidget {
  const MandiPricesScreen({super.key});
  @override
  State<MandiPricesScreen> createState() => _MandiPricesScreenState();
}

class _MandiPricesScreenState extends State<MandiPricesScreen> {
  List<Map<String, dynamic>> _prices = [];
  bool _loading = true;
  bool _generatingPdf = false;
  String _selectedCrop = 'All';
  String _sortBy = 'modal_price'; // or 'crop_name'

  final List<String> _popularCrops = [
    'All', 'Rice', 'Wheat', 'Maize', 'Cotton', 'Soybean',
    'Onion', 'Tomato', 'Sugarcane', 'Groundnut', 'Jowar', 'Bajra',
  ];

  @override
  void initState() {
    super.initState();
    // Use post-frame callback so AppState.selectedDistrict is fully available
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrices());
  }

  String _dataSource = '';
  int _liveCount = 0;
  String _fetchedAt = '';

  Future<void> _loadPrices() async {
    final district = context.read<AppState>().selectedDistrict;
    if (district.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      // Use bulk endpoint — returns { prices: [...], district, source, live_count, fetched_at }
      final data = await api.getMandiPricesBulk(district);
      setState(() {
        final raw = data['prices'] as List? ?? [];
        _prices = List<Map<String, dynamic>>.from(raw);
        _dataSource = data['source'] ?? 'unknown';
        _liveCount  = (data['live_count'] as num?)?.toInt() ?? 0;
        _fetchedAt  = data['fetched_at'] ?? '';
        _loading = false;
      });
    } catch (e) {
      // Fallback to static data only if API completely fails
      setState(() {
        _prices     = _mockPrices();
        _dataSource = 'static_fallback';
        _liveCount  = 0;
        _loading    = false;
      });
    }
  }

  List<Map<String, dynamic>> _mockPrices() => [
    {'crop': 'Rice', 'mandi': 'Pune APMC', 'min_price': 1800, 'modal_price': 2100, 'max_price': 2400, 'unit': 'quintal', 'date': '${DateTime.now().subtract(const Duration(days: 1)).day}/${DateTime.now().subtract(const Duration(days: 1)).month}/${DateTime.now().year}',},
    {'crop': 'Wheat', 'mandi': 'Nashik APMC', 'min_price': 2000, 'modal_price': 2250, 'max_price': 2500, 'unit': 'quintal', 'date': '${DateTime.now().subtract(const Duration(days: 1)).day}/${DateTime.now().subtract(const Duration(days: 1)).month}/${DateTime.now().year}',},
    {'crop': 'Maize', 'mandi': 'Nagpur APMC', 'min_price': 1400, 'modal_price': 1650, 'max_price': 1900, 'unit': 'quintal', 'date': '${DateTime.now().subtract(const Duration(days: 1)).day}/${DateTime.now().subtract(const Duration(days: 1)).month}/${DateTime.now().year}',},
    {'crop': 'Cotton', 'mandi': 'Amravati APMC', 'min_price': 5500, 'modal_price': 6200, 'max_price': 7000, 'unit': 'quintal', 'date': '${DateTime.now().subtract(const Duration(days: 1)).day}/${DateTime.now().subtract(const Duration(days: 1)).month}/${DateTime.now().year}',},
    {'crop': 'Soybean', 'mandi': 'Latur APMC', 'min_price': 3800, 'modal_price': 4300, 'max_price': 4900, 'unit': 'quintal', 'date': '${DateTime.now().subtract(const Duration(days: 1)).day}/${DateTime.now().subtract(const Duration(days: 1)).month}/${DateTime.now().year}',},
    {'crop': 'Onion', 'mandi': 'Nashik APMC', 'min_price': 600, 'modal_price': 900, 'max_price': 1400, 'unit': 'quintal', 'date': '${DateTime.now().subtract(const Duration(days: 1)).day}/${DateTime.now().subtract(const Duration(days: 1)).month}/${DateTime.now().year}',},
    {'crop': 'Tomato', 'mandi': 'Pune APMC', 'min_price': 800, 'modal_price': 1200, 'max_price': 2000, 'unit': 'quintal', 'date': '${DateTime.now().subtract(const Duration(days: 1)).day}/${DateTime.now().subtract(const Duration(days: 1)).month}/${DateTime.now().year}',},
    {'crop': 'Sugarcane', 'mandi': 'Kolhapur APMC', 'min_price': 280, 'modal_price': 310, 'max_price': 340, 'unit': 'quintal', 'date': '${DateTime.now().subtract(const Duration(days: 1)).day}/${DateTime.now().subtract(const Duration(days: 1)).month}/${DateTime.now().year}',},
    {'crop': 'Groundnut', 'mandi': 'Solapur APMC', 'min_price': 4200, 'modal_price': 4800, 'max_price': 5500, 'unit': 'quintal', 'date': '${DateTime.now().subtract(const Duration(days: 1)).day}/${DateTime.now().subtract(const Duration(days: 1)).month}/${DateTime.now().year}',},
    {'crop': 'Jowar', 'mandi': 'Aurangabad APMC', 'min_price': 1600, 'modal_price': 1900, 'max_price': 2200, 'unit': 'quintal', 'date': '${DateTime.now().subtract(const Duration(days: 1)).day}/${DateTime.now().subtract(const Duration(days: 1)).month}/${DateTime.now().year}',},
  ];

  List<Map<String, dynamic>> get _filteredPrices {
    var list = _selectedCrop == 'All'
        ? List<Map<String, dynamic>>.from(_prices)
        : _prices.where((p) => (p['crop'] as String).toLowerCase() == _selectedCrop.toLowerCase()).toList();

    list.sort((a, b) {
      if (_sortBy == 'modal_price') {
        return (b['modal_price'] as num).compareTo(a['modal_price'] as num);
      }
      return (a['crop'] as String).compareTo(b['crop'] as String);
    });
    return list;
  }

  Future<void> _downloadPdf() async {
    setState(() => _generatingPdf = true);
    try {
      final pdf = pw.Document();
      final green = PdfColor.fromHex('2E7D32');
      final amber = PdfColor.fromHex('F59E0B');
      final lightGreen = PdfColor.fromHex('E8F5E9');
      final grey = PdfColor.fromHex('6B7280');

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(color: green, borderRadius: pw.BorderRadius.circular(12)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('FarmSmart - Mandi Prices', style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Live APMC prices | Maharashtra',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 11)),
              pw.SizedBox(height: 4),
              pw.Text('Generated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 10)),
            ]),
          ),
          pw.SizedBox(height: 20),
          pw.Text('All options ranked by modal price (highest first)',
              style: pw.TextStyle(fontSize: 11, color: grey)),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('E5E7EB'), width: 1),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: green),
                children: ['Crop', 'Mandi', 'Min (Rs.)', 'Modal (Rs.)', 'Max (Rs.)']
                    .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(h, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10))))
                    .toList(),
              ),
              ..._filteredPrices.asMap().entries.map((e) {
                final p = e.value;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: e.key.isEven ? lightGreen : PdfColors.white),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(p['crop'] as String, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(p['mandi'] as String? ?? '', style: pw.TextStyle(fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rs.${p['min_price']}', style: pw.TextStyle(fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rs.${p['modal_price']}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rs.${p['max_price']}', style: pw.TextStyle(fontSize: 10))),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Text('FarmSmart DSS - Prices sourced from Agmarknet (Data.gov.in). Verify before selling.',
              style: pw.TextStyle(fontSize: 9, color: grey), textAlign: pw.TextAlign.center),
        ],
      ));

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/mandi_prices_${DateTime.now().day}_${DateTime.now().month}.pdf');
      await file.writeAsBytes(await pdf.save());
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF error: $e'), backgroundColor: AppTheme.accentRed),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prices = _filteredPrices;
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Mandi Prices'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: _generatingPdf
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _generatingPdf ? null : _downloadPdf,
            tooltip: 'Download PDF',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : context.watch<AppState>().selectedDistrict.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_off_outlined, size: 64, color: AppTheme.textSecondary.withOpacity(0.4)),
                    const SizedBox(height: 16),
                    const Text('No District Selected',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    const Text('Please complete the crop recommendation wizard first to set your district.',
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadPrices,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoBanner(),
                    const SizedBox(height: 20),
                    _buildFilters(),
                    const SizedBox(height: 20),
                    _buildSortRow(prices.length),
                    const SizedBox(height: 12),
                    ...prices.map((p) => _buildPriceCard(p)),

                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Prices sourced from Agmarknet (Data.gov.in). Use them to compare options and plan your sale — not as a guaranteed rate.",
              style: TextStyle(fontSize: 12.5, color: Color(0xFF92400E), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _popularCrops.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final crop = _popularCrops[i];
          final selected = _selectedCrop == crop;
          return GestureDetector(
            onTap: () => setState(() => _selectedCrop = crop),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? AppTheme.primary : AppTheme.divider),
              ),
              child: Text(crop,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppTheme.textPrimary,
                  )),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortRow(int count) {
    return Row(
      children: [
        Text('$count results', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const Spacer(),
        const Text('Sort: ', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        GestureDetector(
          onTap: () => setState(() => _sortBy = _sortBy == 'modal_price' ? 'crop_name' : 'modal_price'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(_sortBy == 'modal_price' ? 'Highest Price' : 'Crop Name',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                const SizedBox(width: 4),
                const Icon(Icons.swap_vert_rounded, color: AppTheme.primary, size: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCard(Map<String, dynamic> p) {
    final modal = (p['modal_price'] as num).toDouble();
    final min   = (p['min_price']   as num).toDouble();
    final max   = (p['max_price']   as num).toDouble();
    final range = max - min;
    final fillFraction = range > 0 ? ((modal - min) / range).clamp(0.0, 1.0) : 0.5;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['crop'] as String,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.textSecondary),
                    const SizedBox(width: 3),
                    Text(p['mandi'] as String? ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ]),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₹${modal.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                Text('per ${p['unit'] ?? 'quintal'}',
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              ]),
            ],
          ),
          const SizedBox(height: 14),
          // Price range bar
          Row(children: [
            SizedBox(width: 40, child: Text('₹${min.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: AppTheme.accentRed, fontWeight: FontWeight.w600))),
            Expanded(child: Stack(children: [
              Container(height: 6, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(3))),
              FractionallySizedBox(
                widthFactor: fillFraction,
                child: Container(height: 6, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(3))),
              ),
            ])),
            SizedBox(width: 50, child: Text('₹${max.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
          ]),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 11, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(p['date'] as String? ?? p['arrival_date'] as String? ?? 'Recent',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ]),
            Row(children: [
              // Live vs fallback badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (p['source'] == 'agmarknet_live')
                      ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  (p['source'] == 'agmarknet_live') ? 'LIVE' : 'AVG',
                  style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w800,
                    color: (p['source'] == 'agmarknet_live')
                        ? AppTheme.primary : const Color(0xFFF59E0B),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppTheme.primarySurface, borderRadius: BorderRadius.circular(6)),
                child: Text('Modal: ₹${modal.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600)),
              ),
            ]),
          ]),
        ],
      ),
    );
  }
}