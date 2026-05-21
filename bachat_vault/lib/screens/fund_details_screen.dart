import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:auto_size_text/auto_size_text.dart';

class FundDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> fund;
  final double investmentAmount;
  final Map<String, dynamic> benchmarkStats;

  const FundDetailsScreen({
    super.key,
    required this.fund,
    required this.investmentAmount,
    required this.benchmarkStats,
  });

  @override
  State<FundDetailsScreen> createState() => _FundDetailsScreenState();
}

class _FundDetailsScreenState extends State<FundDetailsScreen> {
  // Chart State
  bool _isChartExpanded = false;
  bool _isLoadingChart = false;
  String _chartPeriod = '1Y';
  bool _showKse100 = false;
  bool _showGold = false;
  
  // Holdings State
  bool _isLoadingHoldings = true;
  String _holdingsDate = '';
  List<Map<String, dynamic>> _sectorAllocations = [];
  List<Map<String, dynamic>> _topHoldings = [];
  final List<Color> _sectorColors = [
    Colors.tealAccent, Colors.blueAccent, Colors.purpleAccent, 
    Colors.orangeAccent, Colors.pinkAccent, Colors.yellowAccent, 
    Colors.cyanAccent, Colors.lightGreenAccent, Colors.redAccent, Colors.indigoAccent
  ];

  List<FlSpot> _fundSpots = [];
  List<FlSpot> _kseSpots = [];
  List<FlSpot> _goldSpots = [];

  double _minX = 0;
  double _maxX = 0;
  double _minY = 90;
  double _maxY = 110;

  // Shutter Menu Dynamic Data
  bool _isDetailsExpanded = false;
  String? _latestNavVal;
  String? _latestNavDateVal;

  @override
  void initState() {
    super.initState();
    _loadChartData(); 
    _loadHoldingsData();
  }

