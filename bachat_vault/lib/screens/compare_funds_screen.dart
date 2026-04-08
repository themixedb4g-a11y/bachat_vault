import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bachat_vault/screens/fund_details_screen.dart';
import 'package:fl_chart/fl_chart.dart';

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

  // --- CHART ENGINE STATE ---
  bool _isChartExpanded = false;
  bool _isLoadingChart = false;
  Map<String, List<FlSpot>> _chartSpots = {};
  double _minX = 0;
  double _maxX = 0;
  double _minY = 90;
  double _maxY = 110;
  final List<Color> _chartColors = [Colors.tealAccent, Colors.orangeAccent, Colors.pinkAccent, Colors.blueAccent];

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _selectedPeriod = '1Y';
    
    // 1. USE THE SHORT CATEGORY FROM THE DASHBOARD
    final Set<String> catSet = {};
    for (var f in widget.allFunds) {
      final cat = f['short_category'] ?? f['category'];
      if (cat != null && cat.toString().isNotEmpty) catSet.add(cat.toString().trim());
    }
    _categories = catSet.toList()..sort();
    if (_categories.isNotEmpty) {
      _selectedCategory = _categories.contains('Equity') ? 'Equity' : _categories.first;
    }
  }

  // --- THE OVERLAP ELIGIBILITY ENGINE ---
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

  // --- THE OVERLAP MATH ENGINE ---
  Future<void> _loadOverlapData() async {
    if (!mounted) return;
    setState(() => _isLoadingOverlap = true);

    final validTickers = _selectedFundTickers.where((t) => t != null).toList();
    final t1 = validTickers[0]!.toString().toUpperCase().trim();
    final t2 = validTickers[1]!.toString().toUpperCase().trim();

    try {
      final supabase = Supabase.instance.client;

      final d1Res = await supabase.from('fund_holdings').select('fmr_date').eq('fund_ticker', t1).order('fmr_date', ascending: false).limit(1);
      final d2Res = await supabase.from('fund_holdings').select('fmr_date').eq('fund_ticker', t2).order('fmr_date', ascending: false).limit(1);

      String date1 = d1Res.first['fmr_date'].toString().substring(0, 10);
      String date2 = d2Res.first['fmr_date'].toString().substring(0, 10);

      final h1Res = await supabase.from('fund_holdings').select('stock_ticker, holding_percentage').eq('fund_ticker', t1).eq('fmr_date', date1);
      final h2Res = await supabase.from('fund_holdings').select('stock_ticker, holding_percentage').eq('fund_ticker', t2).eq('fmr_date', date2);

      Map<String, double> fund1Map = {};
      for (var h in h1Res) {
        fund1Map[h['stock_ticker'].toString().trim()] = double.tryParse(h['holding_percentage'].toString()) ?? 0.0;
      }

      double totalOverlap = 0.0;
      List<Map<String, dynamic>> sharedDetails = [];
      List<String> sharedTickers = [];

      for (var h in h2Res) {
        String ticker = h['stock_ticker'].toString().trim();
        if (ticker == 'CASH' || ticker == 'OTHER') continue;

        double p2 = double.tryParse(h['holding_percentage'].toString()) ?? 0.0;
        
        if (fund1Map.containsKey(ticker)) {
          double p1 = fund1Map[ticker]!;
          double intersection = math.min(p1, p2); 
          
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

  // --- THE MULTI-FUND CHART ENGINE ---
  Future<void> _loadComparisonChartData() async {
    final validTickers = _selectedFundTickers.where((t) => t != null).cast<String>().toList();
    if (validTickers.isEmpty) return;
    if (!mounted) return;
    setState(() => _isLoadingChart = true);

    try {
      final supabase = Supabase.instance.client;
      DateTime startDate = DateTime.now();
      
      switch (_selectedPeriod) {
        case '30D': startDate = DateTime.now().subtract(const Duration(days: 30)); break;
        case '1Y': startDate = DateTime.now().subtract(const Duration(days: 365)); break;
        case '3Y': startDate = DateTime.now().subtract(const Duration(days: 1095)); break;
        case '5Y': startDate = DateTime.now().subtract(const Duration(days: 1825)); break;
        case '10Y': startDate = DateTime.now().subtract(const Duration(days: 3650)); break;
        case '15Y': startDate = DateTime.now().subtract(const Duration(days: 5475)); break;
        case 'MAX': startDate = DateTime(2000, 1, 1); break;
        default: startDate = DateTime.now().subtract(const Duration(days: 365));
      }
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);

      List<List<dynamic>> allFundData = [];
      List<List<dynamic>> allPayoutData = [];

      List<Future> futures = [];
      for (String ticker in validTickers) {
        futures.add(supabase.from('daily_nav').select('validity_date, nav').eq('ticker', ticker).gte('validity_date', startDateStr).order('validity_date', ascending: true));
        futures.add(supabase.from('payout_history').select('payout_date, payout_amount, ex_nav').eq('ticker', ticker).gte('payout_date', startDateStr));
      }
      final responses = await Future.wait(futures);

      for (int i = 0; i < validTickers.length; i++) {
        allFundData.add(List.from(responses[i * 2] as List<dynamic>));
        allPayoutData.add(List.from(responses[(i * 2) + 1] as List<dynamic>));
      }

      List<DateTime> startDates = [];
      for (var data in allFundData) {
        if (data.isNotEmpty) startDates.add(DateTime.parse(data.first['validity_date'].toString()));
      }
      if (startDates.isNotEmpty) {
        DateTime commonStartDate = startDates.reduce((a, b) => a.isAfter(b) ? a : b);
        for (int i = 0; i < allFundData.length; i++) {
          allFundData[i].removeWhere((row) => DateTime.parse(row['validity_date'].toString()).isBefore(commonStartDate));
          allPayoutData[i].removeWhere((row) => DateTime.parse(row['payout_date'].toString()).isBefore(commonStartDate));
        }
      }

      Map<String, List<FlSpot>> newSpots = {};
      double localMinX = 9999999999999;
      double localMaxX = 0;
      double localMinY = 999999;
      double localMaxY = -999999;

      for (int i = 0; i < validTickers.length; i++) {
        String ticker = validTickers[i];
        List<dynamic> fundData = allFundData[i];
        List<dynamic> payoutData = allPayoutData[i];
        List<FlSpot> spots = [];
        
        if (fundData.isEmpty) continue;

        double startNav = 1.0;
        for (var row in fundData) {
          double val = double.tryParse(row['nav'].toString()) ?? 0.0;
          if (val > 0) { startNav = val; break; }
        }

        double currentUnits = 100.0 / startNav;

        for (var row in fundData) {
          String dateStr = row['validity_date'].toString();
          DateTime date = DateTime.parse(dateStr);
          double nav = double.tryParse(row['nav'].toString()) ?? 0.0;
          if (nav <= 0) continue;

          var dailyPayouts = payoutData.where((p) => p['payout_date'].toString().startsWith(dateStr));
          for (var p in dailyPayouts) {
            double pAmt = double.tryParse(p['payout_amount'].toString()) ?? 0.0;
            double exNav = double.tryParse(p['ex_nav'].toString()) ?? 0.0;
            if (exNav > 0) currentUnits = currentUnits * (1 + (pAmt / exNav));
          }

          double base100Value = currentUnits * nav;
          double xValue = date.millisecondsSinceEpoch.toDouble();
          
          spots.add(FlSpot(xValue, base100Value));
          
          if (xValue < localMinX) localMinX = xValue;
          if (xValue > localMaxX) localMaxX = xValue;
          if (base100Value < localMinY) localMinY = base100Value;
          if (base100Value > localMaxY) localMaxY = base100Value;
        }
        newSpots[ticker] = spots;
      }

      if (mounted) {
        setState(() {
          _chartSpots = newSpots;
          _minX = localMinX;
          _maxX = localMaxX;
          _minY = localMinY * 0.95;
          _maxY = localMaxY * 1.05;
          _isLoadingChart = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingChart = false);
    }
  }

  Widget _buildOverlapAnalyzer() {
    if (!_showOverlapButton) return const SizedBox.shrink();

    if (!_isOverlapExpanded) {
      return Center(
        child: OutlinedButton.icon(
          icon: const Icon(Icons.pie_chart_outline, color: Colors.purpleAccent, size: 25),
          label: const Text('✨ Overlap Analyzer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            side: BorderSide(color: Colors.purpleAccent.withOpacity(0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            backgroundColor: Colors.purpleAccent.withOpacity(0.05)
          ),
          onPressed: () {
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
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.purpleAccent.withOpacity(0.3))),
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
            const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: Colors.purpleAccent)))
          else if (_overlappingStocks.isEmpty)
            const SizedBox(height: 100, child: Center(child: Text('These funds are perfectly diversified.\nThey share 0 assets.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))))
          else ...[
            Center(
              child: Column(
                children: [
                  Text('${_totalOverlapPercentage.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.purpleAccent, fontSize: 48, fontWeight: FontWeight.w800, height: 1.0)),
                  const SizedBox(height: 4),
                  const Text('Total Shared Assets', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Top Shared Holdings:', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
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
                              child: Container(decoration: BoxDecoration(color: Colors.purpleAccent.withOpacity(0.8), borderRadius: BorderRadius.circular(3))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('${currentOverlap.toStringAsFixed(1)}% overlap', style: const TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold)),
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

  Widget _buildComparisonChart() {
    final validTickers = _selectedFundTickers.where((t) => t != null).cast<String>().toList();
    if (validTickers.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.tealAccent.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('✨ Growth Comparison', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                onPressed: () => setState(() => _isChartExpanded = false),
              )
            ],
          ),
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 12, runSpacing: 8,
            children: validTickers.asMap().entries.map((entry) {
              int idx = entry.key;
              String ticker = entry.value;
              final fundData = widget.allFunds.firstWhere((f) => f['ticker'] == ticker, orElse: () => {});
              
              // 2. USE DASHBOARD'S SHORT NAME
              String name = fundData['short_name']?.toString() ?? fundData['fund_name']?.toString() ?? ticker;
              
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: _chartColors[idx % _chartColors.length], shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(name, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 250,
            child: _isLoadingChart 
              ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
              : _chartSpots.isEmpty 
                ? const Center(child: Text('No data available for this period.', style: TextStyle(color: Colors.white54)))
                : LineChart(
                    LineChartData(
                      minX: _minX, maxX: _maxX, minY: _minY, maxY: _maxY,
                      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1)),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(color: Colors.white38, fontSize: 10))),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true, reservedSize: 30, 
                            interval: (_maxX - _minX) > 0 ? (_maxX - _minX) / 3 : 86400000.0 * 30,
                            getTitlesWidget: (value, meta) {
                              DateTime date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                              return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(DateFormat('MMM yy').format(date), style: const TextStyle(color: Colors.white38, fontSize: 10)));
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              DateTime date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                              String ticker = validTickers[spot.barIndex];
                              final fundData = widget.allFunds.firstWhere((f) => f['ticker'] == ticker, orElse: () => {});
                              
                              // 3. USE DASHBOARD'S SHORT NAME
                              String name = fundData['short_name']?.toString() ?? fundData['fund_name']?.toString() ?? ticker;
                              
                              return LineTooltipItem('${DateFormat('dd MMM yyyy').format(date)}\n$name\n${spot.y.toStringAsFixed(1)}', TextStyle(color: _chartColors[spot.barIndex % _chartColors.length], fontSize: 10, fontWeight: FontWeight.bold));
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: validTickers.asMap().entries.map((entry) {
                        int idx = entry.key;
                        String ticker = entry.value;
                        return LineChartBarData(
                          spots: _chartSpots[ticker] ?? [],
                          isCurved: true,
                          color: _chartColors[idx % _chartColors.length],
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // 4. FILTER BY SHORT CATEGORY
  List<Map<String, dynamic>> _getFundsInCategory() {
    if (_selectedCategory == null) return [];
    return widget.allFunds.where((f) => (f['short_category'] ?? f['category'])?.toString().trim() == _selectedCategory).toList();
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
      onTap: () {
        setState(() => _selectedPeriod = label);
        if (_isChartExpanded) _loadComparisonChartData();
      },
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
    // 5. USE DASHBOARD'S SHORT NAME
    final fundName = fund['short_name']?.toString() ?? fund['fund_name']?.toString() ?? 'Unknown Fund';
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
                            _checkOverlapEligibility();
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
                                
                                // 6. USE DASHBOARD'S SHORT NAME IN DROPDOWN
                                items: availableFunds.map((f) => DropdownMenuItem(
                                  value: f['ticker'] as String, 
                                  child: Text((f['short_name'] ?? f['fund_name']).toString(), overflow: TextOverflow.ellipsis)
                                )).toList(),
                                
                                onChanged: (val) { 
                                  setState(() { _selectedFundTickers[index] = val; }); 
                                  _checkOverlapEligibility();
                                },
                              ),
                            ),
                          ),
                          if (index >= 2) 
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                              onPressed: () { 
                                setState(() { _selectedFundTickers.removeAt(index); }); 
                                _checkOverlapEligibility();
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
                          _checkOverlapEligibility();
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
                      children: ['30D', '1Y', '3Y', '5Y', '10Y', '15Y', 'MAX'].map((p) => _buildPeriodFilterBtn(p)).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildOverlapAnalyzer(),
                  const SizedBox(height: 8),

                  if (!_isChartExpanded && _selectedFundTickers.where((t) => t != null).isNotEmpty)
                    Center(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.show_chart, color: Colors.tealAccent, size: 25),
                        label: const Text('✨ Compare Performance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          side: BorderSide(color: Colors.tealAccent.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          backgroundColor: Colors.tealAccent.withOpacity(0.05)
                        ),
                        onPressed: () {
                          setState(() => _isChartExpanded = true);
                          _loadComparisonChartData();
                        },
                      ),
                    ),

                  if (_isChartExpanded)
                    _buildComparisonChart(),

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