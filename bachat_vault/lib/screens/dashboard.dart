import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with AutomaticKeepAliveClientMixin {
  final SupabaseClient supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _allFunds = [];
  Map<String, dynamic> _benchmarkStats = {}; 
  
  double _investmentAmount = 100000.0;
  final TextEditingController _investmentController = TextEditingController(text: '1,00,000');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0);
  final PageController _pageController = PageController(viewportFraction: 0.92);

  String _selectedDashboardPeriod = '1Y';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _investmentController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $urlString'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _fetchData() async {
    setState(() { _isLoading = true; _errorMessage = null; });

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
      'Index Tracker': 'Index Tracker', 'Shariah Compliant Index Tracker': 'Index Tracker', 'Index': 'Index Tracker',
      'Shariah Compliant Commodities': 'Commodities',
      'Exchange Traded Fund': 'Exchange Traded Fund', 'Shariah Compliant Exchange Traded Fund': 'Exchange Traded Fund',
      'VPS-Money Market': 'VPS-Money Market', 'VPS-Shariah Compliant Money Market': 'VPS-Money Market',
      'VPS-Debt': 'VPS-Debt', 'VPS-Shariah Compliant Debt': 'VPS-Debt',
      'VPS-Commodities / Gold': 'VPS-Commodities', 'VPS-Shariah Compliant Commodities / Gold': 'VPS-Commodities',
      'VPS-Equity': 'VPS-Equity', 'VPS-Shariah Compliant Equity': 'VPS-Equity',
      'Dedicated Equity': 'Dedicated Equity', 'Shariah Compliant Dedicated Equity': 'Dedicated Equity',
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
      'Pak Oman Asset Management Company Limited': 'Pak Oman Asset Management', 'Pak-Qatar Asset Management Company Limited': 'Pak Qatar Asset Management', 'EFU Life Insurance Limited': 'EFU Life Insurance',
      'UBL Fund Managers Limited': 'UBL Funds',
    };

    try {
      final masterResponse = await supabase.from('master_funds').select();
      final statsResponse = await supabase.from('performance_stats').select('ticker, return_1d, return_30d, return_1y, return_3y, return_5y, return_10y, return_15y, return_20y, ter_mtd, ter_ytd, last_validity_date');

      _benchmarkStats['KSE100'] = statsResponse.firstWhere((s) => s['ticker'] == 'KSE100', orElse: () => <String, dynamic>{});
      _benchmarkStats['KMI30'] = statsResponse.firstWhere((s) => s['ticker'] == 'KMI30', orElse: () => <String, dynamic>{});
      _benchmarkStats['GOLD_24K'] = statsResponse.firstWhere((s) => s['ticker'] == 'GOLD_24K', orElse: () => <String, dynamic>{});
      _benchmarkStats['CPI_PK'] = statsResponse.firstWhere((s) => s['ticker'] == 'CPI_PK', orElse: () => <String, dynamic>{});

      final List<Map<String, dynamic>> combined = [];

      for (var mf in masterResponse) {
        final ticker = mf['ticker'];
        final stats = statsResponse.firstWhere((s) => s['ticker'] == ticker, orElse: () => <String, dynamic>{});

        final rawCat = mf['category']?.toString().trim() ?? '';
        final rawAmc = mf['amc_name']?.toString().trim() ?? '';

        combined.add({
          ...mf,
          'category': categoryMap[rawCat] ?? rawCat,
          'amc_name': amcMap[rawAmc] ?? rawAmc,
          'return_1d': stats['return_1d'], 'return_30d': stats['return_30d'], 'return_1y': stats['return_1y'],
          'return_3y': stats['return_3y'], 'return_5y': stats['return_5y'], 'return_10y': stats['return_10y'],
          'return_15y': stats['return_15y'], 'return_20y': stats['return_20y'],
          'ter_mtd': stats['ter_mtd'], 'ter_ytd': stats['ter_ytd'], 'last_validity_date': stats['last_validity_date'],
        });
      }
      setState(() { _allFunds = combined; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _errorMessage = e.toString(); _isLoading = false; });
    }
  }

  String _getGreetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 20) return 'Good Evening';
    return 'Good Night';
  }

  String _getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️';
    if (hour < 17) return '🌤️';
    if (hour < 20) return '🌙';
    return '🌙';
  }

  List<Map<String, dynamic>> _getTop5Funds(List<String> categories, String sortKey) {
    var filtered = _allFunds.where((f) {
      final cat = f['category']?.toString().trim() ?? '';
      return categories.contains(cat) && f[sortKey] != null;
    }).toList();
    if (filtered.isEmpty) return [];

    String latestDateStr = "";
    for (var f in filtered) {
      final d = f['last_validity_date']?.toString() ?? "";
      if (d.compareTo(latestDateStr) > 0) latestDateStr = d;
    }

    filtered = filtered.where((f) => f['last_validity_date']?.toString() == latestDateStr).toList();
    filtered.sort((a, b) {
      final valA = (a[sortKey] as num).toDouble();
      final valB = (b[sortKey] as num).toDouble();
      return valB.compareTo(valA);
    });

    return filtered.take(5).toList();
  }

  Widget _buildDashFilterBtn(String label) {
    final isSelected = _selectedDashboardPeriod == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedDashboardPeriod = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.tealAccent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.tealAccent : Colors.white.withOpacity(0.2)),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.tealAccent : Colors.white70, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500, fontSize: 13)),
      ),
    );
  }

  Widget _buildTop5Card(String title, List<String> categories, String sortKey) {
    final topFunds = _getTop5Funds(categories, sortKey);

    return Align(
      alignment: Alignment.topCenter, // Stops the card from stretching to the bottom
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05), 
          borderRadius: BorderRadius.circular(24), 
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.tealAccent.withOpacity(0.1), Colors.transparent]),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Hugs the content tightly
          children: [
            Text(title, style: const TextStyle(color: Colors.tealAccent, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            const SizedBox(height: 16),
            if (topFunds.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text("No funds available.", style: TextStyle(color: Colors.white54))))
            else
              // Removed Expanded() and added shrinkWrap!
              ListView.separated(
                shrinkWrap: true, // Tells the list to only take up exact space needed
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topFunds.length,
                separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 24),
                itemBuilder: (context, index) {
                  final fund = topFunds[index];
                  final name = fund['fund_name'] ?? 'Unknown';
                  final isShariah = (fund['is_shariah'] == 1 || fund['is_shariah'] == '1' || fund['is_shariah'] == true);
                  final dateStr = fund['last_validity_date'] != null ? DateFormat('dd MMM yyyy').format(DateTime.tryParse(fund['last_validity_date'].toString()) ?? DateTime.now()) : 'N/A';
                  
                  final returnFactor = (fund[sortKey] as num).toDouble();
                  final double profitValue = _investmentAmount * (returnFactor - 1.0);
                  
                  String profitString = _currencyFormat.format(profitValue.abs());
                  String displayProfit = profitValue >= 0 ? '+$profitString' : '-$profitString';
                  Color profitColor = profitValue >= 0 ? Colors.greenAccent : Colors.redAccent.shade100;

                  return InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FundDetailsScreen(fund: fund, investmentAmount: _investmentAmount, benchmarkStats: _benchmarkStats))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('$name${isShariah ? " 🕌" : ""}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(displayProfit, style: TextStyle(color: profitColor, fontSize: 14, fontWeight: FontWeight.bold)),
                            Text(dateStr, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // MARKET OVERVIEW SECTION (Dynamic Data & Centered)
  // ============================================================================
  
  double _getDynamicReturn(String ticker, String dbKey) {
    final stat = _benchmarkStats[ticker];
    if (stat == null || stat[dbKey] == null) return 0.0;
    return ((stat[dbKey] as num).toDouble() - 1.0) * 100.0;
  }

  Widget _buildMarketCard(String title, String subtitle, double percentChange, IconData icon, Color iconColor) {
    bool isPositive = percentChange >= 0;
    Color statColor = isPositive ? Colors.greenAccent : Colors.redAccent.shade100;
    String sign = isPositive ? '+' : '';

    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: iconColor, size: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: statColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$sign${percentChange.toStringAsFixed(2)}%',
                  style: TextStyle(color: statColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMarketOverviewSection(String periodLabel, String dbKey) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'Market Benchmarks ($periodLabel)', 
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Container(
            constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMarketCard('KSE 100', 'PSX Index', _getDynamicReturn('KSE100', dbKey), Icons.show_chart, Colors.blueAccent),
                const SizedBox(width: 12),
                _buildMarketCard('KMI 30', 'Islamic Index', _getDynamicReturn('KMI30', dbKey), Icons.mosque_outlined, Colors.green),
                const SizedBox(width: 12),
                _buildMarketCard('Gold', 'Per Tola', _getDynamicReturn('GOLD_24K', dbKey), Icons.circle, Colors.amberAccent),
              ],
            ),
          ),
        ),
      ],
    );
  }
  // ============================================================================

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.tealAccent, size: 22),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    String dbSortKey = _selectedDashboardPeriod == '30D' ? 'return_30d' : _selectedDashboardPeriod == '3Y' ? 'return_3y' : 'return_1y';

    return Theme(
      data: Theme.of(context).copyWith(textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        drawer: Drawer(
          backgroundColor: const Color(0xFF0F172A),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  border: Border(bottom: BorderSide(color: Colors.tealAccent, width: 2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Image.asset('assets/app_logo.png', width: 64, height: 64, errorBuilder: (c,e,s) => const Icon(Icons.account_balance_wallet, color: Colors.tealAccent, size: 48)),
                    const SizedBox(height: 12),
                    const Text('Bachat Vault', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const Text('Version 1.0.0', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              _buildDrawerItem(Icons.menu_book_rounded, 'Investment Guide', () { }),
              const Divider(color: Colors.white12),
              Padding(padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8), child: Text('COMMUNITIES', style: TextStyle(color: Colors.tealAccent.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2))),
              _buildDrawerItem(Icons.facebook_rounded, 'Facebook Page', () => _launchURL('https://www.facebook.com/MFInvestment')),
              _buildDrawerItem(Icons.groups_rounded, 'Facebook Group', () => _launchURL('https://www.facebook.com/groups/2125880957874842')),
              _buildDrawerItem(Icons.chat_rounded, 'WhatsApp Group', () => _launchURL('https://chat.whatsapp.com/HHUBK1TR6h918qOlfx4n4v?mode=gi_t')),
              _buildDrawerItem(Icons.campaign_rounded, 'WhatsApp Channel', () => _launchURL('https://whatsapp.com/channel/0029Vb7Nr1k1t90jrhhvPp3j')),
              _buildDrawerItem(Icons.camera_alt_rounded, 'Instagram', () => _launchURL('https://www.instagram.com/mfi_pakistan/')),
              _buildDrawerItem(Icons.smart_display_rounded, 'YouTube Channel', () => _launchURL('https://www.youtube.com/@the_mixedb4g')),
              const Divider(color: Colors.white12),
              _buildDrawerItem(Icons.settings_rounded, 'App Settings', () { }),
              _buildDrawerItem(Icons.gavel_rounded, 'Terms & Conditions', () { }),
            ],
          ),
        ),
        appBar: AppBar(
          title: Row(mainAxisSize: MainAxisSize.min, children: [Text(_getGreetingText(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)), const SizedBox(width: 8), AnimatedEmoji(emoji: _getGreetingEmoji())]),
          centerTitle: false, backgroundColor: Colors.transparent, elevation: 0,
          actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _fetchData)],
          flexibleSpace: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.black.withOpacity(0.2)))),
        ),
        body: Container(
          width: double.infinity, height: double.infinity,
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF000000)])),
          child: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
                : _errorMessage != null
                    ? Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.redAccent)))
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            const Center(child: Text('Your Investment Value', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                              child: Center(
                                child: IntrinsicWidth(
                                  child: TextField(
                                    controller: _investmentController, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [IndianNumberFormatter()], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800), decoration: const InputDecoration(prefixText: 'PKR ', prefixStyle: TextStyle(color: Colors.tealAccent, fontSize: 24, fontWeight: FontWeight.w700), border: InputBorder.none),
                                    onChanged: (val) { setState(() { _investmentAmount = double.tryParse(val.replaceAll(',', '')) ?? 0.0; }); },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [_buildDashFilterBtn('30D'), const SizedBox(width: 12), _buildDashFilterBtn('1Y'), const SizedBox(width: 12), _buildDashFilterBtn('3Y')],
                            ),
                            const SizedBox(height: 24),
                            
                            SizedBox(
                              height: 440,
                              child: PageView(
                                controller: _pageController,
                                physics: const BouncingScrollPhysics(),
                                children: [
                                  _buildTop5Card('Top 5 Equity Funds', ['Equity'], dbSortKey),
                                  _buildTop5Card('Top 5 ETFs', ['Exchange Traded Fund'], dbSortKey),
                                  _buildTop5Card('Top 5 Money Market', ['Money Market'], dbSortKey),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // PERFECTLY UPDATED FUNCTION CALL:
                            _buildMarketOverviewSection(_selectedDashboardPeriod, dbSortKey),
                            const SizedBox(height: 24),

                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: InkWell(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FullPerformanceScreen(allFunds: _allFunds, initialInvestment: _investmentAmount, benchmarkStats: _benchmarkStats))),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.tealAccent, Colors.teal], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.tealAccent.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]),
                                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.analytics_outlined, color: Colors.black87), SizedBox(width: 8), Text('Explore Full Performance', style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w800))]),
                                ),
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

