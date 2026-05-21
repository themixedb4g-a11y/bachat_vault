import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:bachat_vault/screens/index_investing_screen.dart';
import 'package:bachat_vault/screens/risk_profiler_screen.dart';
import 'package:bachat_vault/screens/dashboard.dart'; // To access AppData
import 'package:bachat_vault/screens/manager_scorecard_screen.dart';

// ============================================================================
// 1. THE NEW "TOOLS" MAIN MENU
// ============================================================================
class CalculatorsScreen extends StatefulWidget {
  const CalculatorsScreen({super.key});

  @override
  State<CalculatorsScreen> createState() => _CalculatorsScreenState();
}

class _CalculatorsScreenState extends State<CalculatorsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Widget _buildToolCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Widget destinationScreen,
  }) {
    return InkWell(
      onTap: () {
        // --- ADD THIS SAFETY CHECK ---
        if (AppData.allFunds.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Market data is still loading, please wait...'),
              backgroundColor: Colors.teal,
            ),
          );
          return;
        }
        // --- NAVIGATION ---
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destinationScreen),
        );
      },
      borderRadius: BorderRadius.circular(20),

      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withOpacity(0.3)),
          gradient: LinearGradient(
            colors: [accentColor.withOpacity(0.1), Colors.transparent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text(
            'Tools',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
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
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  
                  _buildToolCard(
                    context: context,
                    title: 'Financial Calculators',
                    subtitle: 'Plan your SIP, SWP, and FIRE goals. Calculate VPS Tax Credit',
                    icon: Icons.calculate_rounded,
                    accentColor: Colors.tealAccent,
                    destinationScreen: const FinancialCalculatorsScreen(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildToolCard(
                    context: context,
                    title: '✨ Index Tracker',
                    subtitle: 'Index Investing for KSE100, KMI30 & PSXDIV20.',
                    icon: Icons.pie_chart_rounded,
                    accentColor: Colors.amberAccent, 
                    destinationScreen: const IndexInvestingScreen(),
                  ),

                  const SizedBox(height: 16),
                  
                    _buildToolCard(
                    context: context,
                    title: '🧠 Smart Risk Profiler',
                    subtitle: 'Take a quick quiz to discover your investor profile and ideal asset allocation.',
                    icon: Icons.psychology_rounded,
                    accentColor: Colors.purpleAccent,
                    // Pass the RiskProfilerScreen with the data from the Global Vault
                    destinationScreen: Builder(builder: (context) {
                      return RiskProfilerScreen(
                        allFunds: AppData.allFunds,
                        benchmarkStats: AppData.benchmarkStats,
                      );
                    }),
                  ),

                  const SizedBox(height: 16),
                  
                    _buildToolCard(
                    context: context,
                    title: '🏆 Manager Scorecard',
                    subtitle: 'Rankings of Pakistan\'s top mutual fund managers based on performance and risk.',
                    icon: Icons.leaderboard_rounded,
                    accentColor: Colors.amberAccent,
                    destinationScreen: Builder(builder: (context) {
                      return const ManagerScorecardScreen();
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 2. THE TABBED FINANCIAL CALCULATORS SCREEN
// ============================================================================
class FinancialCalculatorsScreen extends StatefulWidget {
  const FinancialCalculatorsScreen({super.key});

  @override
  State<FinancialCalculatorsScreen> createState() => _FinancialCalculatorsScreenState();
}

class _FinancialCalculatorsScreenState extends State<FinancialCalculatorsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
            'Calculators',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: Colors.white),
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withOpacity(0.2)),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Colors.tealAccent,
                labelColor: Colors.tealAccent,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
                dividerColor: Colors.transparent,
                tabAlignment: TabAlignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                tabs: const [Tab(text: 'SIP'), Tab(text: 'VPS'), Tab(text: 'SWP'), Tab(text: 'FIRE')],
              ),
            ),
          ),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF000000)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: TabBarView(
              controller: _tabController,
              children: const [SipCalculator(), VpsTaxCalculator(), SwpCalculator(), FireCalculator()],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 3. VPS TAX CREDIT CALCULATOR (MONTHLY FIXED)
// ============================================================================
class VpsTaxCalculator extends StatefulWidget {
  const VpsTaxCalculator({super.key});
  @override
  State<VpsTaxCalculator> createState() => _VpsTaxCalculatorState();
}

class _VpsTaxCalculatorState extends State<VpsTaxCalculator> with AutomaticKeepAliveClientMixin {
  final TextEditingController _monthlySalaryController = TextEditingController(text: '3,00,000');
  final TextEditingController _vpsInvController = TextEditingController(text: '5,00,000');

  double _grossSalary = 0;
  double _incomeTaxMonthly = 0;
  double _taxCreditMonthly = 0;
  double _netIncomeTaxMonthly = 0;
  double _takeHomeAnnual = 0;
  double _takeHomeMonthly = 0;
  double _avgTaxRate = 0;
  double _maxEligibleInvestment = 0;

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  void _calculate() {
    final double monthlySalary = double.tryParse(_monthlySalaryController.text.replaceAll(',', '')) ?? 0;
    final double vpsInvestment = double.tryParse(_vpsInvController.text.replaceAll(',', '')) ?? 0;

    double gross = monthlySalary * 12;
    double tax = 0;

    if (gross <= 600000) {
      tax = 0;
    } else if (gross <= 1200000) {
      tax = (gross - 600000) * 0.01;
    } else if (gross <= 2200000) {
      tax = 6000 + (gross - 1200000) * 0.11;
    } else if (gross <= 3200000) {
      tax = 116000 + (gross - 2200000) * 0.23;
    } else if (gross <= 4100000) {
      tax = 346000 + (gross - 3200000) * 0.30;
    } else if (gross <= 10000000) {
      tax = 616000 + (gross - 4100000) * 0.35;
    } else {
      tax = 2681000 + (gross - 10000000) * 0.35;
      tax = tax * 1.09; 
    }

    double avgRate = gross > 0 ? (tax / gross) : 0;
    double maxEligible = gross * 0.20;
    
    double eligibleInvestment = min(vpsInvestment, maxEligible);
    double taxCredit = avgRate * eligibleInvestment;
    
    double netTax = tax - taxCredit;
    if (netTax < 0) netTax = 0; 
    
    double takeHomeAnnual = gross - netTax;
    
    setState(() {
      _grossSalary = gross;
      _avgTaxRate = avgRate * 100; 
      _maxEligibleInvestment = maxEligible;
      
      // Converted to Monthly exactly as requested
      _incomeTaxMonthly = tax / 12;
      _taxCreditMonthly = taxCredit / 12;
      _netIncomeTaxMonthly = netTax / 12;
      
      _takeHomeAnnual = takeHomeAnnual;
      _takeHomeMonthly = takeHomeAnnual / 12;
    });
  }

  Widget _buildField({required String label, required String prefix, required TextEditingController controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
          child: TextField(
            controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [LengthLimitingTextInputFormatter(12), IndianNumberFormatter()],
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            onChanged: (val) => _calculate(),
            decoration: InputDecoration(prefixText: prefix.isNotEmpty ? '$prefix ' : null, prefixStyle: const TextStyle(color: Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.bold), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Padding(padding: EdgeInsets.only(bottom: 16.0, top: 8.0), child: Text('VPS Tax Credit Calculator', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))),
                child: Column(
                  children: [
                    _buildField(label: 'Your Monthly Salary', prefix: 'PKR', controller: _monthlySalaryController),
                    const SizedBox(height: 16),
                    _buildField(label: 'Annual Investment in VPS', prefix: 'PKR', controller: _vpsInvController),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.teal.withOpacity(0.1), Colors.tealAccent.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.tealAccent.withOpacity(0.3))),
                child: Column(
                  children: [
                    _buildResultRow('Gross Annual Salary', 'PKR ${_currencyFormat.format(_grossSalary)}', Colors.white), 
                    const SizedBox(height: 4),
                    _buildResultRow('Avg Tax Rate', '${_avgTaxRate.toStringAsFixed(2)}%', Colors.white54, isSubText: true),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white12)),
                    
                    _buildResultRow('Max Eligible Investment (20%)', 'PKR ${_currencyFormat.format(_maxEligibleInvestment)}', Colors.amberAccent), 
                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white12)),
                    
                    _buildResultRow('Original Monthly Tax', 'PKR ${_currencyFormat.format(_incomeTaxMonthly)}', Colors.redAccent.shade100), 
                    const SizedBox(height: 8),
                    _buildResultRow('Monthly Tax Credit', 'PKR ${_currencyFormat.format(_taxCreditMonthly)}', Colors.greenAccent), 
                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white12)),
                    
                    _buildResultRow('Net Monthly Income Tax', 'PKR ${_currencyFormat.format(_netIncomeTaxMonthly)}', Colors.white, isTotal: true), 
                    const SizedBox(height: 16),
                    
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.tealAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.tealAccent.withOpacity(0.3))),
                      child: Column(
                        children: [
                          _buildResultRow('Net Monthly Take-Home', 'PKR ${_currencyFormat.format(_takeHomeMonthly)}', Colors.tealAccent, isTotal: true),
                          const SizedBox(height: 8),
                          _buildResultRow('Net Annual Take-Home', 'PKR ${_currencyFormat.format(_takeHomeAnnual)}', Colors.tealAccent.shade100, isSubText: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, Color valueColor, {bool isTotal = false, bool isSubText = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
      children: [
        Expanded(child: Text(label, style: TextStyle(color: isSubText ? Colors.white54 : Colors.white70, fontSize: isTotal ? 14 : isSubText ? 11 : 12, fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500))), 
        const SizedBox(width: 8),
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: Text(value, style: TextStyle(color: valueColor, fontSize: isTotal ? 20 : isSubText ? 12 : 15, fontWeight: FontWeight.bold))))
      ]
    );
  }
}

