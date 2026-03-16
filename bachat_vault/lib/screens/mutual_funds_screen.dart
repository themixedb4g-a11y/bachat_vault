import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MutualFundsScreen extends StatelessWidget {
  const MutualFundsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        dividerColor: Colors.transparent, // Prevents ugly lines on ExpansionTiles
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text(
            'Mutual Funds 101',
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
              itemCount: _guideSections.length,
              itemBuilder: (context, index) {
                return _buildExpandableCard(_guideSections[index]);
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
final List<GuideSection> _guideSections = [
  GuideSection(
    title: 'What is a Mutual Fund?',
    icon: Icons.group_work_outlined,
    content: 'Think of a mutual fund as a giant pool of money contributed by thousands of investors. Instead of buying individual stocks or bonds yourself, professional Fund Managers at an AMC (Asset Management Company) take this pooled money and invest it on your behalf.',
    bulletPoints: [
      'Regulated: Highly monitored by the SECP (Securities and Exchange Commission of Pakistan).',
      'Accessible: You can start investing with as little as PKR 500 or 1,000.',
      'Diversified: Your money is spread across many assets, reducing overall risk.',
    ],
  ),
  GuideSection(
    title: 'Conventional vs. Islamic',
    icon: Icons.balance_outlined,
    content: 'In Pakistan, every category of mutual fund usually has two versions:',
    bulletPoints: [
      'Conventional Funds: Invest in interest-bearing instruments (Stocks, T-Bills, standard banks, commercial paper).',
      'Islamic (Shariah-Compliant) Funds: Invest only in Riba-free instruments (Sukuks, Islamic banks, KMI-30 index stocks). These are audited by a Shariah Board.',
    ],
  ),
  GuideSection(
    title: 'Types of Funds (By Risk)',
    icon: Icons.stacked_bar_chart_rounded,
    content: 'Funds are categorized by where they put your money. Higher risk usually means higher potential returns over a long period.',
    bulletPoints: [
      'Money Market Funds (Very Low Risk): Invests in short-term government securities and bank deposits. Best for your Emergency Fund (1 day to 6 months).',
      'Income Funds (Low to Medium Risk): Invests in longer-term bonds and Sukuks. Best for short-term goals (1 to 3 years).',
      'Equity Funds (High Risk): Invests heavily in the stock market (PSX). Value fluctuates daily. Best for long-term wealth creation (5+ years).',
      'Asset Allocation / Balanced Funds (Medium-High Risk): A hybrid mix of both stocks and fixed income.',
    ],
  ),
  GuideSection(
    title: 'Key Terms You Must Know',
    icon: Icons.menu_book_rounded,
    content: 'Before investing, familiarize yourself with these common acronyms:',
    bulletPoints: [
      'NAV (Net Asset Value): The price of a single unit of the mutual fund. It changes daily.',
      'TER (Total Expense Ratio): The annual fee the AMC charges to manage your money (usually 0.5% to 3%). It is already deducted from your daily NAV.',
      'Front-End Load: A small fee (usually 0% to 3%) deducted when you deposit money. *Tip: Many AMCs waive this if you invest online!*',
      'FMR (Fund Manager Report): A monthly PDF published by the AMC showing exactly where the fund is invested and its past performance.',
    ],
  ),
];