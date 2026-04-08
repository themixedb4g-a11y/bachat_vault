import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AccountOpeningScreen extends StatelessWidget {
  const AccountOpeningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        dividerColor: Colors.transparent, 
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text(
            'Account Opening & Taxes',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withOpacity(0.2)),
            ),
          ),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF000000)],
            ),
          ),
          child: SafeArea(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 16, bottom: 40, left: 16, right: 16),
              itemCount: _accountSections.length,
              itemBuilder: (context, index) {
                return _buildExpandableCard(_accountSections[index]);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableCard(GuideSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: ExpansionTile(
              initiallyExpanded: section.isExpanded,
              iconColor: Colors.tealAccent,
              collapsedIconColor: Colors.white70,
              tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              title: Row(
                children: [
                  Icon(section.icon, color: Colors.tealAccent, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      section.title,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              children: [
                if (section.content != null)
                  Text(
                    section.content!,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.6),
                  ),
                if (section.bulletPoints != null) ...[
                  const SizedBox(height: 12),
                  ...section.bulletPoints!.map((bullet) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                bullet,
                                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ))
                ],
                if (section.customWidget != null) ...[
                  const SizedBox(height: 16),
                  section.customWidget!
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- DATA STRUCTURE ---
class GuideSection {
  final String title;
  final String? content;
  final List<String>? bulletPoints;
  final IconData icon;
  final Widget? customWidget;
  final bool isExpanded;

  GuideSection({
    required this.title,
    this.content,
    this.bulletPoints,
    required this.icon,
    this.customWidget,
    this.isExpanded = false,
  });
}

// --- THE CONTENT ---
final List<GuideSection> _accountSections = [
  GuideSection(
    title: '3 Ways to Open an Account Online',
    icon: Icons.app_registration_rounded,
    isExpanded: true,
    content: 'All these options are available online through websites or mobile apps, so you can start investing easily from anywhere!',
    bulletPoints: [
      'CDC\'s Asaan Connect: Complete your KYC and biometric verification just once. After that, you can open an account with any AMC, Broker, or Takaful provider without repeating documentation.',
      'Digital Platforms: Open a single account with any aggregator platform like Emlaak and invest in ANY fund of ANY AMC through one dashboard.',
      'Direct with AMC: Open an account directly with an individual Asset Management Company to invest specifically in their funds.',
    ],
  ),
  GuideSection(
    title: 'Sahulat vs. Sarmayakari Account',
    icon: Icons.compare_arrows_rounded,
    content: 'When opening an account, you will choose between a Basic (Sahulat) or a Full (Sarmayakari) account based on your documentation.',
    customWidget: Column(
      children: [
        _buildComparisonRow('Limits', 'Sahulat (Basic)', 'Sarmayakari (Full)', isHeader: true),
        _buildComparisonRow('Lifetime Limit', 'Rs. 10,00,000', 'No Limit'),
        _buildComparisonRow('Annual Gross Limit', 'Rs. 8,00,000', 'No Limit'),
        _buildComparisonRow('Single Transaction', 'Rs. 4,00,000', 'No Limit'),
        _buildComparisonRow('Source of Income Doc', 'Not Required', 'Required'),
        _buildComparisonRow('Opening Time', '5 - 10 Mins', '10 - 15 Mins'),
        const SizedBox(height: 12),
        const Text(
          '*Note: You can always open a Sahulat Account first and upgrade it to a Full Account later by providing income proof.*',
          style: TextStyle(color: Colors.tealAccent, fontSize: 11, fontStyle: FontStyle.italic),
        )
      ],
    ),
  ),
  GuideSection(
    title: 'Steps to Open a Full Account',
    icon: Icons.format_list_numbered_rounded,
    content: 'To open a Full Sarmayakari Account, you will complete these standard steps in the app/portal:',
    bulletPoints: [
      '1. CNIC Scan (Front & Back)',
      '2. Profile Information (Name, Address, Nominee)',
      '3. Bank Account Details (IBAN for withdrawals)',
      '4. KYC Information (Risk profiling questions)',
      '5. Upload Source of Income (Salary slip, job letter, etc.)',
      '6. Biometric Verification (Done via phone camera)',
      '7. Approval & Investment (Usually within 3 working days)',
    ],
  ),
  GuideSection(
    title: 'Taxation Rules (FY 2025-26)',
    icon: Icons.receipt_long_rounded,
    content: 'Your profits are subject to Capital Gains Tax (CGT) when you sell units, or Tax on Dividends when a fund distributes cash. Being an Active Taxpayer (Filer) significantly reduces these deductions.',
    bulletPoints: [
      'Filers (CGT): Capital Gains Tax is a flat 15% across all mutual funds when you sell your units for a profit.',
      'Filers (Dividends): Dividend tax is 15% on income generated from Equities, and 25% on income from Fixed Income. (e.g., If your fund earns 80% of its money from stocks and 20% from bonds, your dividend is split! You only pay 15% tax on the stock portion and 25% on the bond portion).',
      'Non-Filers: Capital Gains Tax is 30% for investments made before July 1, 2025, but drops to 15% for investments made on or after July 1, 2025. However, Tax on Dividends is heavily penalized at double the standard rate (up to 50%).',
      'Automatic Deduction: You do not need to calculate or pay these taxes manually. The AMC automatically deducts the exact amount before depositing the profits into your bank account.',
      'Zakat Deduction: Unless you submit a CZ-50 form (Zakat Exemption Affidavit) during account opening, 2.5% Zakat will be deducted annually on the 1st of Ramadan.',
    ],
  ),
];

// Helper widget for the comparison table
Widget _buildComparisonRow(String title, String basic, String full, {bool isHeader = false}) {
  final color = isHeader ? Colors.tealAccent : Colors.white70;
  final weight = isHeader ? FontWeight.bold : FontWeight.normal;
  final fontSize = isHeader ? 12.0 : 11.0;

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6.0),
    child: Row(
      children: [
        Expanded(flex: 2, child: Text(title, style: TextStyle(color: color, fontWeight: weight, fontSize: fontSize))),
        Expanded(flex: 2, child: Text(basic, style: TextStyle(color: color, fontWeight: weight, fontSize: fontSize))),
        Expanded(flex: 2, child: Text(full, style: TextStyle(color: color, fontWeight: weight, fontSize: fontSize), textAlign: TextAlign.right)),
      ],
    ),
  );
}