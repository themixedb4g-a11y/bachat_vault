import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PensionFundsScreen extends StatelessWidget {
  const PensionFundsScreen({super.key});

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
            'Pension Funds (VPS)',
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
              itemCount: _vpsSections.length,
              itemBuilder: (context, index) {
                return _buildExpandableCard(_vpsSections[index]);
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
final List<GuideSection> _vpsSections = [
  GuideSection(
    title: 'What is VPS (Voluntary Pension System)?',
    icon: Icons.savings_outlined,
    content: 'VPS is a specialized retirement savings scheme regulated by the SECP. It is designed to help you build a massive nest egg for your retirement while giving you immediate, legal tax breaks from the FBR today.',
    bulletPoints: [
      'Self-Managed: Unlike government or company pensions, YOU own this account and YOU choose how it is invested.',
      'Sub-Funds: Every VPS has 3 to 4 sub-funds (Equity, Debt, Money Market, and sometimes Commodities).',
      'Portability: If you change jobs, your VPS account stays with you.',
    ],
  ),
  GuideSection(
    title: 'The Golden Benefit: Tax Rebate',
    icon: Icons.receipt_long_outlined,
    content: 'This is the biggest reason to open a VPS. Under Section 63 of the Income Tax Ordinance 2001, you can claim a massive tax rebate (refund) on your investment.',
    bulletPoints: [
      'The Limit: You can invest up to 20% of your taxable income into a VPS to claim a tax credit.',
      'How it works: If you are a salaried individual, you just need to submit your investment certificate or statement to your payroll or finance department and they will automatically reduce your monthly income tax!',
      'Business Owners: You can claim this refund when filing your annual FBR tax returns.',
    ],
  ),
  GuideSection(
    title: 'Allocation Policies (Risk Profiles)',
    icon: Icons.tune_rounded,
    content: 'You do not have to pick individual stocks. You just choose an "Allocation Policy" based on your age and risk appetite:',
    bulletPoints: [
      'High Volatility: Up to 80% invested in Equity (Stocks). Best if you are young and retirement is decades away.',
      'Medium Volatility: A balanced mix of Equity (up to 50%) and Debt. Best for middle-aged investors.',
      'Low Volatility: Strictly Debt and Money Market (No Equity). Best if you are nearing retirement and want to protect your capital.',
      'Life Cycle Allocation: The AMC automatically shifts your money from High to Low risk as you get older. You do nothing!',
    ],
  ),
  GuideSection(
    title: 'Withdrawal Rules & Retirement',
    icon: Icons.card_giftcard_rounded,
    content: 'Because this is a retirement fund, the government strictly regulates how and when you can take the money out.',
    bulletPoints: [
      'Retirement Age: You can choose your retirement age anywhere between 60 and 70 years or or after 25 years of contribution.',
      'Tax-Free Lump Sum: At retirement, you can withdraw up to 50% of your total accumulated balance completely TAX-FREE.',
      'Income Payment Plan (IPP): The remaining 50% must be put into an IPP, which will pay you a monthly pension for the rest of your life.',
    ],
  ),
  GuideSection(
    title: 'Can I withdraw early?',
    icon: Icons.warning_amber_rounded,
    content: 'Yes, but there is a catch. Since the government gave you tax breaks to put the money in, they will penalize you for taking it out before your official retirement age.',
    bulletPoints: [
      'Early Withdrawal Penalty: If you withdraw before retirement, your withdrawal amount will be taxed at your average tax rate of the last 3 preceding years.',
      'Verdict: Only put money into a VPS that you are 100% sure you will not need until you turn 60 or after 25 years.',
    ],
  ),
];