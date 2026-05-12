import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/app_state.dart';
import 'wizard_screen.dart';
import 'pest_alerts_screen.dart';
import 'scanner_screen.dart';
import 'mandi_prices_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildFarmImage(),
                  const SizedBox(height: 28),
                  _buildHeroSection(context),
                  const SizedBox(height: 32),
                  _buildMainActions(context),
                  const SizedBox(height: 28),
                  _buildStatsRow(),
                  const SizedBox(height: 28),
                  _buildMandiCard(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      snap: true,
      backgroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.eco_rounded, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('FarmSmart',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary, letterSpacing: -0.5)),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('Crop Decision Support System',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary, letterSpacing: 0.1)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      /* actions: [
        GestureDetector(
          onTap: () => context.read<AppState>().toggleLanguage(),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.inputBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(state.language == 'English' ? 'हिंदी' : 'EN',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: AppTheme.textPrimary),
          onPressed: () {},
        ),
        const SizedBox(width: 4),
      ], */

    );
  }

  /*Widget _buildAlertBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.accentAmber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: AppTheme.accentAmber, size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active Alert: Nagpur District', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
                Text('Whitefly risk detected for cotton crops', style: TextStyle(fontSize: 12, color: Color(0xFFB45309))),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.accentAmber),
        ],
      ),
    );
  }*/
  Widget _buildFarmImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        'https://images.unsplash.com/photo-1464226184884-fa280b87c399?w=800&q=80',
        width: double.infinity,
        height: 180,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 180,
          decoration: BoxDecoration(
            color: AppTheme.primarySurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(child: Icon(Icons.landscape_rounded, color: AppTheme.primary, size: 48)),
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.primarySurface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 14),
              SizedBox(width: 5),
              Text('Smart Farming Tool', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Find the right crop\nfor your land',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -1, height: 1.15),
        ),
        const SizedBox(height: 10),
        const Text(
          'Get data-driven crop recommendations with risk assessment, weather analysis, and pest alerts — no lab report needed.',
          style: TextStyle(fontSize: 14.5, color: AppTheme.textSecondary, height: 1.55),
        ),
      ],
    );
  }

  Widget _buildMainActions(BuildContext context) {
    return Column(
      children: [
        _PrimaryActionButton(
          icon: Icons.agriculture_rounded,
          label: 'Get Crop Recommendation',
          subtitle: 'Data-driven analysis in 3 steps',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WizardScreen())),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SecondaryActionButton(
                icon: Icons.bug_report_outlined,
                label: 'Pest Alerts',
                color: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFFF8E1),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PestAlertsScreen())),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SecondaryActionButton(
                icon: Icons.document_scanner_outlined,
                label: 'Scan Disease',
                color: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFF5F3FF),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen())),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(children: [
      _StatChip(value: '55+', label: 'Crops'),
      const SizedBox(width: 10),
      _StatChip(value: '35', label: 'Districts'),
      const SizedBox(width: 10),
      _StatChip(value: '26yr', label: 'Data'),
      const SizedBox(width: 10),
      _StatChip(value: 'Live', label: 'Weather'),
    ]);
  }

  Widget _buildMandiCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MandiPricesScreen())),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.storefront_outlined, color: Color(0xFFF59E0B), size: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mandi Prices', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
                  SizedBox(height: 4),
                  Text('Latest APMC prices to help you decide where and when to sell your harvest.', style: TextStyle(fontSize: 12, color: Color(0xFFB45309), height: 1.4)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFF59E0B)),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const _PrimaryActionButton({required this.icon, required this.label, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF388E3C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  const _SecondaryActionButton({required this.icon, required this.label, required this.color, required this.bgColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 10),
            Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value, label;
  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.divider)),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primary)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title, desc;
  final Color color;
  const _FeatureCard({required this.icon, required this.title, required this.desc, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}