// ============================================================================
// PHASE 3: FULL PERFORMANCE SCREEN
// ============================================================================

class FullPerformanceScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allFunds;
  final double initialInvestment;
  final Map<String, dynamic> benchmarkStats;

  const FullPerformanceScreen({super.key, required this.allFunds, required this.initialInvestment, required this.benchmarkStats});

  @override
  State<FullPerformanceScreen> createState() => _FullPerformanceScreenState();
}

class _FullPerformanceScreenState extends State<FullPerformanceScreen> {
  late double _investmentAmount;
  late TextEditingController _investmentController;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0);

  List<String> _categories = ['All'];
  List<String> _amcs = ['All'];
  String _selectedCategory = 'All';
  String _selectedAmc = 'All';
  String _selectedPeriod = '1D';

  @override
  void initState() {
    super.initState();
    _investmentAmount = widget.initialInvestment;
    _investmentController = TextEditingController(text: _currencyFormat.format(_investmentAmount));
    _setupFilters();
  }

  @override
  void dispose() { _investmentController.dispose(); super.dispose(); }

  void _setupFilters() {
    final Set<String> categorySet = {};
    final Set<String> amcSet = {};
    for (var mf in widget.allFunds) {
      final cat = mf['category']; if (cat != null && cat.toString().isNotEmpty) categorySet.add(cat.toString().trim());
      final amc = mf['amc_name']; if (amc != null && amc.toString().isNotEmpty) amcSet.add(amc.toString().trim());
    }
    setState(() { _categories = ['All', ...categorySet.toList()..sort()]; _amcs = ['All', ...amcSet.toList()..sort()]; });
  }

  String _getSortKey() {
    switch (_selectedPeriod) {
      case '1D': return 'return_1d'; 
      case '30D': return 'return_30d'; 
      case '1Y': return 'return_1y';
      case '3Y': return 'return_3y'; 
      case '5Y': return 'return_5y'; 
      case '10Y': return 'return_10y';
      case '15Y': return 'return_15y'; 
      case '20Y': return 'return_20y'; 
      case 'MTD': return 'return_30d'; 
      case 'YTD': return 'return_1y'; 
      default: return 'return_1d';
    }
  }

  List<Map<String, dynamic>> _getFilteredAndSortedFunds() {
    final sortKey = _getSortKey();
    var filtered = widget.allFunds.where((f) => f[sortKey] != null).toList();
    if (_selectedCategory != 'All') filtered = filtered.where((f) => f['category']?.toString().trim() == _selectedCategory).toList();
    if (_selectedAmc != 'All') filtered = filtered.where((f) => f['amc_name']?.toString().trim() == _selectedAmc).toList();
    filtered.sort((a, b) { final valA = (a[sortKey] as num).toDouble(); final valB = (b[sortKey] as num).toDouble(); return valB.compareTo(valA); });
    return filtered;
  }

  Widget _buildFilterButton(String label) {
    final isSelected = _selectedPeriod == label;
    return GestureDetector(
      onTap: () { setState(() { _selectedPeriod = label; }); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? Colors.tealAccent.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected ? Colors.tealAccent : Colors.white.withOpacity(0.2), width: 1)),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.tealAccent : Colors.white70, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500, fontSize: 11)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedFunds = _getFilteredAndSortedFunds();
    final sortKey = _getSortKey();

    return Theme(
      data: Theme.of(context).copyWith(textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Full Performance', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)), backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.white),
          // --- NEW COMPARE BUTTON ---
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CompareFundsScreen(
                    allFunds: widget.allFunds,
                    investmentAmount: _investmentAmount,
                    benchmarkStats: widget.benchmarkStats,
                    initialPeriod: _selectedPeriod,
                  )));
                },
                icon: const Icon(Icons.compare_arrows_rounded, color: Colors.tealAccent),
                label: const Text('Compare Funds', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                style: TextButton.styleFrom(backgroundColor: Colors.tealAccent.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              ),
            )
          ],
          // --------------------------
          flexibleSpace: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.black.withOpacity(0.2)))),
        ),
        body: Container(
          width: double.infinity, height: double.infinity,
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF000000)])),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Investment Amount', style: TextStyle(color: Colors.white70, fontSize: 11)), const SizedBox(height: 4),
                                SizedBox(
                                  height: 48,
                                  child: TextField(
                                    controller: _investmentController, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [IndianNumberFormatter()], textAlignVertical: TextAlignVertical.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    decoration: InputDecoration(prefixText: 'PKR ', prefixStyle: const TextStyle(color: Colors.tealAccent, fontSize: 14, fontWeight: FontWeight.bold), filled: true, fillColor: Colors.white.withOpacity(0.1), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12)),
                                    onChanged: (val) { setState(() { _investmentAmount = double.tryParse(val.replaceAll(',', '')) ?? 0.0; }); },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('AMC Name', style: TextStyle(color: Colors.white70, fontSize: 11)), const SizedBox(height: 4),
                                Container(
                                  height: 48, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedAmc, isExpanded: true, dropdownColor: const Color(0xFF203A43), menuMaxHeight: 350, icon: const Icon(Icons.arrow_drop_down, color: Colors.tealAccent), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500), isDense: true,
                                      items: _amcs.map((amc) => DropdownMenuItem<String>(value: amc, child: Text(amc, maxLines: 2, overflow: TextOverflow.visible, style: const TextStyle(fontSize: 13)))).toList(),
                                      onChanged: (val) { if (val != null) setState(() { _selectedAmc = val; }); },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Category', style: TextStyle(color: Colors.white70, fontSize: 12)), const SizedBox(height: 4),
                      Container(
                        height: 48, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategory, isExpanded: true, dropdownColor: const Color(0xFF203A43), menuMaxHeight: 350, icon: const Icon(Icons.arrow_drop_down, color: Colors.tealAccent), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), isDense: true,
                            items: _categories.map((cat) => DropdownMenuItem<String>(value: cat, child: Text(cat, maxLines: 2, overflow: TextOverflow.visible))).toList(),
                            onChanged: (val) { if (val != null) setState(() { _selectedCategory = val; }); },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: ['1D', 'MTD', '30D', 'YTD', '1Y', '3Y', '5Y', '10Y', '15Y', '20Y']
                              .asMap()
                              .entries
                              .map((entry) {
                            return Padding(
                              padding: EdgeInsets.only(right: entry.key != 10 ? 8.0 : 0.0),
                              child: _buildFilterButton(entry.value),
                            );
                          }).toList(),
                        ),
                      ),
                      
                    ],
                  ),
                ),
                const SizedBox(height: 4), const Divider(color: Colors.white24, height: 1),
                Expanded(
                  child: displayedFunds.isEmpty
                      ? const Center(child: Text('No funds found for this timeframe.', style: TextStyle(color: Colors.white70)))
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 40, left: 16, right: 16), physics: const BouncingScrollPhysics(), itemCount: displayedFunds.length,
                          itemBuilder: (context, index) {
                            final fund = displayedFunds[index];
                            final fundName = fund['fund_name'] ?? 'Unknown Fund';
                            final amcName = fund['amc_name'] ?? '';
                            final category = fund['category'] ?? '';
                            final riskProfile = fund['risk_profile'] ?? '';
                            final isShariah = (fund['is_shariah'] == 1 || fund['is_shariah'] == '1' || fund['is_shariah'] == true);
                            final returnFactor = (fund[sortKey] as num).toDouble();
                            final double percent = (returnFactor - 1.0) * 100.0;
                            final double profitValue = _investmentAmount * (returnFactor - 1.0);
                            
                            String profitString = _currencyFormat.format(profitValue.abs());
                            String formattedValueDisplay = profitValue > 0 ? '+$profitString' : profitValue < 0 ? '-$profitString' : '0';
                            String percentageString = '${percent > 0 ? '+' : ''}${percent.toStringAsFixed(2)}%';
                            Color statColor = percent > 0 ? Colors.greenAccent : percent < 0 ? Colors.redAccent.shade100 : Colors.white70;

                            final lastValidityDate = fund['last_validity_date'] != null ? DateFormat('dd MMM yyyy').format(DateTime.tryParse(fund['last_validity_date'].toString()) ?? DateTime.now()) : 'N/A';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FundDetailsScreen(fund: fund, investmentAmount: _investmentAmount, benchmarkStats: widget.benchmarkStats))),
                                child: Container(
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1), width: 1)),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 6, child: Text(amcName.toString().toUpperCase(), style: const TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis)), const SizedBox(width: 8), Expanded(flex: 4, child: fund['last_validity_date'] != null ? Text('Validity Date: $lastValidityDate', textAlign: TextAlign.right, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w500)) : const SizedBox.shrink())]),
                                            const SizedBox(height: 6),
                                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 6, child: Text('$fundName${isShariah ? " 🕌" : ""}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis)), const SizedBox(width: 8), Expanded(flex: 4, child: Text(formattedValueDisplay, textAlign: TextAlign.right, style: TextStyle(color: statColor, fontSize: 15, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])))]),
                                            const SizedBox(height: 6),
                                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(flex: 6, child: Row(children: [if (riskProfile.toString().isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text('Risk: $riskProfile', style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600))), Expanded(child: Text(category.toString(), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis))])), const SizedBox(width: 8), Expanded(flex: 4, child: Text('($percentageString)', textAlign: TextAlign.right, style: TextStyle(color: statColor, fontSize: 11, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])))])
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// THE DEEP DIVE SCREEN (ADDED CAGR & BENCHMARKS)
// ============================================================================

class FundDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> fund;
  final double investmentAmount;
  final Map<String, dynamic> benchmarkStats;

  const FundDetailsScreen({super.key, required this.fund, required this.investmentAmount, required this.benchmarkStats});

  bool _isPeriodValid(String? inceptionDateStr, int requiredDays) {
    if (inceptionDateStr == null || inceptionDateStr.isEmpty) return true;
    DateTime? incDate = DateTime.tryParse(inceptionDateStr);
    if (incDate == null) return true;
    final diff = DateTime.now().difference(incDate).inDays;
    return diff >= requiredDays;
  }

  String _formatBenchmarkCagr(String ticker, String dbKey, int years) {
    final stat = benchmarkStats[ticker];
    if (stat == null || stat[dbKey] == null) return 'N/A';
    final growth = (stat[dbKey] as num).toDouble();
    double cagrPercent = (math.pow(growth, 1.0 / years) - 1.0) * 100;
    return '${cagrPercent >= 0 ? '+' : ''}${cagrPercent.toStringAsFixed(2)}%';
  }

  Widget _buildReturnRow(String label, String dbKey, int requiredDays, {int? years, bool isShariah = false}) {
    final rawValue = fund[dbKey];
    final inception = fund['inception_date']?.toString();
    final NumberFormat currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0);

    if (rawValue == null || !_isPeriodValid(inception, requiredDays)) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)), const Text('-', style: TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.bold))]));
    }

    final double returnFactor = (rawValue as num).toDouble();
    final double percent = (returnFactor - 1.0) * 100.0;
    final double profitValue = investmentAmount * (returnFactor - 1.0);

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

  @override
  Widget build(BuildContext context) {
    final fundName = fund['fund_name'] ?? 'Unknown Fund';
    final amcName = fund['amc_name'] ?? 'Unknown AMC';
    final isShariah = (fund['is_shariah'] == 1 || fund['is_shariah'] == '1' || fund['is_shariah'] == true);
    final category = fund['category'] ?? 'N/A';
    final risk = fund['risk_profile'] ?? 'N/A';
    final inceptionRaw = fund['inception_date'];
    final incDateStr = inceptionRaw != null ? DateFormat('dd MMM yyyy').format(DateTime.tryParse(inceptionRaw.toString()) ?? DateTime.now()) : 'N/A';
    final terMtd = fund['ter_mtd'] != null ? '${fund['ter_mtd']}%' : 'N/A';
    final terYtd = fund['ter_ytd'] != null ? '${fund['ter_ytd']}%' : 'N/A';

    final String safeAmcName = amcName.toString().toLowerCase().replaceAll(' ', '_');
    final String safeTicker = fund['ticker']?.toString().toLowerCase() ?? '';
    final bool isCrypto = category.toString().toLowerCase() == 'crypto';
    
    // If it's crypto, use the ticker (btc.png). Otherwise, use the AMC name.
    final String logoPath = isCrypto ? 'assets/logos/$safeTicker.png' : 'assets/logos/$safeAmcName.png';

    return Theme(
      data: Theme.of(context).copyWith(textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.white), flexibleSpace: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.black.withOpacity(0.2))))),
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
                        width: 60, height: 60,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            logoPath,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_balance, color: Colors.tealAccent, size: 30),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  Row(children: [_buildInfoPill('Category', category.toString()), const SizedBox(width: 12), _buildInfoPill('Risk Profile', risk.toString())]), const SizedBox(height: 12),
                  Row(children: [_buildInfoPill('Inception Date', incDateStr), const SizedBox(width: 12), _buildInfoPill('TER (MTD)', terMtd), const SizedBox(width: 12), _buildInfoPill('TER (YTD)', terYtd)]), const SizedBox(height: 32),
                  
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
                        _buildReturnRow('15 Years', 'return_15y', 5475, years: 15, isShariah: isShariah), const Divider(color: Colors.white12), 
                        _buildReturnRow('20 Years', 'return_20y', 7300, years: 20, isShariah: isShariah)
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