  // --- THE FINANCIAL ENGINE: BASE 100 COMPOUNDING ---
  Future<void> _loadChartData() async {
    if (!mounted) return;
    setState(() => _isLoadingChart = true);

    try {
      final supabase = Supabase.instance.client;
      final String ticker = widget.fund['ticker'];
      final bool isShariah = (widget.fund['is_shariah'] == 1 || widget.fund['is_shariah'] == '1' || widget.fund['is_shariah'] == true);
      final String indexTicker = isShariah ? 'KMI30' : 'KSE100';
      
      final bool isBenchmark = ['KSE100', 'KMI30', 'GOLD_24K', 'CPI_PK', 'USDPKR'].contains(ticker);
      DateTime startDate = DateTime.now();
      switch (_chartPeriod) {
        case '1M': startDate = DateTime.now().subtract(const Duration(days: 30)); break;
        case '3M': startDate = DateTime.now().subtract(const Duration(days: 90)); break;
        case '6M': startDate = DateTime.now().subtract(const Duration(days: 180)); break;
        case '1Y': startDate = DateTime.now().subtract(const Duration(days: 365)); break;
        case '3Y': startDate = DateTime.now().subtract(const Duration(days: 1095)); break;
        case '5Y': startDate = DateTime.now().subtract(const Duration(days: 1825)); break;
        case 'MAX': startDate = DateTime(2000, 1, 1); break;
      }
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      final fundFuture = isBenchmark 
          ? supabase.from('benchmarks').select('validity_date, value').eq('ticker', ticker).gte('validity_date', startDateStr).order('validity_date', ascending: true)
          : supabase.from('daily_nav').select('validity_date, nav').eq('ticker', ticker).gte('validity_date', startDateStr).order('validity_date', ascending: true);
      final payoutFuture = isBenchmark 
          ? Future.value([]) 
          : supabase.from('payout_history').select('payout_date, payout_amount, ex_nav').eq('ticker', ticker).gte('payout_date', startDateStr);
      final indexFuture = _showKse100 ? supabase.from('benchmarks').select('validity_date, value').eq('ticker', indexTicker).gte('validity_date', startDateStr).order('validity_date', ascending: true) : Future.value([]);
      final goldFuture = _showGold ? supabase.from('benchmarks').select('validity_date, value').eq('ticker', 'GOLD_24K').gte('validity_date', startDateStr).order('validity_date', ascending: true) : Future.value([]);

      final responses = await Future.wait([fundFuture, payoutFuture, indexFuture, goldFuture]);
      List<dynamic> fundData = List.from(responses[0] as List<dynamic>);
      List<dynamic> payoutData = List.from(responses[1] as List<dynamic>);
      List<dynamic> indexData = List.from(responses[2] as List<dynamic>);
      List<dynamic> goldData = List.from(responses[3] as List<dynamic>);

      // Extract Latest NAV dynamically for Shutter Menu
      if (mounted && fundData.isNotEmpty) {
        final lastPoint = fundData.last;
        double? n = double.tryParse(lastPoint[isBenchmark ? 'value' : 'nav'].toString());
        if (n != null) {
          String s = n.toStringAsFixed(4);
          if (s.contains('.')) {
            s = s.replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
          }
          _latestNavVal = s;
        }
        final d = DateTime.tryParse(lastPoint['validity_date'].toString());
        if (d != null) _latestNavDateVal = DateFormat('dd MMM yyyy').format(d);
      }

      List<DateTime> startDates = [];
      if (fundData.isNotEmpty) startDates.add(DateTime.parse(fundData.first['validity_date'].toString()));
      if (_showKse100 && indexData.isNotEmpty) startDates.add(DateTime.parse(indexData.first['validity_date'].toString()));
      if (_showGold && goldData.isNotEmpty) startDates.add(DateTime.parse(goldData.first['validity_date'].toString()));

      if (startDates.isNotEmpty) {
        DateTime commonStartDate = startDates.reduce((a, b) => a.isAfter(b) ? a : b);
        fundData.removeWhere((row) => DateTime.parse(row['validity_date'].toString()).isBefore(commonStartDate));
        indexData.removeWhere((row) => DateTime.parse(row['validity_date'].toString()).isBefore(commonStartDate));
        goldData.removeWhere((row) => DateTime.parse(row['validity_date'].toString()).isBefore(commonStartDate));
        payoutData.removeWhere((row) => DateTime.parse(row['payout_date'].toString()).isBefore(commonStartDate));
      }

      List<FlSpot> fundSpots = [];
      double startNav = 1.0;
      for (var row in fundData) {
        double val = double.tryParse(row[isBenchmark ? 'value' : 'nav'].toString()) ?? 0.0;
        if (val > 0) { startNav = val; break; }
      }

      double currentUnits = 100.0 / startNav;
      double localMinY = 999999;
      double localMaxY = -999999;

      for (var row in fundData) {
        String dateStr = row['validity_date'].toString();
        DateTime date = DateTime.parse(dateStr);
        
        double nav = double.tryParse(row[isBenchmark ? 'value' : 'nav'].toString()) ?? 0.0;
        if (nav <= 0) continue;
        var dailyPayouts = payoutData.where((p) => p['payout_date'].toString().startsWith(dateStr));
        for (var p in dailyPayouts) {
          double pAmt = double.tryParse(p['payout_amount'].toString()) ?? 0.0;
          double exNav = double.tryParse(p['ex_nav'].toString()) ?? 0.0;
          if (exNav > 0) {
            currentUnits = currentUnits * (1 + (pAmt / exNav));
          }
        }

        double base100Value = currentUnits * nav;
        double xValue = date.millisecondsSinceEpoch.toDouble();
        
        fundSpots.add(FlSpot(xValue, base100Value));
        if (base100Value < localMinY) localMinY = base100Value;
        if (base100Value > localMaxY) localMaxY = base100Value;
      }

      if (fundSpots.length < 2) {
        if (mounted) setState(() { _isLoadingChart = false; _fundSpots = []; });
        return;
      }

      List<FlSpot> processBenchmark(List<dynamic> data) {
        List<FlSpot> spots = [];
        if (data.isEmpty) return spots;
        double startVal = double.tryParse(data.first['value'].toString()) ?? 1.0;
        if (startVal <= 0) startVal = 1.0;
        for (var row in data) {
          DateTime date = DateTime.parse(row['validity_date'].toString());
          double val = double.tryParse(row['value'].toString()) ?? 0.0;
          if (val <= 0) continue;
          double base100Value = (val / startVal) * 100.0;
          if (base100Value < localMinY) localMinY = base100Value;
          if (base100Value > localMaxY) localMaxY = base100Value;
          spots.add(FlSpot(date.millisecondsSinceEpoch.toDouble(), base100Value));
        }
        return spots;
      }

      if (mounted) {
        setState(() {
          _fundSpots = fundSpots;
          _kseSpots = processBenchmark(indexData);
          _goldSpots = processBenchmark(goldData);
          _minX = fundSpots.first.x;
          _maxX = fundSpots.last.x;
          _minY = localMinY * 0.95;
          _maxY = localMaxY * 1.05;
          _isLoadingChart = false;
        });
      }
    } catch (e) {
      debugPrint("Chart Fetch Error: $e");
      if (mounted) setState(() => _isLoadingChart = false);
    }
  }

