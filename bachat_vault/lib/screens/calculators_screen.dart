import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class CalculatorsScreen extends StatefulWidget {
  const CalculatorsScreen({super.key});

  @override
  State<CalculatorsScreen> createState() => _CalculatorsScreenState();
}

class _CalculatorsScreenState extends State<CalculatorsScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;

  @override
  bool get wantKeepAlive => true;

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
    super.build(context);
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
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
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
                tabs: const [Tab(text: 'Lumpsum'), Tab(text: 'SIP'), Tab(text: 'SWP'), Tab(text: 'FIRE')],
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
              children: const [LumpsumCalculator(), SipCalculator(), SwpCalculator(), FireCalculator()],
            ),
          ),
        ),
      ),
    );
  }
}

class LumpsumCalculator extends StatefulWidget {
  const LumpsumCalculator({super.key});
  @override
  State<LumpsumCalculator> createState() => _LumpsumCalculatorState();
}

class _LumpsumCalculatorState extends State<LumpsumCalculator> with AutomaticKeepAliveClientMixin {
  final TextEditingController _amountController = TextEditingController(text: '10,00,000');
  final TextEditingController _rateController = TextEditingController(text: '16');
  final TextEditingController _yearsController = TextEditingController(text: '10');

  double _totalInvested = 0; double _estimatedReturns = 0; double _totalValue = 0;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() { super.initState(); _calculate(); }

  void _calculate() {
    final double principal = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    final double rate = double.tryParse(_rateController.text.replaceAll(',', '')) ?? 0;
    final double years = double.tryParse(_yearsController.text.replaceAll(',', '')) ?? 0;

    if (principal > 0 && years > 0) {
      final double finalValue = principal * pow((1 + (rate / 100)), years);
      setState(() { _totalInvested = principal; _totalValue = finalValue; _estimatedReturns = finalValue - principal; });
    } else {
      setState(() { _totalInvested = 0; _totalValue = 0; _estimatedReturns = 0; });
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
            inputFormatters: isCurrency ? [IndianNumberFormatter()] : [],
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Padding(padding: EdgeInsets.only(bottom: 16.0, top: 8.0), child: Text('Lumpsum Investment Calculator', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))),
                child: Column(
                  children: [
                    _buildField(label: 'Lumpsum Amount', prefix: 'PKR', suffix: '', controller: _amountController, isCurrency: true), const SizedBox(height: 16),
                    Row(children: [Expanded(child: _buildField(label: 'Expected Return', prefix: '', suffix: '%', controller: _rateController)), const SizedBox(width: 16), Expanded(child: _buildField(label: 'Time Period', prefix: '', suffix: 'Years', controller: _yearsController))]),
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
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(color: Colors.white70, fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500)), Text(value, style: TextStyle(color: valueColor, fontSize: isTotal ? 22 : 16, fontWeight: FontWeight.bold))]);
  }
}

class SipCalculator extends StatefulWidget {
  const SipCalculator({super.key});
  @override
  State<SipCalculator> createState() => _SipCalculatorState();
}

class _SipCalculatorState extends State<SipCalculator> with AutomaticKeepAliveClientMixin {
  final TextEditingController _amountController = TextEditingController(text: '10,000');
  final TextEditingController _stepUpController = TextEditingController(text: '10');
  final TextEditingController _rateController = TextEditingController(text: '16');
  final TextEditingController _yearsController = TextEditingController(text: '10');

  double _totalInvested = 0; double _estimatedReturns = 0; double _totalValue = 0;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() { super.initState(); _calculate(); }

  void _calculate() {
    final double initialMonthlyInvestment = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    final double stepUpPercentage = double.tryParse(_stepUpController.text.replaceAll(',', '')) ?? 0;
    final double expectedReturn = double.tryParse(_rateController.text.replaceAll(',', '')) ?? 0;
    final double years = double.tryParse(_yearsController.text.replaceAll(',', '')) ?? 0;

    if (initialMonthlyInvestment > 0 && years > 0) {
      double totalBalance = 0; double totalInvested = 0; double currentMonthlySip = initialMonthlyInvestment;
      double monthlyRate = (expectedReturn / 100) / 12; int totalMonths = (years * 12).toInt();

      for (int month = 1; month <= totalMonths; month++) {
        totalInvested += currentMonthlySip; totalBalance += currentMonthlySip; totalBalance += totalBalance * monthlyRate;
        if (month % 12 == 0) currentMonthlySip += currentMonthlySip * (stepUpPercentage / 100);
      }
      setState(() { _totalInvested = totalInvested; _totalValue = totalBalance; _estimatedReturns = totalBalance - totalInvested; });
    } else {
      setState(() { _totalInvested = 0; _totalValue = 0; _estimatedReturns = 0; });
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
            inputFormatters: isCurrency ? [IndianNumberFormatter()] : [],
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Padding(padding: EdgeInsets.only(bottom: 16.0, top: 8.0), child: Text('Systematic Investment Plan Calculator', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))),
                child: Column(
                  children: [
                    Row(children: [Expanded(child: _buildField(label: 'Monthly Investment', prefix: 'PKR', suffix: '', controller: _amountController, isCurrency: true)), const SizedBox(width: 16), Expanded(child: _buildField(label: 'Annual Step-up', prefix: '', suffix: '%', controller: _stepUpController))]), const SizedBox(height: 16),
                    Row(children: [Expanded(child: _buildField(label: 'Expected Return', prefix: '', suffix: '%', controller: _rateController)), const SizedBox(width: 16), Expanded(child: _buildField(label: 'Time Period', prefix: '', suffix: 'Years', controller: _yearsController))]),
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
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(color: Colors.white70, fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500)), Text(value, style: TextStyle(color: valueColor, fontSize: isTotal ? 22 : 16, fontWeight: FontWeight.bold))]);
  }
}

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
      double balance = totalInvestment; double currentWithdrawal = initialMonthlyWithdrawal; double totalWithdrawn = 0;
      double monthlyRate = (expectedReturn / 100) / 12; int monthsLasted = 0;
      int totalMonths = (years * 12).toInt(); bool survived = true;

      for (int month = 1; month <= totalMonths; month++) {
        balance += balance * monthlyRate; balance -= currentWithdrawal; totalWithdrawn += currentWithdrawal; monthsLasted++;
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
            inputFormatters: isCurrency ? [IndianNumberFormatter()] : [],
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
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(color: Colors.white70, fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500)), Text(value, style: TextStyle(color: valueColor, fontSize: isTotal ? 22 : 16, fontWeight: FontWeight.bold))]);
  }
}

