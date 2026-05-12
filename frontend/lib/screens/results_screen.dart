import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import 'pest_alerts_screen.dart';
import 'scanner_screen.dart';
import 'home_screen.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});
  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _generatingPdf = false;

  Color _riskColor(String level) {
    switch (level.toUpperCase()) {
      case 'LOW':    return AppTheme.primary;
      case 'MEDIUM': return AppTheme.accentAmber;
      case 'HIGH':   return AppTheme.accentRed;
      default:       return AppTheme.textSecondary;
    }
  }

  String _riskLabel(String level) {
    switch (level.toUpperCase()) {
      case 'LOW':    return 'Safe';
      case 'MEDIUM': return 'Moderate';
      case 'HIGH':   return 'Risky';
      default:       return 'Moderate';
    }
  }

  Color _riskBarColor(double v) {
    if (v < 35) return AppTheme.primary;
    if (v < 60) return AppTheme.accentAmber;
    return AppTheme.accentRed;
  }

  IconData _trendIcon(String t) => t == 'UP'
      ? Icons.trending_up_rounded
      : t == 'DOWN'
      ? Icons.trending_down_rounded
      : Icons.trending_flat_rounded;

  Color _trendColor(String t) => t == 'UP'
      ? AppTheme.primary
      : t == 'DOWN'
      ? AppTheme.accentRed
      : AppTheme.accentAmber;

  @override
  Widget build(BuildContext context) {
    final state  = context.watch<AppState>();
    final crops  = state.cropResults;
    if (crops.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final sel = crops[state.selectedCropIndex];

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Crop Recommendation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heroCard(sel),
            const SizedBox(height: 16),
            if (state.hasBudget) _affordBanner(sel),
            if (state.hasBudget) const SizedBox(height: 16),
            _quickStats(sel, state),
            const SizedBox(height: 16),
            _riskRadar(sel),
            const SizedBox(height: 16),
            _whySection(sel),
            const SizedBox(height: 16),
            _cropList(context, state, crops),
            const SizedBox(height: 16),
            _actionButtons(context, state),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── 1. Hero card ──────────────────────────────────────────────────
  Widget _heroCard(Map<String, dynamic> c) {
    final riskColor = _riskColor(c['risk_level'] as String? ?? 'MEDIUM');
    final rank      = c['rank'] as int? ?? 1;
    final suit      = (c['suitability'] as String?) ?? '';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _pill('#$rank ${rank == 1 ? 'Recommendation' : 'Best for You'}',
              Colors.white.withOpacity(0.15), Colors.white),
          const Spacer(),
          _pill('${_riskLabel(c['risk_level'] as String? ?? 'MEDIUM')} RISK',
              riskColor.withOpacity(0.25), riskColor, border: true),
        ]),
        const SizedBox(height: 18),
        Text(c['emoji'] ?? '🌾', style: const TextStyle(fontSize: 48)),
        const SizedBox(height: 6),
        Text(c['crop_name'] ?? '',
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1)),
        const SizedBox(height: 4),
        if (suit.isNotEmpty && suit != 'No regional data')
          Text(suit, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7))),
      ]),
    );
  }

  Widget _pill(String text, Color bg, Color fg, {bool border = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      border: border ? Border.all(color: fg, width: 1.5) : null,
    ),
    child: Text(text, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w700)),
  );

  // ── 2. Affordability banner ───────────────────────────────────────
  Widget _affordBanner(Map<String, dynamic> c) {
    final af   = c['affordability'] as Map<String, dynamic>?;
    if (af == null) return const SizedBox.shrink();
    final can  = af['can_afford'] as bool? ?? true;
    final label= af['affordability_label'] as String? ?? '';
    final cost = (af['input_cost'] as num?)?.toDouble() ?? 0;
    final fg   = can ? AppTheme.primary : AppTheme.accentRed;
    final bg   = can ? AppTheme.primarySurface : const Color(0xFFFEE2E2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(can ? Icons.check_circle_rounded : Icons.cancel_rounded, color: fg, size: 26),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(can ? 'YES — You can afford this' : 'Budget Warning',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(height: 2),
          Text('Cost: Rs.${_fmt(cost)}  |  $label',
              style: TextStyle(fontSize: 12, color: fg.withOpacity(0.8))),
        ])),
      ]),
    );
  }

  // ── 3. Top-N selector ─────────────────────────────────────────────
  Widget _buildTopNSelector(AppState state, int totalCrops) {
    final maxN     = totalCrops.clamp(3, 10);
    final currentN = state.visibleCropCount.clamp(3, maxN);
    return Row(
      children: [
        const Text('Show top:',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(maxN - 2, (i) {
                final n        = i + 3;
                final selected = currentN == n;
                return GestureDetector(
                  onTap: () => state.setVisibleCropCount(n),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 6),
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.primary : AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: selected ? AppTheme.primary : AppTheme.divider),
                    ),
                    child: Center(
                      child: Text('$n',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : AppTheme.textSecondary)),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  // ── 4. Quick stats ────────────────────────────────────────────────
  Widget _quickStats(Map<String, dynamic> c, AppState state) {
    final mkt     = c['market_signal'] as Map<String, dynamic>?;
    final demand  = mkt?['demand_level'] as String? ?? 'MEDIUM';
    final harvest = c['harvest_days']    as int?    ?? 120;
    final risk    = c['risk_level']      as String? ?? 'MEDIUM';
    final suit    = c['suitability']     as String? ?? '';
    final inSeason = suit != 'No regional data' && suit.isNotEmpty;

    final demandColor = demand == 'HIGH' ? AppTheme.primary
        : demand == 'LOW'  ? AppTheme.accentRed
        : AppTheme.accentAmber;
    final riskColor = _riskColor(risk);

    return Row(children: [
      Expanded(child: _LightStatChip(Icons.storefront_outlined, 'DEMAND',
          demand == 'HIGH' ? 'High' : demand == 'LOW' ? 'Low' : 'Medium', demandColor)),
      const SizedBox(width: 8),
      Expanded(child: _LightStatChip(Icons.bolt_outlined, 'RISK',
          risk == 'LOW' ? 'Safe' : risk == 'HIGH' ? 'High Risk' : 'Moderate', riskColor)),
      const SizedBox(width: 8),
      Expanded(child: _LightStatChip(
          inSeason ? Icons.check_box_rounded : Icons.calendar_today_outlined,
          'SEASON', inSeason ? 'Good' : state.season,
          inSeason ? AppTheme.primary : AppTheme.accentAmber)),
      const SizedBox(width: 8),
      Expanded(child: _LightStatChip(
          Icons.timer_outlined, 'HARVEST', '~$harvest d', AppTheme.textSecondary)),
    ]);
  }

  // ── 5. Money forecast ─────────────────────────────────────────────
  Widget _moneyForecast(Map<String, dynamic> c, AppState state) {
    final af      = c['affordability'] as Map<String, dynamic>?;
    final spend   = (af?['input_cost'] as num?)?.toDouble();
    final earnStr = c['revenue_estimate'] as String? ?? 'N/A';

    double? earnMid, profit, roi;
    if (earnStr != 'N/A' && earnStr.contains('–') && spend != null) {
      final parts = earnStr.replaceAll('₹', '').replaceAll('Rs.', '').replaceAll(',', '').split('–');
      final lo = double.tryParse(parts[0].trim());
      final hi = double.tryParse(parts[1].replaceAll(RegExp(r'[^0-9.]'), '').trim());
      if (lo != null && hi != null) {
        earnMid = (lo + hi) / 2;
        profit  = earnMid - spend;
        roi     = (profit / spend) * 100;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance_wallet_outlined,
              color: AppTheme.textSecondary, size: 16),
          const SizedBox(width: 8),
          Text('MONEY FORECAST (${state.landAcres.toStringAsFixed(1)} ACRES)',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _LightMoneyBox('YOU SPEND',
              spend != null ? 'Rs.${_fmt(spend)}' : c['input_cost_estimate'] ?? 'N/A',
              AppTheme.accentRed, false, null)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward_rounded, color: AppTheme.textSecondary, size: 16),
          ),
          Expanded(child: _LightMoneyBox('YOU EARN',
              earnMid != null ? 'Rs.${_fmt(earnMid)}' : earnStr,
              const Color(0xFFF59E0B), false, null)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('=', style: TextStyle(fontSize: 18,
                color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
          ),
          Expanded(child: _LightMoneyBox(
            'NET PROFIT',
            profit != null
                ? '${profit >= 0 ? '+' : ''}Rs.${_fmt(profit.abs())}'
                : 'N/A',
            (profit == null || profit >= 0) ? AppTheme.primary : AppTheme.accentRed,
            true,
            roi != null ? 'ROI: ${roi.toStringAsFixed(0)}%' : null,
          )),
        ]),
      ]),
    );
  }

  // ── 6. Risk radar ─────────────────────────────────────────────────
  Widget _riskRadar(Map<String, dynamic> c) {
    final bd      = c['risk_breakdown'] as Map<String, dynamic>? ?? {};
    final weather = (bd['weather']    as num?)?.toDouble() ?? 0;
    final market  = (bd['market']     as num?)?.toDouble() ?? 0;
    final cost    = (bd['input_cost'] as num?)?.toDouble() ?? 0;
    final pest    = (bd['pest']       as num?)?.toDouble() ?? 0;
    final fill    = _riskColor(c['risk_level'] as String? ?? 'MEDIUM');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Risk Breakdown',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: fill.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: fill.withOpacity(0.3)),
            ),
            child: Text(
                '${(c['risk_score'] as num?)?.toStringAsFixed(0) ?? '--'}/100',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fill)),
          ),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 200,
          child: RadarChart(RadarChartData(
            dataSets: [RadarDataSet(
              fillColor: fill.withOpacity(0.15),
              borderColor: fill, borderWidth: 2, entryRadius: 4,
              dataEntries: [
                RadarEntry(value: weather), RadarEntry(value: market),
                RadarEntry(value: cost),    RadarEntry(value: pest),
              ],
            )],
            radarShape: RadarShape.polygon, tickCount: 4,
            ticksTextStyle: const TextStyle(fontSize: 8, color: AppTheme.textSecondary),
            gridBorderData: const BorderSide(color: AppTheme.divider),
            tickBorderData: const BorderSide(color: AppTheme.divider),
            radarBorderData: const BorderSide(color: AppTheme.divider),
            getTitle: (i, angle) => RadarChartTitle(
                text: ['Weather', 'Market', 'Cost', 'Pest'][i], angle: angle),
            titleTextStyle: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          )),
        ),
        const SizedBox(height: 16),
        ...[('Weather', weather), ('Market', market), ('Input Cost', cost), ('Pest', pest)]
            .map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(width: 72, child: Text(e.$1,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: e.$2 / 100, minHeight: 6,
                    backgroundColor: AppTheme.divider,
                    valueColor: AlwaysStoppedAnimation(_riskBarColor(e.$2)),
                  ),
                )),
                SizedBox(width: 32, child: Text('${e.$2.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary),
                    textAlign: TextAlign.right)),
              ]),
            )),
        const SizedBox(height: 8),
        Builder(builder: (_) {
          final all   = {'Weather': weather, 'Market': market, 'Input Cost': cost, 'Pest': pest};
          final worst = all.entries.reduce((a, b) => a.value > b.value ? a : b);
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: AppTheme.accentAmber, size: 15),
              const SizedBox(width: 8),
              Expanded(child: Text('Main concern: ${worst.key} risk is elevated',
                  style: const TextStyle(fontSize: 12,
                      color: Color(0xFF92400E), fontWeight: FontWeight.w500))),
            ]),
          );
        }),
      ]),
    );
  }

  // ── 7. Why section ────────────────────────────────────────────────
  Widget _whySection(Map<String, dynamic> c) {
    final raw    = c['explanation'] ?? c['explanation_points'];
    final points = raw is List ? List<String>.from(raw) : <String>[];
    if (points.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.lightbulb_outline_rounded, color: AppTheme.primary, size: 20),
          SizedBox(width: 8),
          Text('Why We Recommend This',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
        ]),
        const SizedBox(height: 16),
        ...points.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              margin: const EdgeInsets.only(top: 3), width: 18, height: 18,
              decoration: const BoxDecoration(
                  color: AppTheme.primarySurface, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: AppTheme.primary, size: 12),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(p,
                style: const TextStyle(fontSize: 13.5,
                    color: AppTheme.textPrimary, height: 1.45))),
          ]),
        )),
      ]),
    );
  }

  // ── 8. Ranked crop list ───────────────────────────────────────────
  Widget _cropList(BuildContext context, AppState state, List<Map<String, dynamic>> crops) {
    final visibleCount = state.visibleCropCount.clamp(3, crops.length);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('All Options — Ranked for You',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary))),
          Text('${crops.length} crops',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ]),
        const SizedBox(height: 4),
        const SizedBox(height: 12),
        _buildTopNSelector(state, crops.length),
        const SizedBox(height: 16),
        ...List.generate(visibleCount, (i) {
          final c      = crops[i];
          final sel    = state.selectedCropIndex == i;
          final af     = c['affordability'] as Map<String, dynamic>?;
          final canAff = af?['can_afford']  as bool?   ?? true;
          final risk   = c['risk_level']    as String? ?? 'MEDIUM';
          final rank   = c['rank']          as int?    ?? (i + 1);
          final trend  = (c['market_signal'] as Map<String, dynamic>?)?['price_trend']
              as String? ?? 'STABLE';
          final harvest = c['harvest_days'] as int? ?? 120;

          return GestureDetector(
            onTap: () => state.selectCrop(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sel ? AppTheme.primarySurface : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: sel ? AppTheme.primary : AppTheme.divider,
                    width: sel ? 2 : 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: rank <= 3
                          ? AppTheme.primary.withOpacity(0.12)
                          : AppTheme.divider,
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text('#$rank',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                            color: rank <= 3 ? AppTheme.primary : AppTheme.textSecondary))),
                  ),
                  const SizedBox(width: 8),
                  Text(c['emoji'] ?? '🌾', style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(c['crop_name'] ?? '',
                            style: const TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4, runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _MiniChip(_riskColor(risk), risk == 'LOW' ? 'Safe' : risk == 'HIGH' ? 'Risky' : 'Moderate'),
                            _MiniChip(
                                canAff ? AppTheme.primary : AppTheme.accentRed,
                                canAff ? 'Affordable' : 'Over budget'),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('~${harvest}d',
                                  style: const TextStyle(
                                      fontSize: 10, fontWeight: FontWeight.w600,
                                      color: AppTheme.textSecondary)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ]),
    );
  }

  // ── 9. Action buttons ─────────────────────────────────────────────
  Widget _actionButtons(BuildContext context, AppState state) {
    final cropName =
        (state.cropResults[state.selectedCropIndex]['crop_name'] as String?) ?? '';
    return Column(children: [
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: _generatingPdf
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.picture_as_pdf_outlined, size: 20),
          label: Text(_generatingPdf ? 'Generating...' : 'Download Crop Plan PDF'),
          style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: _generatingPdf ? null : () => _generatePdf(context, state),
        ),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          icon: const Icon(Icons.bug_report_outlined, size: 18),
          label: const Text('Pest Alerts'),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => PestAlertsScreen(cropHint: cropName))),
        )),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton.icon(
          icon: const Icon(Icons.document_scanner_outlined, size: 18),
          label: const Text('Scan Disease'),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ScannerScreen())),
        )),
      ]),
      const SizedBox(height: 10),
      TextButton(
        onPressed: () {
          state.reset();
          Navigator.pushAndRemoveUntil(context,
              MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
        },
        child: const Text('Start Over',
            style: TextStyle(color: AppTheme.textSecondary)),
      ),
    ]);
  }

  // ── PDF generation ────────────────────────────────────────────────
  Future<void> _generatePdf(BuildContext context, AppState state) async {
    setState(() => _generatingPdf = true);
    try {
      final pdf   = pw.Document();
      final crops = state.cropResults;
      final sel   = crops[state.selectedCropIndex];
      final cropName = sel['crop_name']  as String? ?? 'Crop';
      final af       = sel['affordability'] as Map<String, dynamic>?;
      final mandi    = sel['mandi_prices']  as Map<String, dynamic>?;
      final risk     = sel['risk_level']    as String? ?? 'MEDIUM';
      final conf     = (sel['confidence']   as num?)?.toDouble() ?? 0;
      final harvest  = sel['harvest_days']  as int? ?? 120;
      final revenue  = sel['revenue_estimate'] as String? ?? 'N/A';
      final points   = (sel['explanation'] is List)
          ? List<String>.from(sel['explanation'])
          : <String>[];

      final green      = PdfColor.fromHex('2E7D32');
      final lightGreen = PdfColor.fromHex('E8F5E9');
      final grey       = PdfColor.fromHex('6B7280');
      final darkText   = PdfColor.fromHex('1A2E1A');

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: green, borderRadius: pw.BorderRadius.circular(12)),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('FarmSmart Crop Plan',
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 22,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(
                'District: ${state.selectedDistrict}  '
                'Season: ${state.season}  '
                'Area: ${state.landAcres.toStringAsFixed(1)} acres',
                style: pw.TextStyle(color: PdfColors.white, fontSize: 11),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                style: pw.TextStyle(color: PdfColors.white, fontSize: 10)),
            ]),
          ),
          pw.SizedBox(height: 20),

          // Top Recommendation
          pw.Text('#1 Recommended Crop',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: green)),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: lightGreen,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: green, width: 1),
            ),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                pw.Text(cropName,
                    style: pw.TextStyle(fontSize: 20,
                        fontWeight: pw.FontWeight.bold, color: darkText)),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                      color: green, borderRadius: pw.BorderRadius.circular(20)),
                  child: pw.Text('$risk RISK',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 10,
                          fontWeight: pw.FontWeight.bold)),
                ),
              ]),
              pw.SizedBox(height: 8),
              pw.Row(children: [
                pw.Text('Confidence: ', style: pw.TextStyle(color: grey, fontSize: 11)),
                pw.Text('${conf.toStringAsFixed(0)}%',
                    style: pw.TextStyle(color: green, fontSize: 11,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(width: 20),
                pw.Text('Harvest in: ', style: pw.TextStyle(color: grey, fontSize: 11)),
                pw.Text('~$harvest days',
                    style: pw.TextStyle(color: darkText, fontSize: 11,
                        fontWeight: pw.FontWeight.bold)),
              ]),
            ]),
          ),
          pw.SizedBox(height: 20),

          // Financial Summary
          pw.Text('Financial Summary',
              style: pw.TextStyle(fontSize: 14,
                  fontWeight: pw.FontWeight.bold, color: darkText)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('E5E7EB'), width: 1),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
            },
            children: [
              _pdfRow('Input Cost', af != null
                  ? 'Rs.${_fmt((af['input_cost'] as num?)?.toDouble() ?? 0)}'
                  : sel['input_cost_estimate'] ?? 'N/A', lightGreen),
              _pdfRow('Revenue Estimate', revenue.replaceAll('₹', 'Rs.').replaceAll('–', '-').replaceAll('—', '-'), PdfColors.white),
              _pdfRow('Affordability',
                  af?['affordability_label'] as String? ?? 'N/A', lightGreen),
              if (mandi != null) ...[
                _pdfRow('Nearest Mandi',
                    mandi['mandi_name'] as String? ?? '', PdfColors.white),
                _pdfRow('Market Price (Usual)',
                    'Rs.${(mandi['modal_price'] as num?)?.toStringAsFixed(0) ?? 'N/A'}/quintal',
                    lightGreen),
              ],
            ],
          ),
          pw.SizedBox(height: 20),

          // Soil Info
          pw.Text('Soil and Inputs Used',
              style: pw.TextStyle(fontSize: 14,
                  fontWeight: pw.FontWeight.bold, color: darkText)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('E5E7EB'), width: 1),
            columnWidths: {
              0: const pw.FlexColumnWidth(1), 1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1), 3: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: green),
                children: ['Nitrogen (N)', 'Phosphorus (P)', 'Potassium (K)', 'pH']
                    .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(h,
                        style: pw.TextStyle(color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold, fontSize: 10))))
                    .toList(),
              ),
              pw.TableRow(children: [
                state.nitrogen, state.phosphorus, state.potassium, state.ph,
              ].map((v) => pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                      '${v is double ? v.toStringAsFixed(1) : v}',
                      style: pw.TextStyle(fontSize: 11)))).toList()),
            ],
          ),
          pw.SizedBox(height: 20),

          // Why this crop
          if (points.isNotEmpty) ...[
            pw.Text('Why This Crop Was Recommended',
                style: pw.TextStyle(fontSize: 14,
                    fontWeight: pw.FontWeight.bold, color: darkText)),
            pw.SizedBox(height: 8),
            ...points.map((p) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Container(
                  width: 6, height: 6,
                  margin: const pw.EdgeInsets.only(top: 4, right: 8),
                  decoration: pw.BoxDecoration(
                      color: green, shape: pw.BoxShape.circle),
                ),
                pw.Expanded(child: pw.Text(p,
                    style: pw.TextStyle(fontSize: 11, color: darkText))),
              ]),
            )),
            pw.SizedBox(height: 20),
          ],

          // All ranked crops
          pw.Text('All Crop Options Ranked',
              style: pw.TextStyle(fontSize: 14,
                  fontWeight: pw.FontWeight.bold, color: darkText)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('E5E7EB'), width: 1),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FixedColumnWidth(50),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: green),
                children: ['#', 'Crop', 'Risk', 'Budget', 'Score']
                    .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(h,
                        style: pw.TextStyle(color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold, fontSize: 10))))
                    .toList(),
              ),
              ...crops.asMap().entries.map((e) {
                final idx  = e.key;
                final cr   = e.value;
                final crAf = cr['affordability'] as Map<String, dynamic>?;
                final canA = crAf?['can_afford'] as bool? ?? true;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: idx == state.selectedCropIndex
                          ? lightGreen
                          : PdfColors.white),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${cr['rank'] ?? idx + 1}',
                            style: pw.TextStyle(fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${cr['crop_name'] ?? ''}',
                            style: pw.TextStyle(fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(cr['risk_level'] as String? ?? '',
                            style: pw.TextStyle(fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(canA ? 'Affordable' : 'Over budget',
                            style: pw.TextStyle(fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                            '${(cr['composite_score'] ?? cr['confidence'] ?? 0).toStringAsFixed(0)}',
                            style: pw.TextStyle(
                                fontSize: 10, fontWeight: pw.FontWeight.bold))),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 24),

          // Footer
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generated by FarmSmart DSS | For guidance only | Consult your local KVK for field verification',
            style: pw.TextStyle(fontSize: 9, color: grey),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ));

      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/farmsmart_crop_plan_$cropName.pdf');
      await file.writeAsBytes(await pdf.save());
      await OpenFilex.open(file.path);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF error: $e'),
              backgroundColor: AppTheme.accentRed),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  pw.TableRow _pdfRow(String label, String value, PdfColor bg) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: bg),
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(8),
            child: pw.Text(label,
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
        pw.Padding(padding: const pw.EdgeInsets.all(8),
            child: pw.Text(value, style: pw.TextStyle(fontSize: 11))),
      ],
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────────────────────────────────
//  Helper widgets
// ─────────────────────────────────────────────────────────────────────

