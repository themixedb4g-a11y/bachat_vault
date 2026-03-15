import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

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
            'Terms & Conditions',
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 16, bottom: 40, left: 20, right: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Last Updated: March 2026',
                          style: TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        _buildSection(
                          '1. Acceptance of Terms',
                          'By downloading, accessing, or using the Bachat Vault application ("App"), you agree to be bound by these Terms and Conditions. If you do not agree with any part of these terms, you must not use the App.',
                        ),
                        _buildSection(
                          '2. Not Financial Advice',
                          'Bachat Vault is strictly an educational and informational tool. We do not provide financial, investment, legal, or tax advice. Any data, articles, calculators, or charts provided within the App are for general informational purposes only. You should consult with a certified financial advisor before making any investment decisions.',
                        ),
                        _buildSection(
                          '3. Data Accuracy & Third-Party Sources',
                          'The financial data displayed in this App (including but not limited to NAVs, ETF prices, Gold rates, and Crypto prices) is aggregated from public and third-party sources such as MUFAP, PSX, AMC websites, and Yahoo Finance.\n\nWhile we strive to ensure the data is updated and accurate, Bachat Vault makes no warranties regarding the absolute accuracy, completeness, or timeliness of this data. Delays or errors from third-party sources may occur.',
                        ),
                        _buildSection(
                          '4. Calculators & Projections',
                          'The financial calculators (SIP, Lumpsum, Zakat, etc.) provided in the App use mathematical formulas based on user inputs and assumed hypothetical growth rates. These projections are estimates and do not guarantee future returns. Actual market returns will vary.',
                        ),
                        _buildSection(
                          '5. Limitation of Liability',
                          'Under no circumstances shall Bachat Vault, its developers, or its affiliates be liable for any direct, indirect, incidental, or consequential damages, including monetary losses, arising from your use of the App or your reliance on any information provided within it. You are solely responsible for your own investment trades and decisions.',
                        ),
                        _buildSection(
                          '6. Privacy & Data Security',
                          'We respect your privacy. Bachat Vault does not ask for, collect, or store your personal banking credentials, CNIC, or brokerage passwords. Any calculation inputs you enter remain on your device.',
                        ),
                        _buildSection(
                          '7. Changes to the App and Terms',
                          'We reserve the right to modify or discontinue any feature of the App at any time without prior notice. We may also update these Terms periodically. Continued use of the App constitutes your acceptance of the updated Terms.',
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 16),
                        const Text(
                          'If you have any questions about these Terms, please contact us via the Feedback & Support section in the app.',
                          style: TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }
}