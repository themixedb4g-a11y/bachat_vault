import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EtfsScreen extends StatelessWidget {
  const EtfsScreen({super.key});

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
            'Exchange Traded Funds',
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
              itemCount: _etfSections.length,
              itemBuilder: (context, index) {
                return _buildExpandableCard(_etfSections[index]);
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
                Text(
                  section.content,
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
  final String content;
  final List<String>? bulletPoints;
  final IconData icon;

  GuideSection({
    required this.title,
    required this.content,
    this.bulletPoints,
    required this.icon,
  });
}

// --- THE CONTENT ---
final List<GuideSection> _etfSections = [
  GuideSection(
    title: 'What is an ETF?',
    icon: Icons.shopping_basket_outlined,
    content: 'An Exchange Traded Fund (ETF) is a basket of different stocks or bonds, just like a mutual fund. However, instead of buying it directly from an AMC, it is listed on the Pakistan Stock Exchange (PSX) and trades exactly like a regular company share.',
    bulletPoints: [
      'Instant Diversification: Buying one share of an ETF instantly gives you fractional ownership in 10 to 30 top companies.',
      'Real-Time Pricing: Unlike mutual funds (which update prices once a day), ETF prices change every second while the PSX is open.',
    ],
  ),
  GuideSection(
    title: 'Mutual Funds vs. ETFs',
    icon: Icons.compare_arrows_rounded,
    content: 'While they do similar things, there are three major differences between Mutual Funds and ETFs:',
    bulletPoints: [
      'How to Buy: Mutual funds are bought via an AMC app. ETFs require a Stock Brokerage account (e.g., AKD, JS Global).',
      'Lower Fees: ETFs usually have much lower Expense Ratios (TER) than Mutual Funds because they simply track an index rather than paying expensive fund managers to "beat" the market.',
      'No Front-End Load: ETFs have zero sales loads. You only pay the tiny standard broker commission when buying or selling.',
    ],
  ),
  GuideSection(
    title: 'Types of ETFs in Pakistan',
    icon: Icons.pie_chart_outline_rounded,
    content: 'The SECP and PSX have launched several specialized ETFs to suit different investment styles:',
    bulletPoints: [
      'Index Trackers: These track the biggest, most liquid companies on the PSX, mirroring the performance of standard indices.',
      'Islamic ETFs: These strictly track Shariah-compliant indices. Perfect for Riba-free investors.',
      'Dividend ETFs: These focus on companies with a strong history of paying high cash dividends.',
    ],
  ),
  GuideSection(
    title: 'How to Invest in ETFs',
    icon: Icons.phonelink_ring_rounded,
    content: 'Ready to buy your first ETF? You cannot do this through a standard AMC portal. Here is how:',
    bulletPoints: [
      'Step 1: Open a brokerage account with a PSX-registered broker (Sahulat Accounts are great for beginners and can be opened online!).',
      'Step 2: Deposit funds into your brokerage account.',
      'Step 3: Search for the ETF ticker symbol (e.g., UBLP-ETF) during market hours and hit Buy.',
      'Overseas Pakistanis: You can buy ETFs directly through the Roshan Equity Investment (REI) portal linked to your Roshan Digital Account.',
    ],
  ),
];