  // --- FUND HOLDINGS ENGINE ---
  Future<void> _loadHoldingsData() async {
    try {
      final supabase = Supabase.instance.client;
      final String ticker = widget.fund['ticker']?.toString().trim().toUpperCase() ?? '';

      final dateResponse = await supabase.from('fund_holdings')
          .select('fmr_date').eq('fund_ticker', ticker).order('fmr_date', ascending: false).limit(1);
      if (dateResponse.isEmpty) {
        if (mounted) setState(() => _isLoadingHoldings = false);
        return;
      }
      
      String latestDate = dateResponse.first['fmr_date'].toString();
      final prevDateResponse = await supabase.from('fund_holdings')
          .select('fmr_date')
          .eq('fund_ticker', ticker)
          .neq('fmr_date', latestDate) 
          .order('fmr_date', ascending: false)
          .limit(1);
      String? previousDate;
      if (prevDateResponse.isNotEmpty) {
        previousDate = prevDateResponse.first['fmr_date'].toString();
      }

      var futures = <Future>[
        supabase.from('fund_holdings').select('stock_ticker, holding_percentage').eq('fund_ticker', ticker).eq('fmr_date', latestDate)
      ];
      if (previousDate != null) {
        futures.add(supabase.from('fund_holdings').select('stock_ticker, holding_percentage').eq('fund_ticker', ticker).eq('fmr_date', previousDate));
      }

      final results = await Future.wait(futures);
      final holdingsResponse = results[0] as List<dynamic>;
      final prevHoldingsResponse = results.length > 1 ? results[1] as List<dynamic> : [];
      if (holdingsResponse.isEmpty) {
        if (mounted) setState(() => _isLoadingHoldings = false);
        return;
      }

      Map<String, double> prevHoldingsMap = {};
      for (var p in prevHoldingsResponse) {
        prevHoldingsMap[p['stock_ticker'].toString().trim()] = double.tryParse(p['holding_percentage'].toString()) ?? 0.0;
      }

      final List<String> stockTickers = holdingsResponse.map((h) => h['stock_ticker'].toString().trim()).toList();
      final stocksResponse = await supabase.from('master_stocks')
          .select('ticker, company_name')
          .inFilter('ticker', stockTickers);
      List<Map<String, dynamic>> realCompanies = [];
      Map<String, dynamic>? otherHoldings;
      Map<String, dynamic>? cashHoldings;
      for (var holding in holdingsResponse) {
        String sTicker = holding['stock_ticker'].toString().trim();
        double percent = double.tryParse(holding['holding_percentage'].toString()) ?? 0.0;
        
        double? delta;
        if (previousDate != null) {
          double prevPercent = prevHoldingsMap[sTicker] ?? 0.0; 
          delta = percent - prevPercent;
        }

        var stockMeta = (stocksResponse as List).firstWhere(
          (s) => s['ticker'].toString().trim() == sTicker, 
          orElse: () => {'company_name': sTicker}
        );
        String name = stockMeta['company_name'].toString();
        
        if (sTicker == 'CASH') {
          cashHoldings = {'ticker': sTicker, 'name': 'Cash & Equivalents', 'percentage': percent, 'delta': delta};
        } else if (sTicker == 'OTHER') {
          otherHoldings = {'ticker': sTicker, 'name': 'Other Holdings', 'percentage': percent, 'delta': delta};
        } else {
          realCompanies.add({'ticker': sTicker, 'name': name, 'percentage': percent, 'delta': delta});
        }
      }

      realCompanies.sort((a, b) => (b['percentage'] as double).compareTo(a['percentage'] as double));
      List<Map<String, dynamic>> finalHoldings = realCompanies.take(10).toList();

      if (otherHoldings != null && (otherHoldings['percentage'] as double) > 0) finalHoldings.add(otherHoldings);
      if (cashHoldings != null && (cashHoldings['percentage'] as double) > 0) finalHoldings.add(cashHoldings);
      if (mounted) {
        setState(() {
          DateTime? parsedDate;
          try {
             parsedDate = DateTime.tryParse(latestDate.length >= 10 ? latestDate.substring(0, 10) : latestDate);
          } catch (_) {}
          
          _holdingsDate = parsedDate != null ? DateFormat('MMMM yyyy').format(parsedDate) : latestDate;
   
          _sectorAllocations = []; 
          _topHoldings = finalHoldings;
          _isLoadingHoldings = false;
        });
      }
    } catch (e) {
      debugPrint("Holdings Fetch Error: $e");
      if (mounted) setState(() => _isLoadingHoldings = false);
    }
  }