// ============================================================================
// 4. COMBINED SIP & LUMPSUM CALCULATOR
// ============================================================================
class SipCalculator extends StatefulWidget {
  const SipCalculator({super.key});
  @override
  State<SipCalculator> createState() => _SipCalculatorState();
}

class _SipCalculatorState extends State<SipCalculator> with AutomaticKeepAliveClientMixin {
  final TextEditingController _lumpsumController = TextEditingController(text: '0');
  final TextEditingController _amountController = TextEditingController(text: '10,000');
  final TextEditingController _rateController = TextEditingController(text: '16');
  final TextEditingController _yearsController = TextEditingController(text: '10');
  final TextEditingController _stepUpController = TextEditingController(text: '10');
  final TextEditingController _inflationController = TextEditingController(text: '0');

  double _totalInvested = 0; 
  double _estimatedReturns = 0; 
  double _totalValue = 0;
  double _adjustedTotalValue = 0;

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0);

  bool _isLoadingFunds = true;
  List<Map<String, dynamic>> _allFunds = [];
  List<String> _categories = ['All', 'Equity'];
  String _selectedCategory = 'Equity';
  String? _selectedFundTicker;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() { 
    super.initState(); 
    
    // THE FIX: Listen to changes and validate the selected fund
    _yearsController.addListener(() { 
      setState(() {
        _validateSelectedFund();
      }); 
    });

    _calculate(); 
    _fetchFundsData();
  }

  // THE FIX: Safe-check to prevent Dropdown crash
  void _validateSelectedFund() {
    if (_selectedFundTicker == null || _allFunds.isEmpty) return;

    int targetYears = int.tryParse(_yearsController.text.replaceAll(',', '')) ?? 0;
    
    bool isValid = _allFunds.where((f) {
      if (_selectedCategory != 'All' && (f['short_category'] ?? f['category']) != _selectedCategory) return false;
      if (targetYears > 0) {
        DateTime? incDate = f['inception_date'];
        if (incDate != null) {
          double ageYears = DateTime.now().difference(incDate).inDays / 365.25;
          if (ageYears < (targetYears - 1.0)) return false; 
        }
      }
      return true;
    }).any((f) => f['ticker'] == _selectedFundTicker);

    if (!isValid) {
      _selectedFundTicker = null;
    }
  }

  final Map<String, String> categoryMap = {
    'Equity': 'Equity', 'Shariah Compliant Equity': 'Equity',
    'Money Market': 'Money Market', 'Shariah Compliant Money Market': 'Money Market',
    'Income': 'Income', 'Shariah Compliant Income': 'Income',
    'Capital Protected': 'Capital Protected', 'Shariah Compliant Capital Protected': 'Capital Protected',
    'Capital Protected - Income': 'Capital Protected - Income',
    'Aggressive Fixed Income': 'Aggressive Fixed Income', 'Shariah Compliant Aggressive Fixed Income': 'Aggressive Fixed Income',
    'Balanced': 'Balanced', 'Shariah Compliant Balanced': 'Balanced',
    'Asset Allocation': 'Asset Allocation', 'Shariah Compliant Asset Allocation': 'Asset Allocation',
    'Fund of Funds': 'Fund of Funds', 'Shariah Compliant Fund of Funds': 'Fund of Funds', 'Shariah Compliant Fund of Funds - CPPI': 'Fund of Funds',
    'Index Tracker': 'Index Tracker', 'Shariah Compliant Index Tracker': 'Index Tracker', 'Index': 'Index',
    'Shariah Compliant Commodities': 'Commodities',
    'Exchange Traded Fund': 'Exchange Traded Fund', 'Shariah Compliant Exchange Traded Fund': 'Exchange Traded Fund',
    'VPS-Money Market': 'VPS-Money Market', 'VPS-Shariah Compliant Money Market': 'VPS-Money Market',
    'VPS-Debt': 'VPS-Debt', 'VPS-Shariah Compliant Debt': 'VPS-Debt',
    'VPS-Commodities / Gold': 'VPS-Commodities', 'VPS-Shariah Compliant Commodities / Gold': 'VPS-Commodities',
    'VPS-Equity': 'VPS-Equity', 'VPS-Shariah Compliant Equity': 'VPS-Equity',
    'Dedicated Equity': 'Equity', 'Shariah Compliant Dedicated Equity': 'Equity',
  };

  String _cleanFundName(String name) {
    if (name.isEmpty) return name;
    return name
        .replaceAll('Exchange Traded Fund', 'ETF')
        .replaceAll('NBP Islamic Principal Protection Fund I (NBP Islamic Principal Protection Plan I)', 'NBP Islamic Principal Protection Plan I')
        .replaceAll('NBP Islamic Principal Protection Fund I (NBP Islamic Principal Protection Plan II)', 'NBP Islamic Principal Protection Plan II')
        .replaceAll('NBP Islamic Principal Protection Fund I (NBP Islamic Principal Protection Plan III)', 'NBP Islamic Principal Protection Plan III')
        .replaceAll('NBP Islamic Principal Protection Fund I (NBP Islamic Principal Protection Plan IV)', 'NBP Islamic Principal Protection Plan IV')
        .replaceAll('Pak-Qatar Asset Allocation Plan I (PQAAP  IA)', 'Pak Qatar Asset Allocation Plan I')
        .replaceAll('Pak-Qatar Asset Allocation Plan II (PQAAP  IIA)', 'Pak Qatar Asset Allocation Plan II')
        .replaceAll('Pak-Qatar Asset Allocation Plan III (PQAAP  IIIA)', 'Pak Qatar Asset Allocation Plan III')
        .replaceAll('Alhamra Opportunity Fund (Dividend Strategy Plan)', 'Alhamra Opportunity Fund')
        .replaceAll('MCB Pakistan Opportunity Fund (MCB Pakistan  Dividend Yield Plan)', 'MCB Pakistan Opportunity Fund')
        .replaceAll('JS Islamic Sarmaya Mehfooz Fund (JS Islamic Sarmaya Mehfooz Plan 1)', 'JS Islamic Sarmaya Mehfooz Plan I')
        .replaceAll('Faysal Islamic Sovereign Fund (Faysal Islamic Sovereign Plan I)', 'Faysal Islamic Sovereign Plan I')
        .replaceAll('Faysal Islamic Sovereign Fund (Faysal Islamic Sovereign Plan II)', 'Faysal Islamic Sovereign Plan II')
        .replaceAll("Faysal Khushal Mustaqbil Fund (Faysal Nu�umah Women Savers Plan)", "Faysal Nu'umah Women Savers Plan")
        .replaceAll('Faysal Islamic Financial Planning Fund II (Faysal Priority Ascend Plan I)', 'Faysal Priority Ascend Plan I')
        .replaceAll('Faysal Islamic Financial Planning Fund II (Faysal Priority Ascend Plan II)', 'Faysal Priority Ascend Plan II')
        .replaceAll('Faysal Islamic Financial Planning Fund II (Faysal Priority Ascend Plan III)', 'Faysal Priority Ascend Plan III')
        .replaceAll("Faysal Khushal Mustaqbil Fund (Faysal Barak�ah Women Savers Plan)", "Faysal Barak'ah Women Savers Plan")
        .replaceAll('Faysal Islamic Asset Allocation Fund III (Faysal Shariah Flex Plan I)', 'Faysal Shariah Flex Plan I')
        .replaceAll('Faysal Islamic Asset Allocation Fund III (Faysal Shariah Flex Plan II)', 'Faysal Shariah Flex Plan II')
        .replaceAll('Faysal Islamic Asset Allocation Fund III (Faysal Shariah Flex Plan III)', 'Faysal Shariah Flex Plan III')
        .replaceAll('Faysal Islamic Asset Allocation Fund IV (Faysal Shariah Flex Plan IV)', 'Faysal Shariah Flex Plan IV')
        .replaceAll('Faysal Islamic Financial Growth Fund (Faysal Islamic Financial Growth Plan I)', 'Faysal Islamic Financial Growth Plan I')
        .replaceAll('Faysal Islamic Financial Growth Fund (Faysal Islamic Financial Growth Plan II)', 'Faysal Islamic Financial Growth Plan II')
        .replaceAll('Atlas Islamic Fund of Funds (Atlas Aggressive Allocation Islamic Plan)', 'Atlas Islamic Fund of Funds (Aggressive)')
        .replaceAll('Atlas Islamic Fund of Funds (Atlas Conservative Allocation Islamic Plan)', 'Atlas Islamic Fund of Funds (Conservative)')
        .replaceAll('Atlas Islamic Fund of Funds (Atlas Moderate Allocation Islamic Plan)', 'Atlas Islamic Fund of Funds (Moderate)')
        .replaceAll('Alfalah GHP Islamic Prosperity Planning Fund (Alfalah GHP Islamic Moderate Allocation Plan)', 'Alfalah GHP IPP Fund (Moderate)')
        .replaceAll('Alfalah GHP Islamic Prosperity Planning Fund (Alfalah GHP Islamic Active Allocation Plan II)', 'Alfalah GHP IPP Fund (Active)')
        .replaceAll('Alfalah GHP Islamic Prosperity Planning Fund (Alfalah GHP Islamic Balance Allocation Plan)', 'Alfalah GHP IPP Fund (Balance)')
        .replaceAll('Alfalah GHP Prosperity Planning Fund (Alfalah GHP Active Allocation Plan)', 'Alfalah GHP PP Fund (Active)')
        .replaceAll('Alfalah GHP Prosperity Planning Fund (Alfalah GHP Conservative Allocation Plan)', 'Alfalah GHP PP Fund (Conservative)')
        .replaceAll('Alfalah GHP Prosperity Planning Fund (Capital Preservation Plan IV)', 'Alfalah GHP PP Fund (Capital Preservation Plan IV)')
        .replaceAll('Alfalah GHP Prosperity Planning Fund (Alfalah GHP Moderate Allocation Plan)', 'Alfalah GHP PP Fund (Moderate)')
        .replaceAll('Alfalah Financial Value Fund (Alfalah Financial Value Plan I)', 'Alfalah Financial Value Plan I')
        .replaceAll('Alfalah Islamic Sovereign Fund (Alfalah Islamic Sovereign Plan I)', 'Alfalah Islamic Sovereign Plan I')
        .replaceAll('Alfalah Islamic Sovereign Fund (Alfalah Islamic Sovereign Plan II)', 'Alfalah Islamic Sovereign Plan II')
        .replaceAll('Alfalah Islamic Sovereign Fund (Alfalah Islamic Sovereign Plan III)', 'Alfalah Islamic Sovereign Plan III')
        .replaceAll('Meezan Financial Planning Fund of Funds (Very Conservative Allocation Plan)', 'Meezan FP Fund of Funds (Very Conservative)')
        .replaceAll('Meezan Financial Planning Fund of Funds (Moderate)', 'Meezan FP Fund of Funds (Moderate)')
        .replaceAll('Meezan Financial Planning Fund of Funds (Conservative)', 'Meezan FP Fund of Funds (Conservative)')
        .replaceAll('Meezan Financial Planning Fund of Funds (MAAP I)', 'Meezan FP Fund of Funds (MAAP-I)')
        .replaceAll('Meezan Financial Planning Fund of Funds (Aggressive)', 'Meezan FP Fund of Funds (Aggressive)')
        .replaceAll('Meezan Dynamic Asset Allocation Fund (Meezan Dividend Yield Plan)', 'Meezan Dynamic Asset Allocation Fund')
        .replaceAll('Meezan Daily Income Fund (Meezan Mahana Munafa Plan)', 'Meezan Mahana Munafa Plan')
        .replaceAll('Meezan Daily Income Fund (Meezan Munafa Plan I)', 'Meezan Munafa Plan I')
        .replaceAll('Meezan Daily Income Fund (Meezan Sehl Account Plan) (MSHP)', 'Meezan Sehl Account Plan')
        .replaceAll('Meezan Daily Income Fund (Meezan Super Saver Plan) (MSSP)', 'Meezan Super Saver Plan')
        .replaceAll('Meezan Capital Protected Fund III (Meezan Capital Secure Plan I)', 'Meezan Capital Secure Plan I')
        .replaceAll('ABL Islamic Financial Planning Fund (Conservative Allocation Plan)', 'ABL Islamic FP Fund (Conservative)')
        .replaceAll('ABL Financial Planning Fund (Strategic Allocation Plan)', 'ABL FP Fund (Strategic Allocation Plan)')
        .replaceAll('ABL Financial Planning Fund (Conservative Plan)', 'ABL Islamic FP Fund (Conservative)')
        .replaceAll('ABL Islamic Financial Planning Fund (Active Allocation Plan)', 'ABL Islamic FP Fund (Active)')
        .replaceAll('ABL Islamic Financial Planning Fund (Capital Preservation Plan I)', 'ABL Islamic FP Fund (Capital Preservation Plan I)')
        .replaceAll('ABL Special Saving Fund (ABL Special Saving Plan I)', 'ABL Special Saving Plan I')
        .replaceAll('ABL Special Saving Fund (ABL Special Saving Plan II)', 'ABL Special Saving Plan II')
        .replaceAll('ABL Special Saving Fund (ABL Special Saving Plan III)', 'ABL Special Saving Plan III')
        .replaceAll('ABL Special Saving Fund (ABL Special Saving Plan IV)', 'ABL Special Saving Plan IV')
        .replaceAll('ABL Special Saving Fund (ABL Special Saving Plan V)', 'ABL Special Saving Plan V')
        .replaceAll('ABL Special Saving Fund (ABL Special Saving Plan VI)', 'ABL Special Saving Plan VI')
        .replaceAll('Government', 'Govt.')
        .trim();
  }

  Future<void> _fetchFundsData() async {
    final SupabaseClient supabase = Supabase.instance.client;

    try {
      final masterResponse = await supabase.from('master_funds').select('ticker, fund_name, category, inception_date');
      final statsResponse = await supabase.from('performance_stats').select('ticker, return_1y, return_3y, return_5y, return_10y, return_15y, return_20y');

      List<Map<String, dynamic>> combined = [];
      Set<String> catSet = {};

      for (var mf in masterResponse) {
        final rawCat = mf['category']?.toString().trim() ?? '';
        final mappedCat = categoryMap[rawCat] ?? rawCat;
        final rawName = mf['fund_name']?.toString() ?? 'Unknown';

        if (mappedCat == 'Crypto' || ['KSE100', 'KMI30', 'GOLD_24K', 'CPI_PK'].contains(mf['ticker'])) continue;

        final ticker = mf['ticker'];
        final stats = statsResponse.firstWhere((s) => s['ticker'] == ticker, orElse: () => <String, dynamic>{});
        
        DateTime? incDate;
        if (mf['inception_date'] != null) {
          incDate = DateTime.tryParse(mf['inception_date'].toString());
        }

        combined.add({
          'ticker': ticker,
          'fund_name': rawName,
          'short_name': _cleanFundName(rawName),
          'category': rawCat,
          'short_category': mappedCat,
          'inception_date': incDate,
          'return_1y': stats['return_1y'],
          'return_3y': stats['return_3y'],
          'return_5y': stats['return_5y'],
          'return_10y': stats['return_10y'],
          'return_15y': stats['return_15y'],
          'return_20y': stats['return_20y'],
        });

        if (mappedCat.isNotEmpty) catSet.add(mappedCat);
      }

      if (mounted) {
        setState(() {
          _allFunds = combined;
          _categories = ['All', ...catSet.toList()..sort()];
          if (!_categories.contains(_selectedCategory)) {
            _selectedCategory = 'All';
          }
          _isLoadingFunds = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFunds = false);
    }
  }

  void _calculate() {
    final double initialLumpsum = double.tryParse(_lumpsumController.text.replaceAll(',', '')) ?? 0;
    final double initialMonthlyInvestment = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    final double stepUpPercentage = double.tryParse(_stepUpController.text.replaceAll(',', '')) ?? 0;
    final double expectedReturn = double.tryParse(_rateController.text.replaceAll(',', '')) ?? 0;
    final double years = double.tryParse(_yearsController.text.replaceAll(',', '')) ?? 0;
    final double inflation = double.tryParse(_inflationController.text.replaceAll(',', '')) ?? 0;

    if ((initialMonthlyInvestment > 0 || initialLumpsum > 0) && years > 0) {
      double totalBalance = initialLumpsum;
      double totalInvested = initialLumpsum; 
      double currentMonthlySip = initialMonthlyInvestment;
      double monthlyRate = (expectedReturn / 100) / 12;
      int totalMonths = (years * 12).toInt();

      for (int month = 1; month <= totalMonths; month++) {
        totalInvested += currentMonthlySip;
        totalBalance += currentMonthlySip; 
        totalBalance += totalBalance * monthlyRate;
        if (month % 12 == 0) currentMonthlySip += currentMonthlySip * (stepUpPercentage / 100);
      }
      
      final double adjustedValue = inflation > 0 ?
        totalBalance / pow((1 + (inflation / 100)), years) : totalBalance;

      setState(() { 
        _totalInvested = totalInvested; 
        _totalValue = totalBalance; 
        _estimatedReturns = totalBalance - totalInvested; 
        _adjustedTotalValue = adjustedValue; 
      });
    } else {
      setState(() { _totalInvested = 0; _totalValue = 0; _estimatedReturns = 0; _adjustedTotalValue = 0; });
    }
  }

  void _onCategoryChanged(String? val) {
    if (val != null) {
      setState(() {
        _selectedCategory = val;
        _selectedFundTicker = null; 
      });
    }
  }

  void _onFundSelected(String? ticker) {
    setState(() { _selectedFundTicker = ticker; });
    if (ticker == null) return;

    final fund = _allFunds.firstWhere((f) => f['ticker'] == ticker, orElse: () => {});
    if (fund.isEmpty) return;

    int targetYears = int.tryParse(_yearsController.text.replaceAll(',', '')) ?? 5; 

    List<Map<String, dynamic>> availablePeriods = [
      {'years': 1, 'key': 'return_1y'},
      {'years': 3, 'key': 'return_3y'},
      {'years': 5, 'key': 'return_5y'},
      {'years': 10, 'key': 'return_10y'},
      {'years': 15, 'key': 'return_15y'},
      {'years': 20, 'key': 'return_20y'},
    ];

    var validPeriods = availablePeriods.where((p) => fund[p['key']] != null).toList();

    if (validPeriods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough history to calculate an average for this fund.'), backgroundColor: Colors.redAccent, duration: Duration(seconds: 2)),
      );
      return;
    }

    validPeriods.sort((a, b) {
      int diffA = (a['years'] - targetYears).abs();
      int diffB = (b['years'] - targetYears).abs();
      return diffA.compareTo(diffB);
    });

    var bestMatch = validPeriods.first;
    int bestYears = bestMatch['years'];
    double growthFactor = (fund[bestMatch['key']] as num).toDouble();

    double cagr = (pow(growthFactor, 1.0 / bestYears) - 1.0) * 100;
    
    _rateController.text = cagr.toStringAsFixed(2);
    _calculate();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Auto-filled Expected Return using the closest match: $bestYears-Year historical average (${cagr.toStringAsFixed(2)}%)', style: const TextStyle(color: Colors.white)), 
        backgroundColor: Colors.teal,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildField({required String label, required String prefix, required String suffix, required TextEditingController controller, bool isCurrency = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
          child: TextField(
            controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: isCurrency ? [LengthLimitingTextInputFormatter(12), IndianNumberFormatter()] : [LengthLimitingTextInputFormatter(6)],
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            onChanged: (val) => _calculate(),
            decoration: InputDecoration(prefixText: prefix.isNotEmpty ? '$prefix ' : null, prefixStyle: const TextStyle(color: Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.bold), suffixText: suffix.isNotEmpty ? ' $suffix' : null, suffixStyle: const TextStyle(color: Colors.white54, fontSize: 14), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({required String label, required String? value, required List<DropdownMenuItem<String>> items, required void Function(String?) onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          height: 56, 
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              dropdownColor: const Color(0xFF203A43),
              menuMaxHeight: 350,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.tealAccent),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              value: value,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final bool showInflation = (double.tryParse(_inflationController.text.replaceAll(',', '')) ?? 0) > 0;
    int targetYears = int.tryParse(_yearsController.text.replaceAll(',', '')) ?? 0;

    List<Map<String, dynamic>> filteredFunds = _allFunds.where((f) {
      if (_selectedCategory != 'All' && (f['short_category'] ?? f['category']) != _selectedCategory) {
        return false;
      }
      if (targetYears > 0) {
        DateTime? incDate = f['inception_date'];
        if (incDate != null) {
          double ageYears = DateTime.now().difference(incDate).inDays / 365.25;
          if (ageYears < (targetYears - 1.0)) return false; 
        }
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Padding(padding: EdgeInsets.only(bottom: 16.0, top: 8.0), child: Text('SIP Calculator', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))),
                child: Column(
                  children: [
                    Row(children: [
                      Expanded(child: _buildField(label: 'Initial Lumpsum', prefix: 'PKR', suffix: '', controller: _lumpsumController, isCurrency: true)), 
                      const SizedBox(width: 16), 
                      Expanded(child: _buildField(label: 'Monthly SIP', prefix: 'PKR', suffix: '', controller: _amountController, isCurrency: true))
                    ]), 
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: _buildField(label: 'Expected Return', prefix: '', suffix: '%', controller: _rateController)), 
                      const SizedBox(width: 16), 
                      Expanded(child: _buildField(label: 'Time Period', prefix: '', suffix: 'Years', controller: _yearsController))
                    ]), 
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: _buildField(label: 'Annual Step-up', prefix: '', suffix: '%', controller: _stepUpController)), 
                      const SizedBox(width: 16), 
                      Expanded(child: _buildField(label: 'Inflation P.A.', prefix: '', suffix: '%', controller: _inflationController))
                    ]),

                    const SizedBox(height: 20),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 12),
                    const Text('Or auto-fill Expected Return from a specific fund:', style: TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    
                    if (_isLoadingFunds) 
                      const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.tealAccent, strokeWidth: 2)))
                    else
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: _buildDropdown(
                              label: 'Category',
                              value: _selectedCategory,
                              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (val) {
                                _onCategoryChanged(val);
                                _validateSelectedFund(); // Validate immediately on change
                              },
                            )
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 6,
                            child: _buildDropdown(
                              label: 'Select Fund',
                              value: _selectedFundTicker,
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Choose a fund...', style: TextStyle(color: Colors.white54))),
                                ...filteredFunds.map((f) => DropdownMenuItem(
                                  value: f['ticker'] as String, 
                                  child: Text(f['short_name'] ?? f['fund_name']?.toString() ?? 'Unknown', overflow: TextOverflow.ellipsis, maxLines: 1)
                                )).toList()
                              ],
                              onChanged: _onFundSelected,
                            )
                          ),
                        ]
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.teal.withOpacity(0.1), Colors.tealAccent.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.tealAccent.withOpacity(0.3))),
                child: Column(
                  children: [
                    _buildResultRow('Total Invested', 'PKR ${_currencyFormat.format(_totalInvested)}', Colors.white), const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white12)),
                    _buildResultRow('Estimated Returns', '+PKR ${_currencyFormat.format(_estimatedReturns)}', Colors.greenAccent), const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white12)),
                    _buildResultRow('Total Value', 'PKR ${_currencyFormat.format(_totalValue)}', Colors.tealAccent, isTotal: true),
                    if (showInflation) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text('Inflation Adjusted: ', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 8),
                          Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text('PKR ${_currencyFormat.format(_adjustedTotalValue)}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.w700)))),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, Color valueColor, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
      children: [
        Expanded(child: Text(label, style: TextStyle(color: Colors.white70, fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500))), 
        const SizedBox(width: 8),
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: Text(value, style: TextStyle(color: valueColor, fontSize: isTotal ? 22 : 16, fontWeight: FontWeight.bold))))
      ]
    );
  }
}

