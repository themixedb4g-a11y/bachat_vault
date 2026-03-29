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
    setState(() {
      _isLoadingChart = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final String ticker = widget.fund['ticker'];
      final bool isShariah = (widget.fund['is_shariah'] == 1 || widget.fund['is_shariah'] == '1' || widget.fund['is_shariah'] == true);
      final String indexTicker = isShariah ? 'KMI30' : 'KSE100';
      
      // --- NEW: Identify if the main ticker is actually a benchmark ---
      final bool isBenchmark = ['KSE100', 'KMI30', 'GOLD_24K', 'CPI_PK'].contains(ticker);

      // 1. Determine Date Range
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

      // 2. Fetch Data Concurrently (SMART ROUTING)
      final fundFuture = isBenchmark 
          ? supabase.from('benchmarks').select('validity_date, value').eq('ticker', ticker).gte('validity_date', startDateStr).order('validity_date', ascending: true)
          : supabase.from('daily_nav').select('validity_date, nav').eq('ticker', ticker).gte('validity_date', startDateStr).order('validity_date', ascending: true);
          
      final payoutFuture = isBenchmark 
          ? Future.value([]) // Benchmarks don't have payouts
          : supabase.from('payout_history').select('payout_date, payout_amount, ex_nav').eq('ticker', ticker).gte('payout_date', startDateStr);
      
      final indexFuture = _showKse100 ? supabase.from('benchmarks').select('validity_date, value').eq('ticker', indexTicker).gte('validity_date', startDateStr).order('validity_date', ascending: true) : Future.value([]);
      final goldFuture = _showGold ? supabase.from('benchmarks').select('validity_date, value').eq('ticker', 'GOLD_24K').gte('validity_date', startDateStr).order('validity_date', ascending: true) : Future.value([]);

      final responses = await Future.wait([fundFuture, payoutFuture, indexFuture, goldFuture]);
      
      final fundData = responses[0] as List<dynamic>;
      final payoutData = responses[1] as List<dynamic>;
      final indexData = responses[2] as List<dynamic>;
      final goldData = responses[3] as List<dynamic>;

      // Ensure we have at least 2 points to draw a line
      if (fundData.length < 2) {
        setState(() { 
          _isLoadingChart = false; 
          _fundSpots = []; 
        });
        return;
      }

      // 3. Process Main Data (Base 100 + Payout Reinvestment)
      List<FlSpot> fundSpots = [];
      
      // SAFEGUARD: Find the first actual valid NAV/Value greater than 0
      var validStartRow = fundData.firstWhere(
        (row) {
          double val = isBenchmark ? (row['value'] as num).toDouble() : (row['nav'] as num).toDouble();
          return val > 0;
        }, 
        orElse: () => fundData.first
      );
      
      double startNav = isBenchmark ? (validStartRow['value'] as num).toDouble() : (validStartRow['nav'] as num).toDouble();
      if (startNav <= 0) startNav = 1.0; 
      
      double currentUnits = 100.0 / startNav; 
      double localMinY = 999999;
      double localMaxY = -999999;

      for (var row in fundData) {
        String dateStr = row['validity_date'].toString();
        DateTime date = DateTime.parse(dateStr);
        double nav = isBenchmark ? (row['value'] as num).toDouble() : (row['nav'] as num).toDouble();

        if (nav <= 0) continue; // The zero shield

        // Reinvest payouts (will gracefully do nothing for benchmarks since payoutData is empty)
        var dailyPayouts = payoutData.where((p) => p['payout_date'].toString().startsWith(dateStr));
        for (var p in dailyPayouts) {
          double pAmt = (p['payout_amount'] as num).toDouble();
          double exNav = (p['ex_nav'] as num).toDouble();
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

      // 4. Process Benchmark Overlays (Simple Base 100)
      List<FlSpot> processBenchmark(List<dynamic> data) {
        List<FlSpot> spots = [];
        if (data.isEmpty) return spots;
        double startVal = (data.first['value'] as num).toDouble();
        if (startVal <= 0) startVal = 1.0;
        for (var row in data) {
          DateTime date = DateTime.parse(row['validity_date'].toString());
          double val = (row['value'] as num).toDouble();
          if (val <= 0) continue;
          double base100Value = (val / startVal) * 100.0;
          
          if (base100Value < localMinY) localMinY = base100Value;
          if (base100Value > localMaxY) localMaxY = base100Value;
          
          spots.add(FlSpot(date.millisecondsSinceEpoch.toDouble(), base100Value));
        }
        return spots;
      }

      // 5. Update State
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

    } catch (e) {
      debugPrint("Chart Fetch Error: $e");
      setState(() { _isLoadingChart = false; });
    }
  }

  // --- FUND HOLDINGS ENGINE ---
  Future<void> _loadHoldingsData() async {
    try {
      final supabase = Supabase.instance.client;
      final String ticker = widget.fund['ticker'];

      // 1. Find the most recent date this fund reported holdings
      final dateResponse = await supabase.from('fund_holdings')
          .select('fmr_date').eq('fund_ticker', ticker).order('fmr_date', ascending: false).limit(1);
          
      if (dateResponse.isEmpty) {
        setState(() => _isLoadingHoldings = false);
        return;
      }
      
      String latestDate = dateResponse.first['fmr_date'].toString();

      // 2. Fetch the holdings for that specific date
      final holdingsResponse = await supabase.from('fund_holdings')
          .select('stock_ticker, holding_percentage')
          .eq('fund_ticker', ticker).eq('fmr_date', latestDate);

      if (holdingsResponse.isEmpty) {
        setState(() => _isLoadingHoldings = false);
        return;
      }

      // 3. Fetch the metadata for these specific stocks
      final List<String> stockTickers = holdingsResponse.map((h) => h['stock_ticker'].toString()).toList();
      final stocksResponse = await supabase.from('master_stocks')
          .select('ticker, company_name, sector')
          .inFilter('ticker', stockTickers);

      // 4. Merge and Process the Data
      Map<String, double> sectorMap = {};
      List<Map<String, dynamic>> processedHoldings = [];

      for (var holding in holdingsResponse) {
        String sTicker = holding['stock_ticker'].toString();
        double percent = (holding['holding_percentage'] as num).toDouble();
        
        // Find matching stock details (Fallback to 'Others/Cash' if it's a T-Bill or unlisted)
        var stockMeta = stocksResponse.firstWhere((s) => s['ticker'] == sTicker, orElse: () => {'company_name': sTicker, 'sector': 'Others / Cash Equivalents'});
        
        String sector = stockMeta['sector'].toString();
        String name = stockMeta['company_name'].toString();

        // Add to Sector groupings
        sectorMap[sector] = (sectorMap[sector] ?? 0) + percent;

        // Add to individual list
        processedHoldings.add({
          'ticker': sTicker,
          'name': name,
          'sector': sector,
          'percentage': percent,
        });
      }

      // Sort Sectors Highest to Lowest
      var sortedSectors = sectorMap.entries.map((e) => {'sector': e.key, 'percentage': e.value}).toList();
      sortedSectors.sort((a, b) => (b['percentage'] as double).compareTo(a['percentage'] as double));

      // Sort Stocks Highest to Lowest and take Top 10
      processedHoldings.sort((a, b) => (b['percentage'] as double).compareTo(a['percentage'] as double));
      List<Map<String, dynamic>> top10 = processedHoldings.take(10).toList();

      setState(() {
        _holdingsDate = DateFormat('MMMM yyyy').format(DateTime.parse(latestDate));
        _sectorAllocations = sortedSectors;
        _topHoldings = top10;
        _isLoadingHoldings = false;
      });

    } catch (e) {
      debugPrint("Holdings Fetch Error: $e");
      setState(() => _isLoadingHoldings = false);
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
                            showTitles: true, reservedSize: 30, interval: (_maxX - _minX) / 3, // Show roughly 3-4 dates on bottom
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

  // --- FUND HOLDINGS UI ---
  Widget _buildHoldingsSection() {
    if (_isLoadingHoldings) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: Colors.tealAccent)));
    }
    
    if (_sectorAllocations.isEmpty) {
      return const SizedBox.shrink(); // Hide entirely if no data
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Portfolio Holdings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text('As of $_holdingsDate', style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 16),
        
        // 1. SECTOR DONUT CHART
        Container(
          padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
          child: Column(
            children: [
              const Text('Sector Allocation', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              SizedBox(
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Center Text
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_sectorAllocations.length.toString(), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                        const Text('Sectors', style: TextStyle(color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                    // The Donut
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2, centerSpaceRadius: 60, startDegreeOffset: -90,
                        sections: _sectorAllocations.asMap().entries.map((entry) {
                          int idx = entry.key;
                          double val = entry.value['percentage'] as double;
                          return PieChartSectionData(
                            color: _sectorColors[idx % _sectorColors.length], value: val, radius: 25,
                            title: '${val.toStringAsFixed(1)}%', titleStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Sector Legend
              Wrap(
                spacing: 12, runSpacing: 8, alignment: WrapAlignment.center,
                children: _sectorAllocations.asMap().entries.map((entry) {
                  int idx = entry.key;
                  String name = entry.value['sector'] as String;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: _sectorColors[idx % _sectorColors.length], shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(name, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. TOP 10 HOLDINGS LIST
        Container(
          padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Top 10 Holdings', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ..._topHoldings.map((stock) {
                double percent = stock['percentage'] as double;
                // Normalize width relative to the largest holding so the bars look good
                double maxPercent = _topHoldings.first['percentage'] as double;
                double barWidthFactor = percent / maxPercent;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(stock['name'].toString(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Text('${percent.toStringAsFixed(2)}%', style: const TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // The subtle progress bar
                      Container(
                        height: 6, width: double.infinity,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(3)),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: barWidthFactor,
                          child: Container(decoration: BoxDecoration(color: Colors.tealAccent.withOpacity(0.6), borderRadius: BorderRadius.circular(3))),
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

                  _buildHoldingsSection(),
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