  Widget _buildDeltaIndicator(double? delta) {
    if (delta == null) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)),
        child: const Text('First Month', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
      );
    }
    
    if (delta.abs() < 0.01) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
        child: const Text('No change', style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w600)),
      );
    }
    
    final isPositive = delta > 0;
    final color = isPositive ? Colors.greenAccent : Colors.redAccent.shade200;
    final icon = isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(6), 
        border: Border.all(color: color.withOpacity(0.2))
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          Text('${delta.abs().toStringAsFixed(2)}%', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  bool _isPeriodValid(String? inceptionDateStr, int requiredDays) {
    if (inceptionDateStr == null || inceptionDateStr.isEmpty) return true;
    DateTime? incDate = DateTime.tryParse(inceptionDateStr);
    if (incDate == null) return true;
    final diff = DateTime.now().difference(incDate).inDays;
    return diff >= requiredDays;
  }

  String _formatBenchmarkCagr(String ticker, String dbKey, int years) {
    final stat = widget.benchmarkStats[ticker];
    if (stat == null || stat[dbKey] == null) return 'N/A';
    final growth = (stat[dbKey] as num).toDouble();
    double cagrPercent = (math.pow(growth, 1.0 / years) - 1.0) * 100;
    return '${cagrPercent >= 0 ? '+' : ''}${cagrPercent.toStringAsFixed(2)}%';
  }

  String _cleanFundName(String name) {
    return name.replaceAll('Exchange Traded Fund', 'ETF').replaceAll('Government', 'Govt.').trim();
  }

  // --- THE NEW DYNAMIC SHUTTER MENU ROW BUILDER ---
  Widget _buildDetailRow(String label, dynamic value, {String suffix = '', String prefix = '', String? subText}) {
    if (value == null || value.toString().trim().isEmpty || value.toString().trim() == 'null' || value.toString().trim() == 'N/A') {
      return const SizedBox.shrink();
    }
    
    String displayValue = value.toString().trim();

    if (value is num) {
       displayValue = value.toStringAsFixed(2);
       if (displayValue.endsWith('.00')) {
         displayValue = displayValue.substring(0, displayValue.length - 3);
       }
    }
    
    if (suffix.isNotEmpty && displayValue.endsWith(suffix.trim())) {
      suffix = '';
    }

    bool isLongText = displayValue.length > 25;

    if (isLongText) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text('$prefix$displayValue$suffix', textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(flex: 5, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500))),
          const SizedBox(width: 12),
          Expanded(
            flex: 8, 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$prefix$displayValue$suffix', textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                if (subText != null && subText.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 2.0), child: Text(subText, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w400))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnRow(String label, String dbKey, int requiredDays, {int? years, bool isShariah = false}) {
    final rawValue = widget.fund[dbKey];
    final inception = widget.fund['inception_date']?.toString();
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0);
    if (rawValue == null || !_isPeriodValid(inception, requiredDays)) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)), const Text('-', style: TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.bold))]));
    }

    final double returnFactor = (rawValue as num).toDouble();
    final double percent = (returnFactor - 1.0) * 100.0;
    final double profitValue = widget.investmentAmount * (returnFactor - 1.0);

    String profitString = currencyFormat.format(profitValue.abs());
    String formattedValueDisplay = profitValue > 0 ? '+PKR $profitString' : profitValue < 0 ? '-PKR $profitString' : 'PKR 0';
    String percentageString = '${percent > 0 ? '+' : ''}${percent.toStringAsFixed(2)}%';
    Color statColor = percent > 0 ? Colors.greenAccent : percent < 0 ? Colors.redAccent.shade100 : Colors.white70;
    Widget mainRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(formattedValueDisplay, style: TextStyle(color: statColor, fontSize: 16, fontWeight: FontWeight.bold, fontFeatures: const [FontFeature.tabularFigures()])), const SizedBox(height: 2), Text(percentageString, style: TextStyle(color: statColor.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600))]),
      ],
    );
    if (years != null && years >= 1) {
      double cagrPercent = (math.pow(returnFactor, 1.0 / years) - 1.0) * 100;
      String cagrStr = '${cagrPercent > 0 ? '+' : ''}${cagrPercent.toStringAsFixed(2)}%';
      
      String indexTicker = isShariah ? 'KMI30' : 'KSE100';
      String indexName = isShariah ? 'KMI30' : 'KSE100';
      
      String indexCagr = _formatBenchmarkCagr(indexTicker, dbKey, years);
      String goldCagr = _formatBenchmarkCagr('GOLD_24K', dbKey, years);
      String inflCagr = _formatBenchmarkCagr('CPI_PK', dbKey, years);

      Widget cagrRow = Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Annualized:', style: TextStyle(color: Colors.white54, fontSize: 11)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Fund: $cagrStr  •  $indexName: $indexCagr', 
                  style: TextStyle(color: Colors.tealAccent.withOpacity(0.9), fontSize: 10, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Gold: $goldCagr  •  Inflation: $inflCagr', 
                  style: TextStyle(color: Colors.tealAccent.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [mainRow, cagrRow],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: mainRow,
    );
  }

  // --- CHART UI BUILDER ---
  Widget _buildInteractiveChart() {
    final bool isShariah = (widget.fund['is_shariah'] == 1 || widget.fund['is_shariah'] == '1' || widget.fund['is_shariah'] == true);
    final String indexName = isShariah ? 'KMI30' : 'KSE100';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.tealAccent.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Return Index (Base 100)', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                onPressed: () => setState(() { _isChartExpanded = false; }),
              )
            ],
          ),
          const SizedBox(height: 16),
          
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['1M', '3M', '6M', '1Y', '3Y', '5Y', 'MAX'].map((period) {
                final isSelected = _chartPeriod == period;
                return GestureDetector(
                  onTap: () {
                    setState(() { _chartPeriod = period; });
                    _loadChartData();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: isSelected ? Colors.tealAccent.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected ? Colors.tealAccent : Colors.white24)),
                    child: Text(period, style: TextStyle(color: isSelected ? Colors.tealAccent : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 250,
            child: _isLoadingChart 
              ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
              : _fundSpots.isEmpty 
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
                            showTitles: true, 
                            reservedSize: 30, 
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
                              String label = spot.barIndex == 0 ? 'Fund' : spot.barIndex == 1 ? indexName : 'Gold';
                              return LineTooltipItem('${DateFormat('dd MMM yyyy').format(date)}\n$label: ${spot.y.toStringAsFixed(1)}', const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold));
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _fundSpots, isCurved: true, color: Colors.tealAccent, barWidth: 2, isStrokeCapRound: true, dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: true, color: Colors.tealAccent.withOpacity(0.1)),
                        ),
                        if (_showKse100 && _kseSpots.isNotEmpty)
                          LineChartBarData(spots: _kseSpots, isCurved: true, color: Colors.orangeAccent, barWidth: 1.5, dotData: const FlDotData(show: false)),
                        if (_showGold && _goldSpots.isNotEmpty)
                          LineChartBarData(spots: _goldSpots, isCurved: true, color: Colors.yellowAccent, barWidth: 1.5, dotData: const FlDotData(show: false)),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          
          Wrap(
            spacing: 12,
            children: [
              FilterChip(
                label: Text('+ $indexName', style: TextStyle(color: _showKse100 ? Colors.orangeAccent : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                selected: _showKse100,
                selectedColor: Colors.orangeAccent.withOpacity(0.1),
                backgroundColor: Colors.white.withOpacity(0.05),
                checkmarkColor: Colors.orangeAccent,
                side: BorderSide(color: _showKse100 ? Colors.orangeAccent : Colors.transparent),
                onSelected: (val) {
                  setState(() { _showKse100 = val; });
                  _loadChartData();
                },
              ),
              FilterChip(
                label: Text('+ Gold', style: TextStyle(color: _showGold ? Colors.yellowAccent : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                selected: _showGold,
                selectedColor: Colors.yellowAccent.withOpacity(0.1),
                backgroundColor: Colors.white.withOpacity(0.05),
                checkmarkColor: Colors.yellowAccent,
                side: BorderSide(color: _showGold ? Colors.yellowAccent : Colors.transparent),
                onSelected: (val) {
                  setState(() { _showGold = val; });
                  _loadChartData();
                },
              ),
            ],
          )
        ],
      ),
    );
  }

  // --- FUND HOLDINGS UI ---
  Widget _buildHoldingsSection() {
    if (_isLoadingHoldings) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: Colors.tealAccent)));
    }
    
    if (_topHoldings.isEmpty) {
      return const SizedBox.shrink();
    }

    bool isOther(String name) => name == 'Other Holdings';
    bool isCash(String name) => name == 'Cash & Equivalents';

    double absoluteMaxPercent = 0.0;
    for (var item in _topHoldings) {
      if ((item['percentage'] as double) > absoluteMaxPercent) {
        absoluteMaxPercent = item['percentage'] as double;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16), 
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Top Holdings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text('As of $_holdingsDate', style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_topHoldings.length.toString(), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                        const Text('Top Assets', style: TextStyle(color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2, centerSpaceRadius: 45, startDegreeOffset: -90,
                        sections: _topHoldings.asMap().entries.map((entry) {
                          int idx = entry.key;
                          var stock = entry.value;
                          String name = stock['name'].toString();
                          double val = stock['percentage'] as double;
                          
                          Color sectionColor;
                          if (isOther(name)) {
                            sectionColor = Colors.white24;
                          } else if (isCash(name)) {
                            sectionColor = Colors.white10;
                          } else {
                            sectionColor = _sectorColors[idx % _sectorColors.length];
                          }

                          return PieChartSectionData(
                            color: sectionColor, value: val, radius: 50,
                            titleStyle: const TextStyle(color: Colors.transparent), showTitle: false,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              ..._topHoldings.asMap().entries.map((entry) {
                int idx = entry.key;
                var stock = entry.value;
                String name = stock['name'].toString();
                double percent = stock['percentage'] as double;
                
                double barWidthFactor = absoluteMaxPercent > 0 ? (percent / absoluteMaxPercent) : 0.0;
                if (barWidthFactor > 1.0) barWidthFactor = 1.0; 

                Color itemColor;
                if (isOther(name)) {
                  itemColor = Colors.white38;
                } else if (isCash(name)) {
                  itemColor = Colors.white24;
                } else {
                  itemColor = _sectorColors[idx % _sectorColors.length];
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: itemColor, shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(name, style: TextStyle(color: (isOther(name) || isCash(name)) ? Colors.white54 : Colors.white, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${percent.toStringAsFixed(2)}%', style: TextStyle(color: itemColor, fontSize: 13, fontWeight: FontWeight.bold)),
                              _buildDeltaIndicator(stock['delta'] as double?),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 4, width: double.infinity,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(2)),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: barWidthFactor,
                          child: Container(decoration: BoxDecoration(color: itemColor.withOpacity(0.8), borderRadius: BorderRadius.circular(2))),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fundName = _cleanFundName(widget.fund['fund_name'] ?? 'Unknown Fund');
    final amcName = widget.fund['amc_name'] ?? 'Unknown AMC';
    final isShariah = (widget.fund['is_shariah'] == 1 || widget.fund['is_shariah'] == '1' || widget.fund['is_shariah'] == true);
    final category = widget.fund['category'] ?? 'N/A';
    final risk = widget.fund['risk_profile'] ?? 'N/A';
    final inceptionRaw = widget.fund['inception_date'];
    final incDateStr = inceptionRaw != null ? DateFormat('dd MMM yyyy').format(DateTime.tryParse(inceptionRaw.toString()) ?? DateTime.now()) : 'N/A';
    
    final String safeAmcName = amcName.toString().toLowerCase().replaceAll(' ', '_');
    final String safeTicker = widget.fund['ticker']?.toString().toLowerCase() ?? '';
    final bool isCrypto = category.toString().toLowerCase() == 'crypto';
    
    final String logoPath = isCrypto ? 'assets/logos/$safeTicker.png' : 'assets/logos/$safeAmcName.png';

    return Theme(
      data: Theme.of(context).copyWith(textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Fund Details', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          centerTitle: true, backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.white), 
          flexibleSpace: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.black.withOpacity(0.2))))
        ),
        body: Container(
          width: double.infinity, height: double.infinity, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF000000)])),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(), padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(amcName.toString().toUpperCase(), style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
                            const SizedBox(height: 8),
                            Text('$fundName${isShariah ? " 🕌" : ""}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
                            const SizedBox(height: 4),
                            Text(category, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 60, height: 60, padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.1))),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(logoPath, fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_balance, color: Colors.tealAccent, size: 30)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // --- THE DYNAMIC SHUTTER MENU ---
                  GestureDetector(
                    onTap: () => setState(() => _isDetailsExpanded = !_isDetailsExpanded),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.tealAccent, size: 20),
                                  SizedBox(width: 8),
                                  Text('Fund Details & Metrics', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Icon(_isDetailsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.tealAccent),
                            ],
                          ),
                          
                          AnimatedCrossFade(
                            firstChild: const SizedBox(width: double.infinity, height: 0),
                            secondChild: Padding(
                              padding: const EdgeInsets.only(top: 20.0),
                              child: Column(
                                children: [
                                  _buildDetailRow('Risk Profile', risk),
                                  _buildDetailRow('Fund Manager', widget.fund['fund_manager']),
                                  _buildDetailRow('Inception Date', incDateStr),
                                  if (_latestNavVal != null) 
                                  _buildDetailRow('Latest NAV', 'PKR $_latestNavVal', subText: _latestNavDateVal != null ? 'As of $_latestNavDateVal' : null),
                                  if (widget.fund['aum'] != null) 
                                  _buildDetailRow('AUM', (widget.fund['aum'] as num).toDouble() >= 1000 ? 'PKR ${((widget.fund['aum'] as num).toDouble() / 1000).toStringAsFixed(2)} Billion' : 'PKR ${NumberFormat('#,##0.00').format(widget.fund['aum'])} Million'),
                                  // Only show the header if at least one of the values exists
                                  if (widget.fund['min_investment'] != null || widget.fund['sub_investment'] != null) ...[
                                    const Padding(
                                      padding: EdgeInsets.only(top: 12.0, bottom: 4.0),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text('Minimum Investment', style: TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    _buildDetailRow('  • Initial', widget.fund['min_investment']),
                                    _buildDetailRow('  • Subsequent', widget.fund['sub_investment']),
                                  ],
                                  _buildDetailRow('Front End Load (FEL)', widget.fund['fel']),
                                  _buildDetailRow('Back End Load (BEL)', widget.fund['bel']),
                                  _buildDetailRow('TER (MTD)', widget.fund['ter_mtd'], suffix: '%'),
                                  _buildDetailRow('TER (YTD)', widget.fund['ter_ytd'], suffix: '%'),
                                  _buildDetailRow('Standard Deviation', widget.fund['standard_deviation'], suffix: '%'),
                                  _buildDetailRow('Sharpe Ratio', widget.fund['sharpe_ratio']),
                                  _buildDetailRow('Beta', widget.fund['beta']),
                                  _buildDetailRow('Information Ratio', widget.fund['info_ratio']),
                                  _buildDetailRow('Portfolio Turnover', widget.fund['portfolio_turnover']),
                                ],
                              ),
                            ),
                            crossFadeState: _isDetailsExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 300),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  if (!_isChartExpanded)
                    Center(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.show_chart, color: Colors.tealAccent, size: 20),
                        label: const Text('✨ Interactive Chart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          side: BorderSide(color: Colors.tealAccent.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          backgroundColor: Colors.tealAccent.withOpacity(0.05)
                        ),
                        onPressed: () {
                          setState(() { _isChartExpanded = true; });
                          _loadChartData();
                        },
                      ),
                    ),
                  
                  if (_isChartExpanded)
                    _buildInteractiveChart(),

                  const SizedBox(height: 24),
                  
                  const Text('Performance Breakdown', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))),
                    child: Column(
                      children: [
                        _buildReturnRow('1 Day', 'return_1d', 1, isShariah: isShariah), const Divider(color: Colors.white12), 
                        _buildReturnRow('30 Days', 'return_30d', 30, isShariah: isShariah), const Divider(color: Colors.white12), 
                        _buildReturnRow('1 Year', 'return_1y', 365, years: 1, isShariah: isShariah), const Divider(color: Colors.white12), 
                        _buildReturnRow('3 Years', 'return_3y', 1095, years: 3, isShariah: isShariah), const Divider(color: Colors.white12), 
                        _buildReturnRow('5 Years', 'return_5y', 1825, years: 5, isShariah: isShariah), const Divider(color: Colors.white12), 
                        _buildReturnRow('10 Years', 'return_10y', 3650, years: 10, isShariah: isShariah), const Divider(color: Colors.white12), 
                        _buildReturnRow('15 Years', 'return_15y', 5475, years: 15, isShariah: isShariah),
                      ]
                    ),
                  ),

                  _buildHoldingsSection(),
                  const SizedBox(height: 24),
                  
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