class _LightStatChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _LightStatChip(this.icon, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(height: 4),
      Text(label,
          style: TextStyle(fontSize: 8, color: color.withOpacity(0.7),
              fontWeight: FontWeight.w600, letterSpacing: 0.2),
          textAlign: TextAlign.center),
      const SizedBox(height: 2),
      Text(value,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
    ]),
  );
}

class _LightMoneyBox extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool highlight;
  final String? sub;
  const _LightMoneyBox(this.label, this.value, this.color, this.highlight, this.sub);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: highlight
          ? Border.all(color: color, width: 1.5)
          : Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(fontSize: 9, color: color.withOpacity(0.7),
              letterSpacing: 0.3, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
          overflow: TextOverflow.ellipsis),
      if (sub != null) ...[
        const SizedBox(height: 2),
        Text(sub!, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
      ],
    ]),
  );
}

class _LightPriceBox extends StatelessWidget {
  final String label;
  final double? price;
  final Color color;
  final String? sub;
  final bool highlight;
  const _LightPriceBox(this.label, this.price, this.color, this.sub,
      {this.highlight = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: highlight
          ? Border.all(color: color, width: 1.5)
          : Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(fontSize: 9, color: color.withOpacity(0.7),
              letterSpacing: 0.3, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(price != null ? 'Rs.${price!.toStringAsFixed(0)}' : '-',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
          overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text(sub ?? '/quintal',
          style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
    ]),
  );
}

class _MiniChip extends StatelessWidget {
  final Color color;
  final String label;
  const _MiniChip(this.color, this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
  );
}

class _WeatherChip extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _WeatherChip(this.icon, this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 22),
    ),
    const SizedBox(height: 6),
    Text(value,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary)),
    Text(label,
        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
  ]);
}