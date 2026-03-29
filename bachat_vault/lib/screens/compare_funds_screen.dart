import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bachat_vault/screens/fund_details_screen.dart';

class CompareFundsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allFunds;
  final double investmentAmount;
  final Map<String, dynamic> benchmarkStats;
  final String initialPeriod;

  const CompareFundsScreen({super.key, required this.allFunds, required this.investmentAmount, required this.benchmarkStats, required this.initialPeriod});

  @override
  State<CompareFundsScreen> createState() => _CompareFundsScreenState();
}

class _CompareFundsScreenState extends State<CompareFundsScreen> {
  late List<String> _categories;
  String? _selectedCategory;
  List<String?> _selectedFundTickers = [null, null]; 
  late String _selectedPeriod;

  // --- OVERLAP ENGINE STATE ---
  bool _showOverlapButton = false;
  bool _isOverlapExpanded = false;
  bool _isLoadingOverlap = false;
  double _totalOverlapPercentage = 0.0;
  List<Map<String, dynamic>> _overlappingStocks = [];

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0);

  String _cleanFundName(String name) {
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
        .replaceAll('Faysal Khushal Mustaqbil Fund (Faysal Nuumah Women Savers Plan)', 'Faysal Nuumah Women Savers Plan')
        .replaceAll('Faysal Islamic Financial Planning Fund II (Faysal Priority Ascend Plan I)', 'Faysal Priority Ascend Plan I')
        .replaceAll('Faysal Islamic Financial Planning Fund II (Faysal Priority Ascend Plan II)', 'Faysal Priority Ascend Plan II')
        .replaceAll('Faysal Islamic Financial Planning Fund II (Faysal Priority Ascend Plan III)', 'Faysal Priority Ascend Plan III')
        .replaceAll('Faysal Khushal Mustaqbil Fund (Faysal Barakah Women Savers Plan)', 'Faysal Barakaah Women Savers Plan')
        .replaceAll('Faysal Islamic Asset Allocation Fund III (Faysal Shariah Flex Plan I)', 'Faysal Shariah Flex Plan I')
        .replaceAll('Faysal Islamic Asset Allocation Fund III (Faysal Shariah Flex Plan II)', 'Faysal Shariah Flex Plan II')
        .replaceAll('Faysal Islamic Asset Allocation Fund III (Faysal Shariah Flex Plan III)', 'Faysal Shariah Flex Plan III')
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

  @override
  void initState() {
    super.initState();
    _selectedPeriod = '1Y';
    
    final Set<String> catSet = {};
    for (var f in widget.allFunds) {
      final cat = f['category'];
      if (cat != null && cat.toString().isNotEmpty) catSet.add(cat.toString().trim());
    }
    _categories = catSet.toList()..sort();
    if (_categories.isNotEmpty) {
      _selectedCategory = _categories.contains('Equity') ? 'Equity' : _categories.first;
    }
  }

  // --- THE OVERLAP ELIGIBILITY ENGINE ---
  // Silently checks if we have exactly 2 funds, and if both exist in the DB
  Future<void> _checkOverlapEligibility() async {
    final validTickers = _selectedFundTickers.where((t) => t != null).toList();
    
    if (validTickers.length != 2) {
      if (mounted) setState(() { _showOverlapButton = false; _isOverlapExpanded = false; });
      return;
    }

    final t1 = validTickers[0]!.toString().toUpperCase().trim();
    final t2 = validTickers[1]!.toString().toUpperCase().trim();

    try {
      final supabase = Supabase.instance.client;
      // Fast check: Do we have at least 1 holding row for both tickers?
      final res1 = await supabase.from('fund_holdings').select('fund_ticker').eq('fund_ticker', t1).limit(1);
      final res2 = await supabase.from('fund_holdings').select('fund_ticker').eq('fund_ticker', t2).limit(1);

      if (res1.isNotEmpty && res2.isNotEmpty) {
        if (mounted) setState(() => _showOverlapButton = true);
      } else {
        if (mounted) setState(() { _showOverlapButton = false; _isOverlapExpanded = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _showOverlapButton = false; _isOverlapExpanded = false; });
    }
  }

  // --- THE OVERLAP MATH ENGINE (EQUITIES ONLY) ---
  Future<void> _loadOverlapData() async {
    if (!mounted) return;
    setState(() => _isLoadingOverlap = true);

    final validTickers = _selectedFundTickers.where((t) => t != null).toList();
    final t1 = validTickers[0]!.toString().toUpperCase().trim();
    final t2 = validTickers[1]!.toString().toUpperCase().trim();

    try {
      final supabase = Supabase.instance.client;

      // 1. Get the latest reporting dates for both funds
      final d1Res = await supabase.from('fund_holdings').select('fmr_date').eq('fund_ticker', t1).order('fmr_date', ascending: false).limit(1);
      final d2Res = await supabase.from('fund_holdings').select('fmr_date').eq('fund_ticker', t2).order('fmr_date', ascending: false).limit(1);

      String date1 = d1Res.first['fmr_date'].toString().substring(0, 10);
      String date2 = d2Res.first['fmr_date'].toString().substring(0, 10);

      // 2. Pull all holdings for those specific dates
      final h1Res = await supabase.from('fund_holdings').select('stock_ticker, holding_percentage').eq('fund_ticker', t1).eq('fmr_date', date1);
      final h2Res = await supabase.from('fund_holdings').select('stock_ticker, holding_percentage').eq('fund_ticker', t2).eq('fmr_date', date2);

      // 3. Map Fund 1 for ultra-fast lookup
      Map<String, double> fund1Map = {};
      for (var h in h1Res) {
        fund1Map[h['stock_ticker'].toString().trim()] = double.tryParse(h['holding_percentage'].toString()) ?? 0.0;
      }

      // 4. The Math: Find the Minimum Intersection (Ignoring Cash/Others)
      double totalOverlap = 0.0;
      List<Map<String, dynamic>> sharedDetails = [];
      List<String> sharedTickers = [];

      for (var h in h2Res) {
        String ticker = h['stock_ticker'].toString().trim();
        
        // --- THE FIX: Skip non-equity buckets entirely ---
        if (ticker == 'CASH' || ticker == 'OTHER') continue;

        double p2 = double.tryParse(h['holding_percentage'].toString()) ?? 0.0;
        
        if (fund1Map.containsKey(ticker)) {
          double p1 = fund1Map[ticker]!;
          double intersection = math.min(p1, p2); // E.g. Fund A: 10%, Fund B: 7% -> Overlap: 7%
          
          if (intersection > 0) {
            totalOverlap += intersection;
            sharedTickers.add(ticker);
            sharedDetails.add({
              'ticker': ticker,
              'overlap': intersection,
              'p1': p1,
              'p2': p2
            });
          }
        }
      }

      // 5. Fetch beautiful company names
      if (sharedTickers.isNotEmpty) {
        final stocksResponse = await supabase.from('master_stocks').select('ticker, company_name').inFilter('ticker', sharedTickers);
        for (var detail in sharedDetails) {
          var meta = (stocksResponse as List).firstWhere(
            (s) => s['ticker'].toString().trim() == detail['ticker'], 
            orElse: () => {'company_name': detail['ticker']}
          );
          detail['name'] = meta['company_name'].toString();
        }
      }

      // Sort by highest overlap first
      sharedDetails.sort((a, b) => (b['overlap'] as double).compareTo(a['overlap'] as double));

      if (mounted) {
        setState(() {
          _totalOverlapPercentage = totalOverlap;
          _overlappingStocks = sharedDetails;
          _isLoadingOverlap = false;
        });
      }

    } catch (e) {
      debugPrint("Overlap Match Error: $e");
      if (mounted) setState(() => _isLoadingOverlap = false);
    }
  }

  // --- OVERLAP UI WIDGET (TEAL THEME) ---
  Widget _buildOverlapAnalyzer() {
    if (!_showOverlapButton) return const SizedBox.shrink();

    if (!_isOverlapExpanded) {
      return Center(
        child: OutlinedButton.icon(
          // Changed to tealAccent
          icon: const Icon(Icons.pie_chart_outline, color: Colors.tealAccent, size: 20),
          label: const Text('✨ Overlap Analyzer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            // Changed to tealAccent
            side: BorderSide(color: Colors.tealAccent.withOpacity(0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            // Changed to tealAccent
            backgroundColor: Colors.tealAccent.withOpacity(0.05)
          ),
          onPressed: () {
            // Future Paywall Hook goes here!
            setState(() { _isOverlapExpanded = true; });
            _loadOverlapData();
          },
        ),
      );
    }

    double maxOverlap = _overlappingStocks.isNotEmpty ? (_overlappingStocks.first['overlap'] as double) : 100.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      // Changed to tealAccent
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.tealAccent.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('✨ Portfolio Overlap', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                onPressed: () => setState(() => _isOverlapExpanded = false),
              )
            ],
          ),
          const SizedBox(height: 16),
          
          if (_isLoadingOverlap)
            // Changed to tealAccent
            const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: Colors.tealAccent)))
          else if (_overlappingStocks.isEmpty)
            const SizedBox(height: 100, child: Center(child: Text('These funds are perfectly diversified.\nThey share 0 assets.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))))
          else ...[
            // Total Overlap Header
            Center(
              child: Column(
                children: [
                  // Changed to tealAccent
                  Text('${_totalOverlapPercentage.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.tealAccent, fontSize: 48, fontWeight: FontWeight.w800, height: 1.0)),
                  const SizedBox(height: 4),
                  const Text('Total Shared Assets', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Top Shared Holdings:', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            // Shared Holdings Breakdown
            ..._overlappingStocks.take(5).map((stock) {
              double currentOverlap = stock['overlap'] as double;
              double barWidthFactor = maxOverlap > 0 ? (currentOverlap / maxOverlap) : 0.0;
              if (barWidthFactor > 1.0) barWidthFactor = 1.0; 

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stock['name'].toString(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 6, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(3)),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft, 
                              widthFactor: barWidthFactor, 
                              // Changed to tealAccent
                              child: Container(decoration: BoxDecoration(color: Colors.tealAccent.withOpacity(0.8), borderRadius: BorderRadius.circular(3))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Changed to tealAccent
                        Text('${currentOverlap.toStringAsFixed(1)}% overlap', style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    )
                  ],
                ),
              );
            }),
          ]
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFundsInCategory() {
    if (_selectedCategory == null) return [];
    return widget.allFunds.where((f) => f['category']?.toString().trim() == _selectedCategory).toList();
  }

  String _getSortKey(String period) {
    switch (period) {
      case '1D': return 'return_1d'; case '30D': return 'return_30d'; case '1Y': return 'return_1y';
      case '3Y': return 'return_3y'; case '5Y': return 'return_5y'; case '10Y': return 'return_10y';
      case '15Y': return 'return_15y'; case '20Y': return 'return_20y'; case 'MTD': return 'return_30d'; 
      case 'YTD': return 'return_1y'; case '25Y': return 'return_20y'; default: return 'return_1y';
    }
  }

  Widget _buildPeriodFilterBtn(String label) {
    final isSelected = _selectedPeriod == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? Colors.tealAccent.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected ? Colors.tealAccent : Colors.white.withOpacity(0.2), width: 1)),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.tealAccent : Colors.white70, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500, fontSize: 11)),
      ),
    );
  }

  Widget _buildMiniReturnPill(String label, String dbKey, Map<String, dynamic> fund) {
    final rawValue = fund[dbKey];
    if (rawValue == null) return const SizedBox.shrink();

    final percent = ((rawValue as num).toDouble() - 1.0) * 100.0;
    Color statColor = percent > 0 ? Colors.greenAccent : percent < 0 ? Colors.redAccent.shade100 : Colors.white70;
    String sign = percent > 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
          Text('$sign${percent.toStringAsFixed(2)}%', style: TextStyle(color: statColor, fontSize: 10, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(Map<String, dynamic> fund) {
    final fundName = _cleanFundName(fund['fund_name'] ?? 'Unknown Fund');
    final amcName = fund['amc_name'] ?? '';
    final isShariah = (fund['is_shariah'] == 1 || fund['is_shariah'] == '1' || fund['is_shariah'] == true);
    
    final sortKey = _getSortKey(_selectedPeriod);
    final rawValue = fund[sortKey];
    
    double profitValue = 0.0;
    double percent = 0.0;
    if (rawValue != null) {
      final returnFactor = (rawValue as num).toDouble();
      percent = (returnFactor - 1.0) * 100.0;
      profitValue = widget.investmentAmount * (returnFactor - 1.0);
    }

    String profitString = _currencyFormat.format(profitValue.abs());
    String formattedValueDisplay = rawValue == null ? 'N/A' : profitValue > 0 ? '+PKR $profitString' : profitValue < 0 ? '-PKR $profitString' : 'PKR 0';
    String percentageString = rawValue == null ? '' : '(${percent > 0 ? '+' : ''}${percent.toStringAsFixed(2)}%)';
    Color statColor = rawValue == null ? Colors.white54 : percent > 0 ? Colors.greenAccent : percent < 0 ? Colors.redAccent.shade100 : Colors.white70;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FundDetailsScreen(
                fund: fund,
                investmentAmount: widget.investmentAmount,
                benchmarkStats: widget.benchmarkStats,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05), 
            borderRadius: BorderRadius.circular(16), 
            border: Border.all(color: Colors.white.withOpacity(0.15))
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(amcName.toString().toUpperCase(), style: const TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text('$fundName${isShariah ? " 🕌" : ""}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 12),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$_selectedPeriod Growth:', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      Text(formattedValueDisplay, style: TextStyle(color: statColor, fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 6),
                      Text(percentageString, style: TextStyle(color: statColor.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  )
                ],
              ),
              
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white12, height: 1)),
              
              const Center(
                child: Text('Historical Returns:', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.center, 
                  spacing: 8, runSpacing: 8,
                  children: [
                    _buildMiniReturnPill('30D', 'return_30d', fund),
                    _buildMiniReturnPill('1Y', 'return_1y', fund),
                    _buildMiniReturnPill('3Y', 'return_3y', fund),
                    _buildMiniReturnPill('5Y', 'return_5y', fund),
                    _buildMiniReturnPill('10Y', 'return_10y', fund),
                    _buildMiniReturnPill('15Y', 'return_15y', fund),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableFunds = _getFundsInCategory();

    return Theme(
      data: Theme.of(context).copyWith(textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Compare Funds', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
          backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.white),
          flexibleSpace: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.black.withOpacity(0.2)))),
        ),
        body: Container(
          width: double.infinity, height: double.infinity,
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF000000)])),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Category', style: TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    height: 48, padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory, isExpanded: true, dropdownColor: const Color(0xFF203A43), menuMaxHeight: 350, icon: const Icon(Icons.arrow_drop_down, color: Colors.tealAccent),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCategory = val;
                              _selectedFundTickers = [null, null];
                            });
                            _checkOverlapEligibility(); // Trigger Check
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text('Select Funds to Compare', style: TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...List.generate(_selectedFundTickers.length, (index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      height: 52, padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
                      child: Row(
                        children: [
                          Text('Fund ${index + 1}: ', style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedFundTickers[index], isExpanded: true, dropdownColor: const Color(0xFF203A43), menuMaxHeight: 350, icon: const Icon(Icons.arrow_drop_down, color: Colors.tealAccent),
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                hint: const Text('Choose a fund...', style: TextStyle(color: Colors.white38)),
                                items: availableFunds.map((f) => DropdownMenuItem(value: f['ticker'] as String, child: Text(_cleanFundName(f['fund_name'] as String), overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (val) { 
                                  setState(() { _selectedFundTickers[index] = val; }); 
                                  _checkOverlapEligibility(); // Trigger Check
                                },
                              ),
                            ),
                          ),
                          if (index >= 2) 
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                              onPressed: () { 
                                setState(() { _selectedFundTickers.removeAt(index); }); 
                                _checkOverlapEligibility(); // Trigger Check
                              },
                            )
                        ],
                      ),
                    );
                  }),

                  if (_selectedFundTickers.length < 4)
                    Center(
                      child: TextButton.icon(
                        onPressed: () { 
                          setState(() { _selectedFundTickers.add(null); }); 
                          _checkOverlapEligibility(); // Trigger Check
                        },
                        icon: const Icon(Icons.add_circle_outline, color: Colors.tealAccent),
                        label: const Text('Add Another Fund', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  
                  const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white24, height: 1)),

                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.center, 
                      spacing: 8, 
                      runSpacing: 12, 
                      children: ['30D', '1Y', '3Y', '5Y', '10Y', '15Y'].map((p) => _buildPeriodFilterBtn(p)).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- THE NEW OVERLAP ANALYZER WIDGET ---
                  _buildOverlapAnalyzer(),
                  const SizedBox(height: 16),

                  ..._selectedFundTickers.map((ticker) {
                    if (ticker == null) return const SizedBox.shrink();
                    final fundData = widget.allFunds.firstWhere((f) => f['ticker'] == ticker, orElse: () => {});
                    if (fundData.isEmpty) return const SizedBox.shrink();
                    
                    return _buildComparisonCard(fundData);
                  }),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}