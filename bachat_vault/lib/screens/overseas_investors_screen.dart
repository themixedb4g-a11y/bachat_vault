import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OverseasInvestorsScreen extends StatelessWidget {
  const OverseasInvestorsScreen({super.key});

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
            'Overseas Investors (RDA)',
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
              itemCount: _rdaSections.length,
              itemBuilder: (context, index) {
                return _buildExpandableCard(_rdaSections[index]);
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
final List<GuideSection> _rdaSections = [
  GuideSection(
    title: 'The Gateway: Roshan Digital Account',
    icon: Icons.public_rounded,
    content: 'If you are an overseas Pakistani and want to invest safely and profitably in Pakistan, the Roshan Digital Account (RDA) is your gateway. Everything is fully digital, from account opening to investing and profit repatriation.',
    bulletPoints: [
      'Open Remotely: Can be opened online with any major Pakistani bank.',
      'Currency Options: Choose between PKR or foreign currency accounts (USD, GBP, EUR, etc.).',
      'Manage Anywhere: Monitor your entire portfolio from abroad easily.',
    ],
  ),
  GuideSection(
    title: 'Naya Pakistan Certificates (NPCs)',
    icon: Icons.verified_user_outlined,
    content: 'NPCs are government-backed certificates available in both Conventional and Shariah-compliant variants. Tenure options range from 3 months to 5 years.',
    bulletPoints: [
      'High Returns: Often offers higher returns than low-risk mutual funds with virtually no risk.',
      'Tax Advantage: Flat 10% tax rate, which is lower than the standard 15% for mutual funds.',
      'Repatriable: Profits and your initial principal can be repatriated abroad anytime.',
    ],
  ),
  GuideSection(
    title: 'Roshan Equity Investment (PSX)',
    icon: Icons.candlestick_chart_outlined,
    content: 'You can invest directly in Pakistani companies and ETFs on the Pakistan Stock Exchange.',
    bulletPoints: [
      'CDC Integration: Open a brokerage account through the CDC’s Roshan Equity Investment platform.',
      'Direct Trading: Once linked to your RDA, you can seamlessly buy and sell shares online from overseas.',
    ],
  ),
  GuideSection(
    title: 'Mutual Funds',
    icon: Icons.pie_chart_outline_rounded,
    content: 'Most banks offering RDA also partner with Asset Management Companies (AMCs) so you can invest in mutual funds online.',
    bulletPoints: [
      'Diversify: Access Equity, Income, and Money Market funds without opening separate accounts.',
      'Bank Dependency: Not all banks currently provide this feature smoothly — check with your specific bank first.',
    ],
  ),
  GuideSection(
    title: 'Roshan Pension Plan (VPS)',
    icon: Icons.elderly_outlined,
    content: 'Secure your retirement by investing in Roshan Pension Plans under the Voluntary Pension Scheme (VPS).',
    bulletPoints: [
      'Top Managers: These are managed by top AMCs and allow flexible contributions.',
      'Custom Allocation: Choose between equity, debt, or money market allocations depending on your age and financial goals.',
    ],
  ),
];