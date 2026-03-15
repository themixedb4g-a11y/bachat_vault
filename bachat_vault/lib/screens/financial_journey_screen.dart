import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FinancialJourneyScreen extends StatelessWidget {
  const FinancialJourneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text(
            'Your Financial Journey',
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
              itemCount: _journeySteps.length,
              itemBuilder: (context, index) {
                final step = _journeySteps[index];
                final isLast = index == _journeySteps.length - 1;
                return _buildTimelineStep(step, index + 1, isLast);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineStep(JourneyStep step, int stepNumber, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left side: Timeline Icon and Line
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF203A43),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.tealAccent, width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.tealAccent.withOpacity(0.2), blurRadius: 8, spreadRadius: 2),
                  ],
                ),
                child: Icon(step.icon, color: Colors.tealAccent, size: 20),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.tealAccent.withOpacity(0.3),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Right side: Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$stepNumber. ${step.title}',
                          style: const TextStyle(color: Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          step.description,
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                        ),
                        if (step.bulletPoints.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...step.bulletPoints.map((bullet) => Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ', style: TextStyle(color: Colors.tealAccent, fontSize: 14, fontWeight: FontWeight.bold)),
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
            ),
          ),
        ],
      ),
    );
  }
}

// --- DATA STRUCTURE ---
class JourneyStep {
  final String title;
  final String description;
  final List<String> bulletPoints;
  final IconData icon;

  JourneyStep({
    required this.title,
    required this.description,
    this.bulletPoints = const [],
    required this.icon,
  });
}

// --- THE CONTENT ---
final List<JourneyStep> _journeySteps = [
  JourneyStep(
    title: 'Budget Your Income (The 50/30/20 Rule)',
    description: 'Before investing, you need to know where your money goes. Divide your monthly income into three parts:',
    icon: Icons.pie_chart_outline,
    bulletPoints: [
      'Needs (50%): Rent, groceries, utilities, and essential bills.',
      'Wants (30%): Dining out, entertainment, and hobbies.',
      'Savings/Investments (20%+): Pay yourself first. This is the seed money for your future wealth.',
    ],
  ),
  JourneyStep(
    title: 'Build a Safety Net (Protection First)',
    description: 'Do not invest in the stock market until you have a safety net. Markets go up and down, and you don\'t want to be forced to sell your investments at a loss because of an emergency.',
    icon: Icons.shield_outlined,
    bulletPoints: [
      'Emergency Fund: Save 3 to 6 months of living expenses in a highly liquid, secure account (like a Money Market Fund or Savings Account).',
      'Insurance/Takaful: Secure Health and Life insurance to protect yourself and your dependents from sudden medical or financial shocks.',
    ],
  ),
  JourneyStep(
    title: 'Start Investing',
    description: 'Once your safety net is fully funded, you are officially ready to start growing your wealth.',
    icon: Icons.rocket_launch_outlined,
  ),
  JourneyStep(
    title: 'Choose Your Investment Type',
    description: 'Match your investments to your timeline and risk tolerance:',
    icon: Icons.tune_rounded,
    bulletPoints: [
      'High Risk (Long Term 5+ Years): Equity Mutual Funds, Stocks, and ETFs. Great for beating inflation and building wealth.',
      'Low Risk (Short Term 1-3 Years): Money Market and Income Funds. Great for preserving capital and earning steady profit.',
      'Self-Investment (Optional but highly recommended): Upskill yourself, buy a course, or fund a side hustle to increase your primary income.',
    ],
  ),
  JourneyStep(
    title: 'Select a Fund (Due Diligence)',
    description: 'Don\'t just pick a fund blindly. Do your research:',
    icon: Icons.fact_check_outlined,
    bulletPoints: [
      'Match the fund to your financial goal and risk profile.',
      'Check past returns (3Y, 5Y, 10Y) and compare them against the benchmark.',
      'Review the Expense Ratio (TER), front-end/back-end loads, and tax category.',
      'Read the latest Fund Manager Report (FMR).',
    ],
  ),
  JourneyStep(
    title: 'Open Your Account',
    description: 'You have three main options to start investing in Mutual Funds in Pakistan:',
    icon: Icons.account_balance_outlined,
    bulletPoints: [
      'Direct with AMC (Asset Management Company): Open an account directly through the AMC\'s website or app.',
      'Digital Platforms: Use aggregate platforms like Emlaak Financials (SECP Owned) or other distributors for easy access to multiple AMCs.',
      'CDC Account: Open an account with the Central Depository Company and link it to your AMCs.',
    ],
  ),
  JourneyStep(
    title: 'Invest & Automate',
    description: 'Consistency is the secret to wealth.',
    icon: Icons.autorenew_rounded,
    bulletPoints: [
      'Automate: Set up a Systematic Investment Plan (SIP) so money is invested automatically every month.',
      'Monitor: Review your portfolio quarterly and rebalance it annually to ensure it still aligns with your goals.',
    ],
  ),
  JourneyStep(
    title: 'Continuous Improvement',
    description: '(Optional but powerful)',
    icon: Icons.trending_up_rounded,
    bulletPoints: [
      'Scale Up: As your income grows (salary increments, bonuses), increase your monthly SIP amount.',
      'Diversify: Learn about new asset classes (Commodities, Real Estate) over time.',
      'Reassess: Update your financial goals yearly as your life circumstances change.',
    ],
  ),
];