// --- SWP CALCULATOR ---
class SwpCalculator extends StatefulWidget {
  const SwpCalculator({super.key});
  @override
  State<SwpCalculator> createState() => _SwpCalculatorState();
}

class _SwpCalculatorState extends State<SwpCalculator> with AutomaticKeepAliveClientMixin {
  final TextEditingController _amountController = TextEditingController(text: '1,00,00,000');
  final TextEditingController _withdrawalController = TextEditingController(text: '50,000');
  final TextEditingController _rateController = TextEditingController(text: '12');
  final TextEditingController _inflationController = TextEditingController(text: '9');
  final TextEditingController _yearsController = TextEditingController(text: '25');

  double _totalWithdrawn = 0; double _finalBalance = 0; int _monthsLasted = 0; bool _survived = true;

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() { super.initState(); _calculate(); }

  void _calculate() {
    final double totalInvestment = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    final double initialMonthlyWithdrawal = double.tryParse(_withdrawalController.text.replaceAll(',', '')) ?? 0;
    final double expectedReturn = double.tryParse(_rateController.text.replaceAll(',', '')) ?? 0;
    final double inflation = double.tryParse(_inflationController.text.replaceAll(',', '')) ?? 0;
    final double years = double.tryParse(_yearsController.text.replaceAll(',', '')) ?? 0;

    if (totalInvestment > 0 && initialMonthlyWithdrawal > 0 && years > 0) {
      double balance = totalInvestment;
      double currentWithdrawal = initialMonthlyWithdrawal; double totalWithdrawn = 0;
      double monthlyRate = (expectedReturn / 100) / 12; int monthsLasted = 0;
      int totalMonths = (years * 12).toInt(); bool survived = true;

      for (int month = 1; month <= totalMonths; month++) {
        balance += balance * monthlyRate;
        balance -= currentWithdrawal; totalWithdrawn += currentWithdrawal; monthsLasted++;
        if (balance <= 0) { balance = 0; survived = false; break; }
        if (month % 12 == 0) currentWithdrawal += currentWithdrawal * (inflation / 100);
      }
      setState(() { _totalWithdrawn = totalWithdrawn; _finalBalance = balance; _monthsLasted = monthsLasted; _survived = survived; });
    } else {
      setState(() { _totalWithdrawn = 0; _finalBalance = 0; _monthsLasted = 0; _survived = true; });
    }
  }