// ============================================================================
// HELPERS
// ============================================================================

// ============================================================================
// PHASE 5: COMPARE FUNDS SCREEN (POLISHED UI)
// ============================================================================
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
  List<String?> _selectedFundTickers = [null, null]; // Starts with 2 dropdowns
  late String _selectedPeriod;

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    // FIX 2: Force the default selected period to 1Y instead of 1D
    _selectedPeriod = '1Y';
    
    // Extract unique categories (ignoring 'All')
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
        // Removed the margin here so the Wrap widget can center them perfectly
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
    final fundName = fund['fund_name'] ?? 'Unknown Fund';
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.15))),
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
          
          // FIX 3: Centered Historical Returns Section
          const Center(
            child: Text('Historical Returns:', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.center, // Centers the pills
              spacing: 8, runSpacing: 8,
              children: [
                _buildMiniReturnPill('30D', 'return_30d', fund),
                _buildMiniReturnPill('1Y', 'return_1y', fund),
                _buildMiniReturnPill('3Y', 'return_3y', fund),
                _buildMiniReturnPill('5Y', 'return_5y', fund),
                _buildMiniReturnPill('10Y', 'return_10y', fund),
                _buildMiniReturnPill('15Y', 'return_15y', fund),
                _buildMiniReturnPill('20Y', 'return_20y', fund),
              ],
            ),
          )
        ],
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
                                items: availableFunds.map((f) => DropdownMenuItem(value: f['ticker'] as String, child: Text(f['fund_name'] as String, overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (val) { setState(() { _selectedFundTickers[index] = val; }); },
                              ),
                            ),
                          ),
                          if (index >= 2) 
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                              onPressed: () { setState(() { _selectedFundTickers.removeAt(index); }); },
                            )
                        ],
                      ),
                    );
                  }),

                  if (_selectedFundTickers.length < 4)
                    Center(
                      child: TextButton.icon(
                        onPressed: () { setState(() { _selectedFundTickers.add(null); }); },
                        icon: const Icon(Icons.add_circle_outline, color: Colors.tealAccent),
                        label: const Text('Add Another Fund', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  
                  const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white24, height: 1)),

                  // FIX 1: Centered Period Filter Buttons using Wrap
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.center, // Perfect centering
                      spacing: 8, // Horizontal gap
                      runSpacing: 12, // Vertical gap if it drops to a second line
                      children: ['30D', '1Y', '3Y', '5Y', '10Y', '15Y', '20Y'].map((p) => _buildPeriodFilterBtn(p)).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

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

class AnimatedEmoji extends StatefulWidget { final String emoji; const AnimatedEmoji({super.key, required this.emoji}); @override State<AnimatedEmoji> createState() => _AnimatedEmojiState(); }
class _AnimatedEmojiState extends State<AnimatedEmoji> with SingleTickerProviderStateMixin { late AnimationController _controller; @override void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true); } @override void dispose() { _controller.dispose(); super.dispose(); } @override Widget build(BuildContext context) { return SlideTransition(position: Tween<Offset>(begin: const Offset(0, -0.15), end: const Offset(0, 0.15)).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)), child: Text(widget.emoji, style: const TextStyle(fontSize: 22))); } }
class IndianNumberFormatter extends TextInputFormatter { @override TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) { if (newValue.text.isEmpty) return newValue; String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9.]'), ''); if (cleanText.split('.').length > 2) cleanText = oldValue.text.replaceAll(',', ''); if (cleanText.isEmpty) return newValue.copyWith(text: ''); List<String> parts = cleanText.split('.'); String wholeNumber = parts[0]; String decimalPart = parts.length > 1 ? '.${parts[1]}' : ''; if (wholeNumber.isEmpty) return newValue.copyWith(text: cleanText); final formatter = NumberFormat.decimalPattern('en_IN'); String formatted = formatter.format(int.parse(wholeNumber)); String finalString = formatted + decimalPart; return TextEditingValue(text: finalString, selection: TextSelection.collapsed(offset: finalString.length)); } }