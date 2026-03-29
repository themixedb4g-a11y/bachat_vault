import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    _loadChartData(); // Added this so the 1Y chart loads automatically!
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
      final bool isBenchmark = ['KSE100', 'KMI30', 'GOLD_24K', 'CPI_PK'].contains(ticker);

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
      
      final fundData = responses[0] as List<dynamic>;
      final payoutData = responses[1] as List<dynamic>;
      final indexData = responses[2] as List<dynamic>;
      final goldData = responses[3] as List<dynamic>;

      List<FlSpot> fundSpots = [];
      double startNav = 1.0; 
      
      // Safe find for starting NAV
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
        
        // ULTIMATE ZERO SHIELD
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

      // SAFEGUARD: Ensure we actually have data to draw!
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

  // --- FUND HOLDINGS ENGINE (TOP 10 COMPANIES + OTHERS/CASH) ---
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
      
      String rawDate = dateResponse.first['fmr_date'].toString();
      String latestDate = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;

      final holdingsResponse = await supabase.from('fund_holdings')
          .select('stock_ticker, holding_percentage')
          .eq('fund_ticker', ticker).eq('fmr_date', latestDate);

      if (holdingsResponse.isEmpty) {
        if (mounted) setState(() => _isLoadingHoldings = false);
        return;
      }

      final List<String> stockTickers = (holdingsResponse as List).map((h) => h['stock_ticker'].toString().trim()).toList();
      
      final stocksResponse = await supabase.from('master_stocks')
          .select('ticker, company_name')
          .inFilter('ticker', stockTickers);

      List<Map<String, dynamic>> realCompanies = [];
      Map<String, dynamic>? otherHoldings;
      Map<String, dynamic>? cashHoldings;

      for (var holding in holdingsResponse) {
        String sTicker = holding['stock_ticker'].toString().trim();
        double percent = double.tryParse(holding['holding_percentage'].toString()) ?? 0.0;
        
        var stockMeta = (stocksResponse as List).firstWhere(
          (s) => s['ticker'].toString().trim() == sTicker, 
          orElse: () => {'company_name': sTicker}
        );
        
        String name = stockMeta['company_name'].toString();
        
        // Clean up names and separate them into buckets
        if (sTicker == 'CASH') {
          cashHoldings = {'ticker': sTicker, 'name': 'Cash & Equivalents', 'percentage': percent};
        } else if (sTicker == 'OTHER') {
          otherHoldings = {'ticker': sTicker, 'name': 'Other Holdings', 'percentage': percent};
        } else {
          realCompanies.add({'ticker': sTicker, 'name': name, 'percentage': percent});
        }
      }

      // 1. Sort the REAL companies by highest percentage
      realCompanies.sort((a, b) => (b['percentage'] as double).compareTo(a['percentage'] as double));
      
      // 2. Take exactly the Top 10 real companies
      List<Map<String, dynamic>> finalHoldings = realCompanies.take(10).toList();

      // 3. Append the muted categories strictly at the bottom (if they have > 0%)
      if (otherHoldings != null && (otherHoldings['percentage'] as double) > 0) {
        finalHoldings.add(otherHoldings);
      }
      if (cashHoldings != null && (cashHoldings['percentage'] as double) > 0) {
        finalHoldings.add(cashHoldings);
      }

      if (mounted) {
        setState(() {
          DateTime? parsedDate = DateTime.tryParse(latestDate);
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

  // --- EXISTING HELPERS ---
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
    // (Paste your full giant name shortener logic back here)
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

  Widget _buildInfoPill(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)]),
      ),
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
          
          // Timeframe Selectors
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

          // The Actual Chart
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
                            // GRID SAFEGUARD: Prevents Division by Zero crash
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
                          // tooltipBgColor: Colors.black87,
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
                        // Fund Line
                        LineChartBarData(
                          spots: _fundSpots, isCurved: true, color: Colors.tealAccent, barWidth: 2, isStrokeCapRound: true, dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: true, color: Colors.tealAccent.withOpacity(0.1)),
                        ),
                        // KSE100 Line
                        if (_showKse100 && _kseSpots.isNotEmpty)
                          LineChartBarData(spots: _kseSpots, isCurved: true, color: Colors.orangeAccent, barWidth: 1.5, dotData: const FlDotData(show: false), dashArray: [5, 5]),
                        // Gold Line
                        if (_showGold && _goldSpots.isNotEmpty)
                          LineChartBarData(spots: _goldSpots, isCurved: true, color: Colors.yellowAccent, barWidth: 1.5, dotData: const FlDotData(show: false), dashArray: [5, 5]),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          
          // Benchmark Toggles
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

  // --- FUND HOLDINGS UI (OVERFLOW FIX & DISTINCT COLORS) ---
  Widget _buildHoldingsSection() {
    if (_isLoadingHoldings) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: Colors.tealAccent)));
    }
    
    if (_topHoldings.isEmpty) {
      return const SizedBox.shrink();
    }

    bool isOther(String name) => name == 'Other Holdings';
    bool isCash(String name) => name == 'Cash & Equivalents';

    // OVERFLOW FIX: Find the absolute highest percentage in the list to use as our 100% baseline for the bars
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
                          
                          // DISTINCT MUTED COLORS
                          Color sectionColor;
                          if (isOther(name)) {
                            sectionColor = Colors.white24; // Lighter grey for Others
                          } else if (isCash(name)) {
                            sectionColor = Colors.white10; // Darker grey for Cash
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
                
                // MATH FIX: Guaranteed to be between 0.0 and 1.0
                double barWidthFactor = absoluteMaxPercent > 0 ? (percent / absoluteMaxPercent) : 0.0;
                if (barWidthFactor > 1.0) barWidthFactor = 1.0; 

                // DISTINCT MUTED COLORS
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
                          Text('${percent.toStringAsFixed(2)}%', style: TextStyle(color: itemColor, fontSize: 13, fontWeight: FontWeight.bold)),
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
    final terMtd = widget.fund['ter_mtd'] != null ? '${widget.fund['ter_mtd']}%' : 'N/A';
    final terYtd = widget.fund['ter_ytd'] != null ? '${widget.fund['ter_ytd']}%' : 'N/A';

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
                  Row(children: [_buildInfoPill('Category', category.toString()), const SizedBox(width: 12), _buildInfoPill('Risk Profile', risk.toString())]), const SizedBox(height: 12),
                  Row(children: [_buildInfoPill('Inception Date', incDateStr), const SizedBox(width: 12), _buildInfoPill('TER (MTD)', terMtd), const SizedBox(width: 12), _buildInfoPill('TER (YTD)', terYtd)]), 
                  const SizedBox(height: 32),
                  
                  // --- NEW: THE CHART BUTTON & EXPANDING AREA ---
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