  Widget _buildField({required String label, required String prefix, required String suffix, required TextEditingController controller, bool isCurrency = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
          child: TextField(
            controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: isCurrency ? [LengthLimitingTextInputFormatter(12), IndianNumberFormatter()] : [LengthLimitingTextInputFormatter(6)],
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            onChanged: (val) => _calculate(),
            decoration: InputDecoration(prefixText: prefix.isNotEmpty ? '$prefix ' : null, prefixStyle: const TextStyle(color: Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.bold), suffixText: suffix.isNotEmpty ? ' $suffix' : null, suffixStyle: const TextStyle(color: Colors.white54, fontSize: 14), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    String statusMessage = _survived ? 'Your portfolio survived the full term!' : 'Your money ran out after ${_monthsLasted ~/ 12} years and ${_monthsLasted % 12} months.';
    Color statusColor = _survived ? Colors.greenAccent : Colors.redAccent.shade100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Padding(padding: EdgeInsets.only(bottom: 16.0, top: 8.0), child: Text('Systematic Withdrawal Plan Calculator', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))),
                child: Column(
                  children: [
                    Row(children: [Expanded(child: _buildField(label: 'Total Investment', prefix: 'PKR', suffix: '', controller: _amountController, isCurrency: true)), const SizedBox(width: 16), Expanded(child: _buildField(label: 'Monthly Withdrawal', prefix: 'PKR', suffix: '', controller: _withdrawalController, isCurrency: true))]), const SizedBox(height: 16),
                    Row(children: [Expanded(child: _buildField(label: 'Expected Return', prefix: '', suffix: '%', controller: _rateController)), const SizedBox(width: 16), Expanded(child: _buildField(label: 'Inflation P.A.', prefix: '', suffix: '%', controller: _inflationController))]), const SizedBox(height: 16),
                    Row(children: [Expanded(child: _buildField(label: 'Time Period', prefix: '', suffix: 'Years', controller: _yearsController)), const SizedBox(width: 16), const Spacer()]),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.teal.withOpacity(0.1), Colors.tealAccent.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.tealAccent.withOpacity(0.3))),
                child: Column(
                  children: [
                    _buildResultRow('Total Withdrawn', 'PKR ${_currencyFormat.format(_totalWithdrawn)}', Colors.white), const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: Colors.white12)),
                    _buildResultRow('Final Balance', 'PKR ${_currencyFormat.format(_finalBalance)}', Colors.tealAccent, isTotal: true), const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: statusColor.withOpacity(0.3))),
                      child: Row(children: [Icon(_survived ? Icons.check_circle_outline : Icons.warning_amber_rounded, color: statusColor, size: 20), const SizedBox(width: 8), Expanded(child: Text(statusMessage, style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w600)))]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, Color valueColor, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
      children: [
        Expanded(child: Text(label, style: TextStyle(color: Colors.white70, fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500))), 
        const SizedBox(width: 8),
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: Text(value, style: TextStyle(color: valueColor, fontSize: isTotal ? 22 : 16, fontWeight: FontWeight.bold))))
      ]
    );
  }
}