class FireCalculator extends StatefulWidget {
  const FireCalculator({super.key});
  @override
  State<FireCalculator> createState() => _FireCalculatorState();
}

class _FireCalculatorState extends State<FireCalculator> with AutomaticKeepAliveClientMixin {
  final TextEditingController _currentAgeController = TextEditingController(text: '30');
  final TextEditingController _retirementAgeController = TextEditingController(text: '60');
  final TextEditingController _lifeExpectancyController = TextEditingController(text: '85');
  final TextEditingController _initialInvController = TextEditingController(text: '5,00,000');
  final TextEditingController _monthlyInvController = TextEditingController(text: '5,000');
  final TextEditingController _stepUpController = TextEditingController(text: '10');
  final TextEditingController _preRetireReturnController = TextEditingController(text: '16');
  final TextEditingController _postRetireReturnController = TextEditingController(text: '12');
  final TextEditingController _monthlyExpController = TextEditingController(text: '50,000');
  final TextEditingController _inflationController = TextEditingController(text: '9');

  double _corpusAtRetirement = 0; double _expensesAtRetirement = 0; int _survivedMonths = 0; bool _fireAchieved = false;
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
        balance += currentMonthlyInv; balance += balance * preRate;
        if (m % 12 == 0) { currentMonthlyInv += currentMonthlyInv * (stepUp / 100); currentExpenses += currentExpenses * (inflation / 100); }
      }
      double corpusAtRetirement = balance; double expensesAtRetirement = currentExpenses;
      int survivedMonths = 0;
      for (int m = 1; m <= postRetireMonths; m++) {
        balance += balance * postRate; balance -= currentExpenses; survivedMonths++;
        if (balance <= 0) { balance = 0; break; }
        if (m % 12 == 0) currentExpenses += currentExpenses * (inflation / 100);
      }
      setState(() { _corpusAtRetirement = corpusAtRetirement; _expensesAtRetirement = expensesAtRetirement; _survivedMonths = survivedMonths; _fireAchieved = balance > 0; });
    } else {
      setState(() { _corpusAtRetirement = 0; _expensesAtRetirement = 0; _survivedMonths = 0; _fireAchieved = false; });
    }
  }

  // TIGHTENED UI FOR FIRE CALCULATOR
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
            inputFormatters: isCurrency ? [IndianNumberFormatter()] : [],
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            onChanged: (val) => _calculate(),
            decoration: InputDecoration(
              prefixText: prefix.isNotEmpty ? '$prefix ' : null, prefixStyle: const TextStyle(color: Colors.tealAccent, fontSize: 14, fontWeight: FontWeight.bold),
              suffixText: suffix.isNotEmpty ? ' $suffix' : null, suffixStyle: const TextStyle(color: Colors.white54, fontSize: 12),
              border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // Shrunk padding heavily!
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
                const Padding(padding: EdgeInsets.only(bottom: 12.0), child: Text('Financial Independence and Retire Early', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
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
                          Row(children: [Expanded(child: _buildField(label: 'Life Expectancy', prefix: '', suffix: 'Yrs', controller: _lifeExpectancyController)), const SizedBox(width: 12), Expanded(child: _buildField(label: 'Initial Invest.', prefix: 'PKR', suffix: '', controller: _initialInvController, isCurrency: true))]), const SizedBox(height: 8),
                          Row(children: [Expanded(child: _buildField(label: 'Monthly Invest.', prefix: 'PKR', suffix: '', controller: _monthlyInvController, isCurrency: true)), const SizedBox(width: 12), Expanded(child: _buildField(label: 'Annual Step-up', prefix: '', suffix: '%', controller: _stepUpController))]), const SizedBox(height: 8),
                          Row(children: [Expanded(child: _buildField(label: 'Return (Pre-Ret)', prefix: '', suffix: '%', controller: _preRetireReturnController)), const SizedBox(width: 12), Expanded(child: _buildField(label: 'Return (Post)', prefix: '', suffix: '%', controller: _postRetireReturnController))]), const SizedBox(height: 8),
                          Row(children: [Expanded(child: _buildField(label: 'Monthly Exp.', prefix: 'PKR', suffix: '', controller: _monthlyExpController, isCurrency: true)), const SizedBox(width: 12), Expanded(child: _buildField(label: 'Inflation P.A.', prefix: '', suffix: '%', controller: _inflationController))]),
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
                    _buildResultRow('1st Mth Exp (at Retire)', 'PKR ${_currencyFormat.format(_expensesAtRetirement)}', Colors.white70), const SizedBox(height: 12),
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
        Text(value, style: TextStyle(color: valueColor, fontSize: isTotal ? 18 : 14, fontWeight: FontWeight.bold)),
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