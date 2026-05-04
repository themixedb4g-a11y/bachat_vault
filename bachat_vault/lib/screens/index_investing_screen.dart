import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 

class IndexInvestingScreen extends StatefulWidget {
  const IndexInvestingScreen({super.key});

  @override
  State<IndexInvestingScreen> createState() => _IndexInvestingScreenState();
}

class _IndexInvestingScreenState extends State<IndexInvestingScreen> {
  final TextEditingController _amountController = TextEditingController(text: '1,00,000');

  bool _isLoading = true;
  String _selectedIndex = 'KSE100';
  int _topN = 10; 
  double _investmentAmount = 100000.0;

  List<Map<String, dynamic>> _allIndexStocks = [];
  List<Map<String, dynamic>> _allocations = [];
  
  double _displayTotalWeightCaptured = 0.0;
  double _actualMathematicalWeight = 0.0;
  
  double _totalActualCost = 0.0;
  double _minimumRequiredInvestment = 0.0;

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0);

  @override
  void initState() { 
    super.initState(); 
    _fetchIndexData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchIndexData() async {
    setState(() => _isLoading = true);
    final SupabaseClient supabase = Supabase.instance.client;
    
    try {
      final response = await supabase
          .from('live_stock_prices')
          .select('ticker, current_price, kse100_weight, kmi30_weight, psxdiv20_weight');

      if (mounted) {
        setState(() {
          _allIndexStocks = List<Map<String, dynamic>>.from(response);
        });
        _calculateAllocations();
      }
    } catch (e) {
      debugPrint("Index Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculateAllocations() {
    _investmentAmount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    
    if (_investmentAmount <= 0 || _allIndexStocks.isEmpty) {
      setState(() {
        _allocations = [];
        _displayTotalWeightCaptured = 0.0;
        _totalActualCost = 0.0;
        _minimumRequiredInvestment = 0.0;
        _isLoading = false;
      });
      return;
    }

    String weightCol = _selectedIndex == 'KSE100' ? 'kse100_weight' : 
                       _selectedIndex == 'KMI30' ? 'kmi30_weight' : 'psxdiv20_weight';

    List<Map<String, dynamic>> validStocks = _allIndexStocks.where((s) {
      double w = (s[weightCol] as num?)?.toDouble() ?? 0.0;
      return w > 0.0;
    }).toList();

    validStocks.sort((a, b) {
      double wA = (a[weightCol] as num?)?.toDouble() ?? 0.0;
      double wB = (b[weightCol] as num?)?.toDouble() ?? 0.0;
      return wB.compareTo(wA);
    });

    List<Map<String, dynamic>> topStocks = _topN == 999 ? validStocks : validStocks.take(_topN).toList();

    _actualMathematicalWeight = topStocks.fold(0.0, (sum, item) {
      return sum + ((item[weightCol] as num?)?.toDouble() ?? 0.0);
    });

    _displayTotalWeightCaptured = math.min(100.0, _actualMathematicalWeight);

    _allocations.clear();
    double totalCostTracker = 0.0;
    double maxRequiredCash = 0.0;

    for (var stock in topStocks) {
      double originalWeight = (stock[weightCol] as num?)?.toDouble() ?? 0.0;
      double currentPrice = (stock['current_price'] as num?)?.toDouble() ?? 0.0;
      
      if (_actualMathematicalWeight == 0 || currentPrice == 0) continue;

      double normalizedWeight = originalWeight / _actualMathematicalWeight;
      double allocatedCash = _investmentAmount * normalizedWeight;
      
      int sharesToBuy = (allocatedCash / currentPrice).floor();
      double actualCost = sharesToBuy * currentPrice;
      totalCostTracker += actualCost;

      double requiredForOneShare = currentPrice / normalizedWeight;
      if (requiredForOneShare > maxRequiredCash) {
        maxRequiredCash = requiredForOneShare;
      }

      _allocations.add({
        'ticker': stock['ticker'],
        'original_weight': originalWeight,
        'normalized_weight': normalizedWeight * 100, 
        'allocated_cash': allocatedCash, 
        'actual_cost': actualCost,       
        'shares': sharesToBuy,
        'price': currentPrice,
      });
    }

    setState(() {
      _totalActualCost = totalCostTracker;
      _minimumRequiredInvestment = maxRequiredCash;
      _isLoading = false;
    });
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
            onChanged: (val) => _calculateAllocations(),
            decoration: InputDecoration(prefixText: prefix.isNotEmpty ? '$prefix ' : null, prefixStyle: const TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold), suffixText: suffix.isNotEmpty ? ' $suffix' : null, suffixStyle: const TextStyle(color: Colors.white54, fontSize: 14), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({required String label, required T value, required List<DropdownMenuItem<T>> items, required void Function(T?) onChanged}) {
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
            child: DropdownButton<T>(
              isExpanded: true,
              dropdownColor: const Color(0xFF203A43),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.amberAccent),
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
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
    String countText = _topN == 999 ? 'All valid' : 'The Top $_topN';
    bool budgetTooLow = _investmentAmount < _minimumRequiredInvestment;
    double unallocatedCash = _investmentAmount - _totalActualCost;

    return Theme(
      data: Theme.of(context).copyWith(textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🚨 NEW ICON: Pie Chart!
              Icon(Icons.pie_chart_rounded, color: Colors.amberAccent, size: 20),
              SizedBox(width: 8),
              Text('DIY Index Portfolio', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
          centerTitle: true, backgroundColor: Colors.transparent, elevation: 0,
          leading: const BackButton(color: Colors.white),
          flexibleSpace: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.black.withOpacity(0.2)))),
        ),
        body: Container(
          width: double.infinity, height: double.infinity,
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF000000)])),
          child: SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amberAccent.withOpacity(0.2))),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildField(label: 'Investment Value', prefix: 'PKR', suffix: '', controller: _amountController, isCurrency: true),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 6,
                                        child: _buildDropdown<String>(
                                          label: 'Select Index',
                                          value: _selectedIndex,
                                          items: const [
                                            DropdownMenuItem(value: 'KSE100', child: Text('KSE-100')),
                                            DropdownMenuItem(value: 'KMI30', child: Text('KMI-30')),
                                            DropdownMenuItem(value: 'PSXDIV20', child: Text('PSX DIV 20')),
                                          ],
                                          onChanged: (val) { if (val != null) { setState(() => _selectedIndex = val); _calculateAllocations(); } },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 4,
                                        child: _buildDropdown<int>(
                                          label: 'Holdings',
                                          value: _topN,
                                          // 🚨 "Top 30" Removed!
                                          items: const [
                                            DropdownMenuItem(value: 5, child: Text('Top 5')),
                                            DropdownMenuItem(value: 10, child: Text('Top 10')),
                                            DropdownMenuItem(value: 15, child: Text('Top 15')),
                                            DropdownMenuItem(value: 20, child: Text('Top 20')),
                                            DropdownMenuItem(value: 999, child: Text('All')),
                                          ],
                                          onChanged: (val) { if (val != null) { setState(() => _topN = val); _calculateAllocations(); } },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  if (budgetTooLow)
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withOpacity(0.3))),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Budget too low. To accurately buy at least 1 share of every selected stock, you need a minimum of PKR ${_currencyFormat.format(_minimumRequiredInvestment)}.',
                                              style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600, height: 1.3),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amberAccent.withOpacity(0.3))),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline, color: Colors.amberAccent, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '$countText stocks represent ${_displayTotalWeightCaptured.toStringAsFixed(2)}% of the actual $_selectedIndex index weight. Your cash is dynamically normalized to 100% across these assets.',
                                            style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.w600, height: 1.3),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Suggested Portfolio', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('${_allocations.length} Stocks', style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.tealAccent.withOpacity(0.2))),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Actual Market Cost:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                                  Text('PKR ${_currencyFormat.format(_totalActualCost)}', style: const TextStyle(color: Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Unallocated Cash:', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
                                  Text('PKR ${_currencyFormat.format(math.max(0.0, unallocatedCash))}', style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                if (_isLoading)
                  const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Colors.amberAccent))))
                else if (_allocations.isEmpty)
                  const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No data available. Check investment amount.", style: TextStyle(color: Colors.white54)))))
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final stock = _allocations[index];
                          final int shares = stock['shares'];
                          final bool isZero = shares == 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isZero ? Colors.redAccent.withOpacity(0.05) : Colors.white.withOpacity(0.03), 
                              borderRadius: BorderRadius.circular(16), 
                              border: Border.all(color: isZero ? Colors.redAccent.withOpacity(0.2) : Colors.white.withOpacity(0.08))
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(stock['ticker'].toString(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 4),
                                      // 🚨 UI CLEANUP: Single weight line instead of two confusing percentages!
                                      Text('Allocated Weight: ${(stock['normalized_weight'] as double).toStringAsFixed(2)}%', style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('$shares Shares', style: TextStyle(color: isZero ? Colors.redAccent : Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text('Cost: PKR ${_currencyFormat.format(stock['actual_cost'])}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                      Text('@ PKR ${stock['price']}/sh', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: _allocations.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ),
      ),
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