// --- FIRE CALCULATOR ---
class FireCalculator extends StatefulWidget {
  const FireCalculator({super.key});
  @override
  State<FireCalculator> createState() => _FireCalculatorState();
}

class _FireCalculatorState extends State<FireCalculator> with AutomaticKeepAliveClientMixin {
  final TextEditingController _currentAgeController = TextEditingController(text: '30');
  final TextEditingController _retirementAgeController = TextEditingController(text: '50');
  final TextEditingController _lifeExpectancyController = TextEditingController(text: '85');
  final TextEditingController _initialInvController = TextEditingController(text: '5,00,000');
  final TextEditingController _monthlyInvController = TextEditingController(text: '20,000');
  final TextEditingController _stepUpController = TextEditingController(text: '10');
  final TextEditingController _preRetireReturnController = TextEditingController(text: '16');
  final TextEditingController _postRetireReturnController = TextEditingController(text: '12');
  final TextEditingController _monthlyExpController = TextEditingController(text: '50,000');
  final TextEditingController _inflationController = TextEditingController(text: '9');

  double _corpusAtRetirement = 0; double _expensesAtRetirement = 0;
  int _survivedMonths = 0; bool _fireAchieved = false;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() { super.initState(); _calculate(); }

  void _calculate() {
    final int currentAge = int.tryParse(_currentAgeController.text.replaceAll(',', '')) ?? 0;
    final int retirementAge = int.tryParse(_retirementAgeController.text.replaceAll(',', '')) ?? 0;
    final int lifeExpectancy = int.tryParse(_lifeExpectancyController.text.replaceAll(',', '')) ?? 0;
    final double initialInvestment = double.tryParse(_initialInvController.text.replaceAll(',', '')) ?? 0;
    final double monthlyInvestment = double.tryParse(_monthlyInvController.text.replaceAll(',', '')) ?? 0;
    final double stepUp = double.tryParse(_stepUpController.text.replaceAll(',', '')) ?? 0;
    final double preRetireReturn = double.tryParse(_preRetireReturnController.text.replaceAll(',', '')) ?? 0;
    final double postRetireReturn = double.tryParse(_postRetireReturnController.text.replaceAll(',', '')) ?? 0;
    final double currentMonthlyExpenses = double.tryParse(_monthlyExpController.text.replaceAll(',', '')) ?? 0;
    final double inflation = double.tryParse(_inflationController.text.replaceAll(',', '')) ?? 0;

    if (currentAge > 0 && retirementAge > currentAge && lifeExpectancy > retirementAge) {
      int preRetireMonths = (retirementAge - currentAge) * 12;
      int postRetireMonths = (lifeExpectancy - retirementAge) * 12;
      double balance = initialInvestment; double currentMonthlyInv = monthlyInvestment; double currentExpenses = currentMonthlyExpenses;
      double preRate = (preRetireReturn / 100) / 12; double postRate = (postRetireReturn / 100) / 12;

      for (int m = 1; m <= preRetireMonths; m++) {
        balance += currentMonthlyInv;
        balance += balance * preRate;
        if (m % 12 == 0) { currentMonthlyInv += currentMonthlyInv * (stepUp / 100);
        currentExpenses += currentExpenses * (inflation / 100); }
      }
      double corpusAtRetirement = balance;
      double expensesAtRetirement = currentExpenses;
      int survivedMonths = 0;
      for (int m = 1; m <= postRetireMonths; m++) {
        balance += balance * postRate;
        balance -= currentExpenses; survivedMonths++;
        if (balance <= 0) { balance = 0; break; }
        if (m % 12 == 0) currentExpenses += currentExpenses * (inflation / 100);
      }
      setState(() { _corpusAtRetirement = corpusAtRetirement; _expensesAtRetirement = expensesAtRetirement; _survivedMonths = survivedMonths; _fireAchieved = balance > 0; });
    } else {
      setState(() { _corpusAtRetirement = 0; _expensesAtRetirement = 0; _survivedMonths = 0; _fireAchieved = false; });
    }
  }

