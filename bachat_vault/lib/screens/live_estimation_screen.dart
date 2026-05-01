import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class LiveEstimationScreen extends StatefulWidget {
  const LiveEstimationScreen({super.key});

  @override
  State<LiveEstimationScreen> createState() => _LiveEstimationScreenState();
}

class _LiveEstimationScreenState extends State<LiveEstimationScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;

  Map<String, Map<String, dynamic>> _liveStocks = {};
  Map<String, Map<String, dynamic>> _indices = {};
  List<Map<String, dynamic>> _masterFunds = [];
  Map<String, List<Map<String, dynamic>>> _latestHoldingsByFund = {};

  List<Map<String, dynamic>> _estimatedFunds = [];
  List<Map<String, dynamic>> _filteredEstimatedFunds = [];

  double _investmentAmount = 100000.0;
  final TextEditingController _investmentController = TextEditingController(text: '1,00,000');
  
  List<String> _amcs = ['All'];
  List<String> _categories = ['All'];
  String _selectedAmc = 'All';
  String _selectedCategory = 'All';

  // MARKET STATUS STATE
  String _marketStatusText = 'Checking...';
  Color _marketStatusColor = Colors.white54;

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0);

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

  final Map<String, String> amcMap = {
    '786 Investments Limited': '786 Investments', 'ABL Asset Management Company Limited': 'ABL Funds',
    'AKD Investment Management Limited': 'AKD Investment Management', 'Al Habib Asset Management Limited': 'Al Habib Asset Management',
    'Al Meezan Investment Management Limited': 'Al Meezan Investments', 'Alfalah Asset Management Limited': 'Alfalah Asset Management',
    'Atlas Asset Management Limited': 'Atlas Asset Management', 'AWT Investments Limited': 'AWT Investments',
    'Faysal Asset Management Limited': 'Faysal Funds', 'First Capital Investments Limited': 'First Capital Investments',
    'HBL Asset Management Limited': 'HBL Asset Management', 'JS Investments Limited': 'JS Investments',
    'Lakson Investments Limited': 'Lakson Investments', 'Lucky Investments Limited': 'Lucky Investments',
    'Mahaana Wealth Limited': 'Mahaana Wealth', 'MCB Investment Management Limited': 'MCB Funds',
    'National Investment Trust Limited': 'National Investment Trust', 'NBP Fund Management Limited': 'NBP Funds',
    'Pak Oman Asset Management Company Limited': 'Pak Oman Asset Management', 'Pak-Qatar Asset Management Company Limited': 'Pak Qatar Asset Management',
    'EFU Life Insurance Limited': 'EFU Life Insurance', 'UBL Fund Managers Limited': 'UBL Funds',
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
        .replaceAll("Faysal Khushal Mustaqbil Fund (Faysal Nuumah Women Savers Plan)", "Faysal Nu'umah Women Savers Plan")
        .replaceAll('Faysal Islamic Financial Planning Fund II (Faysal Priority Ascend Plan I)', 'Faysal Priority Ascend Plan I')
        .replaceAll('Faysal Islamic Financial Planning Fund II (Faysal Priority Ascend Plan II)', 'Faysal Priority Ascend Plan II')
        .replaceAll('Faysal Islamic Financial Planning Fund II (Faysal Priority Ascend Plan III)', 'Faysal Priority Ascend Plan III')
        .replaceAll("Faysal Khushal Mustaqbil Fund (Faysal Barakah Women Savers Plan)", "Faysal Barak'ah Women Savers Plan")
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

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _investmentController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        supabase.from('master_funds').select('ticker, fund_name, amc_name, category, is_shariah'),
        supabase.from('live_stock_prices').select('ticker, current_price, change, change_percent'),
        supabase.from('fund_holdings').select('fund_ticker, stock_ticker, holding_percentage, fmr_date'),
        supabase.from('market_holidays').select('holiday_date'),
        supabase.from('system_settings').select('setting_key, setting_value'),
      ]);

      final fundsData = results[0] as List<dynamic>;
      final liveData = results[1] as List<dynamic>;
      final holdingsData = results[2] as List<dynamic>;
      final holidaysData = results[3] as List<dynamic>;
      final settingsData = results[4] as List<dynamic>;

      // Resolve Market Status Logic
      _resolveMarketStatus(holidaysData, settingsData);

      _liveStocks.clear();
      _indices.clear();
      for (var row in liveData) {
        String ticker = row['ticker'].toString().toUpperCase();
        if (ticker == 'KSE100' || ticker == 'KMI30') {
          _indices[ticker] = row as Map<String, dynamic>;
        } else {
          _liveStocks[ticker] = row as Map<String, dynamic>;
        }
      }

      List<Map<String, dynamic>> cleanedMasterFunds = [];
      Set<String> amcSet = {};
      Set<String> catSet = {};
      
      for (var fund in fundsData) {
        String rawCat = fund['category']?.toString().trim() ?? '';
        String rawAmc = fund['amc_name']?.toString().trim() ?? '';
        String rawName = fund['fund_name']?.toString() ?? 'Unknown';
        
        bool isShariah = (fund['is_shariah'] == 1 || fund['is_shariah'] == '1' || fund['is_shariah'] == true);

        String cleanCat = categoryMap[rawCat] ?? rawCat;
        String cleanAmc = amcMap[rawAmc] ?? rawAmc;
        String cleanName = _cleanFundName(rawName);

        if (cleanCat == 'Crypto' || rawCat.toUpperCase().contains('VPS') || cleanCat.toUpperCase().contains('VPS')) continue;

        cleanedMasterFunds.add({
          ...fund,
          'category': cleanCat,
          'amc_name': cleanAmc,
          'fund_name': cleanName,
          'is_shariah': isShariah, 
        });

        if (cleanAmc.isNotEmpty) amcSet.add(cleanAmc);
        if (cleanCat.isNotEmpty) catSet.add(cleanCat);
      }
      
      _masterFunds = cleanedMasterFunds;
      _amcs = ['All', ...amcSet.toList()..sort()];
      _categories = ['All', ...catSet.toList()..sort()];

      Map<String, DateTime> latestDatePerFund = {};
      for (var h in holdingsData) {
        String fTicker = h['fund_ticker'].toString();
        DateTime hDate = DateTime.tryParse(h['fmr_date'].toString()) ?? DateTime(1970);
        if (!latestDatePerFund.containsKey(fTicker) || hDate.isAfter(latestDatePerFund[fTicker]!)) {
          latestDatePerFund[fTicker] = hDate;
        }
      }

      _latestHoldingsByFund.clear();
      for (var h in holdingsData) {
        String fTicker = h['fund_ticker'].toString();
        DateTime hDate = DateTime.tryParse(h['fmr_date'].toString()) ?? DateTime(1970);
        
        if (hDate.isAtSameMomentAs(latestDatePerFund[fTicker]!)) {
          if (!_latestHoldingsByFund.containsKey(fTicker)) {
            _latestHoldingsByFund[fTicker] = [];
          }
          _latestHoldingsByFund[fTicker]!.add(h as Map<String, dynamic>);
        }
      }

      _calculateEstimations();

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Network error. Please check your connection.";
          _isLoading = false;
        });
      }
    }
  }

  // --- MARKET STATUS ENGINE ---
  void _resolveMarketStatus(List<dynamic> holidaysData, List<dynamic> settingsData) {
    // 1. Get settings
    String override = 'AUTO';
    bool isRamazan = false;
    for (var s in settingsData) {
      if (s['setting_key'] == 'market_status_override') override = s['setting_value'].toString().toUpperCase();
      if (s['setting_key'] == 'ramazan_timings') isRamazan = s['setting_value'].toString().toUpperCase() == 'TRUE';
    }

    // 2. PKT Conversion & Time Math
    DateTime utcNow = DateTime.now().toUtc();
    DateTime pktNow = utcNow.add(const Duration(hours: 5));
    String todayStr = DateFormat('yyyy-MM-dd').format(pktNow);
    double hourDecimal = pktNow.hour + (pktNow.minute / 60.0);

    // 3. Calendar Check
    bool isWeekend = pktNow.weekday == DateTime.saturday || pktNow.weekday == DateTime.sunday;
    bool isHoliday = holidaysData.any((h) => h['holiday_date'].toString() == todayStr);

    void setStatus(bool isOpen) {
      _marketStatusText = isOpen ? 'Market ON' : 'Market OFF';
      _marketStatusColor = isOpen ? Colors.greenAccent : Colors.redAccent;
    }

    if (override == 'CLOSED') {
      setStatus(false);
      return;
    } else if (override == 'OPEN') {
      setStatus(true);
      return;
    }

    if (isWeekend || isHoliday) {
      setStatus(false);
      return;
    }

    // Time Check
    if (isRamazan) {
      // Ramazan: 9:00 AM - 1:30 PM (Mon-Thu), 9:00 AM - 12:30 PM (Fri)
      if (pktNow.weekday == DateTime.friday) {
         setStatus(hourDecimal >= 9.0 && hourDecimal <= 12.5);
      } else {
         setStatus(hourDecimal >= 9.0 && hourDecimal <= 13.5);
      }
    } else {
      // Standard: 9:30 AM - 3:30 PM (Mon-Thu), Friday split
      if (pktNow.weekday == DateTime.friday) {
        setStatus((hourDecimal >= 9.5 && hourDecimal <= 12.0) || (hourDecimal >= 14.5 && hourDecimal <= 16.5));
      } else {
        setStatus(hourDecimal >= 9.5 && hourDecimal <= 15.5);
      }
    }
  }

  void _calculateEstimations() {
    _estimatedFunds.clear();
    double kse100Change = double.tryParse(_indices['KSE100']?['change_percent']?.toString() ?? '0') ?? 0.0;
    double kmi30Change = double.tryParse(_indices['KMI30']?['change_percent']?.toString() ?? '0') ?? 0.0;
    double dailyCashYield = 10.0 / 365.0; 

    for (var fund in _masterFunds) {
      String ticker = fund['ticker'].toString();
      if (!_latestHoldingsByFund.containsKey(ticker)) continue;
      
      bool isShariah = fund['is_shariah'] == true;
      double proxyIndexChange = isShariah ? kmi30Change : kse100Change;

      List<Map<String, dynamic>> holdings = _latestHoldingsByFund[ticker]!;
      double totalEstimatedReturnPercent = 0.0;
      double totalMappedWeight = 0.0;
      int mappedStocksCount = 0;

      for (var holding in holdings) {
        String stockTicker = holding['stock_ticker'].toString().toUpperCase();
        double holdingPercent = double.tryParse(holding['holding_percentage'].toString()) ?? 0.0;
        
        if (_liveStocks.containsKey(stockTicker)) {
          double stockLiveChangePct = double.tryParse(_liveStocks[stockTicker]!['change_percent'].toString()) ?? 0.0;
          totalEstimatedReturnPercent += (holdingPercent / 100.0) * stockLiveChangePct;
          totalMappedWeight += holdingPercent;
          mappedStocksCount++;
        } else if (stockTicker == 'CASH') {
          totalEstimatedReturnPercent += (holdingPercent / 100.0) * dailyCashYield;
          totalMappedWeight += holdingPercent;
        } else if (stockTicker == 'OTHER') {
          totalEstimatedReturnPercent += (holdingPercent / 100.0) * proxyIndexChange;
          totalMappedWeight += holdingPercent;
        }
      }

      if (mappedStocksCount > 0) {
        if (totalMappedWeight > 0 && totalMappedWeight < 100) {
          totalEstimatedReturnPercent = totalEstimatedReturnPercent * (100.0 / totalMappedWeight);
        }

        _estimatedFunds.add({
          ...fund,
          'estimated_percent': totalEstimatedReturnPercent,
          'mapped_stocks': mappedStocksCount,
        });
      }
    }

    _applyFilters();
  }

  void _applyFilters() {
    List<Map<String, dynamic>> temp = _estimatedFunds;

    if (_selectedAmc != 'All') temp = temp.where((f) => f['amc_name'] == _selectedAmc).toList();
    if (_selectedCategory != 'All') temp = temp.where((f) => f['category'] == _selectedCategory).toList();

    temp.sort((a, b) => (b['estimated_percent'] as double).compareTo(a['estimated_percent'] as double));

    setState(() {
      _filteredEstimatedFunds = temp;
      _isLoading = false;
    });
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true, dropdownColor: const Color(0xFF1E293B), icon: const Icon(Icons.keyboard_arrow_down, color: Colors.tealAccent),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), value: value,
              items: items.map((String item) { return DropdownMenuItem<String>(value: item, child: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis)); }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIndexCard(String title, Map<String, dynamic>? data) {
    if (data == null) return const SizedBox.shrink();

    double current = double.tryParse(data['current_price'].toString()) ?? 0.0;
    double change = double.tryParse(data['change'].toString()) ?? 0.0;
    double changePct = double.tryParse(data['change_percent'].toString()) ?? 0.0;
    
    bool isPositive = change >= 0;
    Color color = isPositive ? Colors.greenAccent : Colors.redAccent.shade200;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(NumberFormat('#,##0.00').format(current), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(isPositive ? Icons.arrow_upward : Icons.arrow_downward, color: color, size: 12),
                const SizedBox(width: 4),
                Text('${changePct.abs().toStringAsFixed(2)}%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_rounded, color: Colors.tealAccent),
              SizedBox(width: 8),
              Text('Live Fund Estimator', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
          centerTitle: true, backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.white),
          flexibleSpace: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.black.withOpacity(0.2)))),
        ),
        body: Container(
          width: double.infinity, height: double.infinity,
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF000000)])),
          child: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)))
                    : CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Center(child: Text('Your Investment Value', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600))),
                                  Center(
                                    child: IntrinsicWidth(
                                      child: TextField(
                                        controller: _investmentController, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [IndianNumberFormatter()], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, height: 1.2), decoration: const InputDecoration(prefixText: 'PKR ', prefixStyle: TextStyle(color: Colors.tealAccent, fontSize: 20, fontWeight: FontWeight.w700), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                        onChanged: (val) { setState(() { _investmentAmount = double.tryParse(val.replaceAll(',', '')) ?? 0.0; }); },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Expanded(child: _buildDropdown('AMC', _selectedAmc, _amcs, (v) { setState(() => _selectedAmc = v!); _applyFilters(); })),
                                      const SizedBox(width: 12),
                                      Expanded(child: _buildDropdown('Category', _selectedCategory, _categories, (v) { setState(() => _selectedCategory = v!); _applyFilters(); })),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // 🚨 NEW: THE MARKET STATUS BADGE!
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Live Market Pulse', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: _marketStatusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _marketStatusColor.withOpacity(0.3))),
                                        child: Row(
                                          children: [
                                            Icon(Icons.circle, color: _marketStatusColor, size: 8),
                                            const SizedBox(width: 6),
                                            Text(_marketStatusText, style: TextStyle(color: _marketStatusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _buildIndexCard('KSE-100', _indices['KSE100']),
                                      const SizedBox(width: 12),
                                      _buildIndexCard('KMI-30', _indices['KMI30']),
                                    ],
                                  ),
                                  const SizedBox(height: 32),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Estimated Returns', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                      Text('${_filteredEstimatedFunds.length} Funds', style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 0),
                            sliver: _filteredEstimatedFunds.isEmpty
                                ? const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No funds match this filter.", style: TextStyle(color: Colors.white54)))))
                                : SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final fund = _filteredEstimatedFunds[index];
                                        double estPercent = fund['estimated_percent'] as double;
                                        double estPkr = _investmentAmount * (estPercent / 100.0);
                                        
                                        bool isShariah = fund['is_shariah'] == true;
                                        bool isPositive = estPercent >= 0;
                                        Color pColor = isPositive ? Colors.greenAccent : Colors.redAccent.shade200;

                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('${fund['fund_name']}${isShariah ? " 🕌" : ""}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                                                    const SizedBox(height: 6),
                                                    // 🚨 REMOVED the "based on X stocks" text here!
                                                    Text('${fund['amc_name']}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text('${isPositive ? '+' : ''}PKR ${_currencyFormat.format(estPkr.abs())}', style: TextStyle(color: pColor, fontSize: 15, fontWeight: FontWeight.bold)),
                                                  const SizedBox(height: 4),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: pColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                                    child: Text('${isPositive ? '+' : ''}${estPercent.toStringAsFixed(2)}%', style: TextStyle(color: pColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      childCount: _filteredEstimatedFunds.length,
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