  Widget _buildField({required String label, required String prefix, required String suffix, required TextEditingController controller, bool isCurrency = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.1))),
          child: TextField(
            controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: isCurrency ? [LengthLimitingTextInputFormatter(12), IndianNumberFormatter()] : [LengthLimitingTextInputFormatter(6)],
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            onChanged: (val) => _calculate(),
            decoration: InputDecoration(
              prefixText: prefix.isNotEmpty ? '$prefix ' : null, prefixStyle: const TextStyle(color: Colors.tealAccent, fontSize: 14, fontWeight: FontWeight.bold),
              suffixText: suffix.isNotEmpty ? ' $suffix' : null, suffixStyle: const TextStyle(color: Colors.white54, fontSize: 12),
              border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    String statusMessage = _fireAchieved ? 'FIRE Achieved! Your wealth survived until age ${_lifeExpectancyController.text}.' : 'Funds depleted at age ${(int.tryParse(_retirementAgeController.text) ?? 0) + (_survivedMonths ~/ 12)}.';
    Color statusColor = _fireAchieved ? Colors.greenAccent : Colors.redAccent.shade100;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                const Padding(padding: EdgeInsets.only(bottom: 12.0), child: Text('Financial Independence - Retire Early', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.1))),
                      child: Column(
                        children: [
                          Row(children: [Expanded(child: _buildField(label: 'Current Age', prefix: '', suffix: 'Yrs', controller: _currentAgeController)), const SizedBox(width: 12), Expanded(child: _buildField(label: 'Retirement Age', prefix: '', suffix: 'Yrs', controller: _retirementAgeController))]), const SizedBox(height: 8),
                          Row(children: [Expanded(child: _buildField(label: 'Life Expectancy', prefix: '', suffix: 'Yrs', controller: _lifeExpectancyController)), const SizedBox(width: 12), Expanded(child: _buildField(label: 'Initial Investment', prefix: 'PKR', suffix: '', controller: _initialInvController, isCurrency: true))]), const SizedBox(height: 8),
                          Row(children: [Expanded(child: _buildField(label: 'Monthly Investment', prefix: 'PKR', suffix: '', controller: _monthlyInvController, isCurrency: true)), const SizedBox(width: 12), Expanded(child: _buildField(label: 'Annual Step-up', prefix: '', suffix: '%', controller: _stepUpController))]), const SizedBox(height: 8),
                          Row(children: [Expanded(child: _buildField(label: 'Return (Pre-Retirement)', prefix: '', suffix: '%', controller: _preRetireReturnController)), const SizedBox(width: 12), Expanded(child: _buildField(label: 'Return (Post Retirement)', prefix: '', suffix: '%', controller: _postRetireReturnController))]), const SizedBox(height: 8),
                          Row(children: [Expanded(child: _buildField(label: 'Monthly Expenses', prefix: 'PKR', suffix: '', controller: _monthlyExpController, isCurrency: true)), const SizedBox(width: 12), Expanded(child: _buildField(label: 'Inflation P.A.', prefix: '', suffix: '%', controller: _inflationController))]),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20, top: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.teal.withOpacity(0.1), Colors.tealAccent.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.tealAccent.withOpacity(0.3))),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildResultRow('Corpus at Retirement', 'PKR ${_currencyFormat.format(_corpusAtRetirement)}', Colors.white, isTotal: true), const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.white12)),
                    _buildResultRow('1st Month Expenses (at Retirement)', 'PKR ${_currencyFormat.format(_expensesAtRetirement)}', Colors.white70), const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: statusColor.withOpacity(0.3))),
                      child: Row(children: [Icon(_fireAchieved ? Icons.check_circle_outline : Icons.warning_amber_rounded, color: statusColor, size: 20), const SizedBox(width: 8), Expanded(child: Text(statusMessage, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)))]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultRow(String label, String value, Color valueColor, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: TextStyle(color: Colors.white70, fontSize: isTotal ? 14 : 12, fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500))),
        const SizedBox(width: 8),
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: Text(value, style: TextStyle(color: valueColor, fontSize: isTotal ? 18 : 14, fontWeight: FontWeight.bold))))
      ],
    );
  }
}

class IndianNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleanText.split('.').length > 2) cleanText = oldValue.text.replaceAll(',', ''); 
    if (cleanText.isEmpty) return newValue.copyWith(text: '');
    List<String> parts = cleanText.split('.');
    String wholeNumber = parts[0];
    String decimalPart = parts.length > 1 ? '.${parts[1]}' : '';
    if (wholeNumber.isEmpty) return newValue.copyWith(text: cleanText);
    final formatter = NumberFormat.decimalPattern('en_IN');
    String formatted = formatter.format(int.parse(wholeNumber));
    String finalString = formatted + decimalPart;
    return TextEditingValue(text: finalString, selection: TextSelection.collapsed(offset: finalString.length));
  }
}