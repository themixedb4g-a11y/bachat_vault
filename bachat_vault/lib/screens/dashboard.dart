import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bachat_vault/screens/compare_funds_screen.dart';
import 'package:bachat_vault/screens/fund_details_screen.dart';
import 'package:bachat_vault/screens/full_performance_screen.dart';
import 'package:bachat_vault/screens/financial_journey_screen.dart';
import 'package:bachat_vault/screens/mutual_funds_screen.dart';
import 'package:bachat_vault/screens/pension_funds_screen.dart';
import 'package:bachat_vault/screens/etfs_screen.dart';
import 'package:bachat_vault/screens/overseas_investors_screen.dart';
import 'package:bachat_vault/screens/account_opening_screen.dart';
import 'package:bachat_vault/screens/terms_conditions_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  final SupabaseClient supabase = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _allFunds = [];
  final Map<String, dynamic> _benchmarkStats = {};

  double _investmentAmount = 100000.0;
  final TextEditingController _investmentController = TextEditingController(
    text: '1,00,000',
  );
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '',
    decimalDigits: 0,
  );
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
          SnackBar(
            content: Text('Could not launch $urlString'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // FIX 2: Added a helper function to catch and translate nasty network errors
  String _getFriendlyErrorMessage(dynamic error) {
    String errorString = error.toString();
    if (errorString.contains('CERTIFICATE_VERIFY_FAILED') || errorString.contains('HandshakeException')) {
      return "Secure connection blocked.\nPlease disable your VPN, Ad-Blocker, or check your network and try again.";
    } else if (errorString.contains('SocketException') || errorString.toLowerCase().contains('network') || errorString.toLowerCase().contains('internet')) {
      return "No internet connection.\nPlease check your Wi-Fi or mobile data.";
    } else {
      return "Unable to load data.\nPlease pull down to refresh.";
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      // FIX 3 (Sub-fix): Only show the full screen loading spinner if we don't have data yet.
      // This prevents the screen from going blank when the user pulls down to refresh.
      if (_allFunds.isEmpty) {
        _isLoading = true;
      }
      _errorMessage = null;
    });

    final Map<String, String> categoryMap = {
      'Equity': 'Equity',
      'Shariah Compliant Equity': 'Equity',
      'Money Market': 'Money Market',
      'Shariah Compliant Money Market': 'Money Market',
      'Income': 'Income',
      'Shariah Compliant Income': 'Income',
      'Capital Protected': 'Capital Protected',
      'Shariah Compliant Capital Protected': 'Capital Protected',
      'Capital Protected - Income': 'Capital Protected - Income',
      'Aggressive Fixed Income': 'Aggressive Fixed Income',
      'Shariah Compliant Aggressive Fixed Income': 'Aggressive Fixed Income',
      'Balanced': 'Balanced',
      'Shariah Compliant Balanced': 'Balanced',
      'Asset Allocation': 'Asset Allocation',
      'Shariah Compliant Asset Allocation': 'Asset Allocation',
      'Fund of Funds': 'Fund of Funds',
      'Shariah Compliant Fund of Funds': 'Fund of Funds',
      'Shariah Compliant Fund of Funds - CPPI': 'Fund of Funds',
      'Index Tracker': 'Index Tracker',
      'Shariah Compliant Index Tracker': 'Index Tracker',
      'Index': 'Index',
      'Shariah Compliant Commodities': 'Commodities',
      'Exchange Traded Fund': 'Exchange Traded Fund',
      'Shariah Compliant Exchange Traded Fund': 'Exchange Traded Fund',
      'VPS-Money Market': 'VPS-Money Market',
      'VPS-Shariah Compliant Money Market': 'VPS-Money Market',
      'VPS-Debt': 'VPS-Debt',
      'VPS-Shariah Compliant Debt': 'VPS-Debt',
      'VPS-Commodities / Gold': 'VPS-Commodities',
      'VPS-Shariah Compliant Commodities / Gold': 'VPS-Commodities',
      'VPS-Equity': 'VPS-Equity',
      'VPS-Shariah Compliant Equity': 'VPS-Equity',
      'Dedicated Equity': 'Dedicated Equity',
      'Shariah Compliant Dedicated Equity': 'Dedicated Equity',
    };

    final Map<String, String> amcMap = {
      '786 Investments Limited': '786 Investments',
      'ABL Asset Management Company Limited': 'ABL Funds',
      'AKD Investment Management Limited': 'AKD Investment Management',
      'Al Habib Asset Management Limited': 'Al Habib Asset Management',
      'Al Meezan Investment Management Limited': 'Al Meezan Investments',
      'Alfalah Asset Management Limited': 'Alfalah Asset Management',
      'Atlas Asset Management Limited': 'Atlas Asset Management',
      'AWT Investments Limited': 'AWT Investments',
      'Faysal Asset Management Limited': 'Faysal Funds',
      'First Capital Investments Limited': 'First Capital Investments',
      'HBL Asset Management Limited': 'HBL Asset Management',
      'JS Investments Limited': 'JS Investments',
      'Lakson Investments Limited': 'Lakson Investments',
      'Lucky Investments Limited': 'Lucky Investments',
      'Mahaana Wealth Limited': 'Mahaana Wealth',
      'MCB Investment Management Limited': 'MCB Funds',
      'National Investment Trust Limited': 'National Investment Trust',
      'NBP Fund Management Limited': 'NBP Funds',
      'Pak Oman Asset Management Company Limited': 'Pak Oman Asset Management',
      'Pak-Qatar Asset Management Company Limited': 'Pak Qatar Asset Management',
      'EFU Life Insurance Limited': 'EFU Life Insurance',
      'UBL Fund Managers Limited': 'UBL Funds',
    };

    String _cleanFundName(String name) {
    return name
        .replaceAll('Exchange Traded Fund', 'ETF')
        .replaceAll(
          'NBP Islamic Principal Protection Fund I (NBP Islamic Principal Protection Plan I)',
          'NBP Islamic Principal Protection Plan I',
        )
        .replaceAll(
          'NBP Islamic Principal Protection Fund I (NBP Islamic Principal Protection Plan II)',
          'NBP Islamic Principal Protection Plan II',
        )
        .replaceAll(
          'NBP Islamic Principal Protection Fund I (NBP Islamic Principal Protection Plan III)',
          'NBP Islamic Principal Protection Plan III',
        )
        .replaceAll(
          'NBP Islamic Principal Protection Fund I (NBP Islamic Principal Protection Plan IV)',
          'NBP Islamic Principal Protection Plan IV',
        )
        .replaceAll(
          'Pak-Qatar Asset Allocation Plan I (PQAAP  IA)',
          'Pak Qatar Asset Allocation Plan I',
        )
        .replaceAll(
          'Pak-Qatar Asset Allocation Plan II (PQAAP  IIA)',
          'Pak Qatar Asset Allocation Plan II',
        )
        .replaceAll(
          'Pak-Qatar Asset Allocation Plan III (PQAAP  IIIA)',
          'Pak Qatar Asset Allocation Plan III',
        )
        .replaceAll(
          'Alhamra Opportunity Fund (Dividend Strategy Plan)',
          'Alhamra Opportunity Fund',
        )
        .replaceAll(
          'MCB Pakistan Opportunity Fund (MCB Pakistan  Dividend Yield Plan)',
          'MCB Pakistan Opportunity Fund',
        )
        .replaceAll(
          'JS Islamic Sarmaya Mehfooz Fund (JS Islamic Sarmaya Mehfooz Plan 1)',
          'JS Islamic Sarmaya Mehfooz Plan I',
        )
        .replaceAll(
          'Faysal Islamic Sovereign Fund (Faysal Islamic Sovereign Plan I)',
          'Faysal Islamic Sovereign Plan I',
        )
        .replaceAll(
          'Faysal Islamic Sovereign Fund (Faysal Islamic Sovereign Plan II)',
          'Faysal Islamic Sovereign Plan II',
        )
        .replaceAll(
          "Faysal Khushal Mustaqbil Fund (Faysal Nu�umah Women Savers Plan)",
          "Faysal Nu'umah Women Savers Plan",
        )
        .replaceAll(
          'Faysal Islamic Financial Planning Fund II (Faysal Priority Ascend Plan I)',
          'Faysal Priority Ascend Plan I',
        )
        .replaceAll(
          'Faysal Islamic Financial Planning Fund II (Faysal Priority Ascend Plan II)',
          'Faysal Priority Ascend Plan II',
        )
        .replaceAll(
          'Faysal Islamic Financial Planning Fund II (Faysal Priority Ascend Plan III)',
          'Faysal Priority Ascend Plan III',
        )
        .replaceAll(
          "Faysal Khushal Mustaqbil Fund (Faysal Barak�ah Women Savers Plan)",
          "Faysal Barak'ah Women Savers Plan",
        )
        .replaceAll(
          'Faysal Islamic Asset Allocation Fund III (Faysal Shariah Flex Plan I)',
          'Faysal Shariah Flex Plan I',
        )
        .replaceAll(
          'Faysal Islamic Asset Allocation Fund III (Faysal Shariah Flex Plan II)',
          'Faysal Shariah Flex Plan II',
        )
        .replaceAll(
          'Faysal Islamic Asset Allocation Fund III (Faysal Shariah Flex Plan III)',
          'Faysal Shariah Flex Plan III',
        )
        .replaceAll(
          'Faysal Islamic Financial Growth Fund (Faysal Islamic Financial Growth Plan I)',
          'Faysal Islamic Financial Growth Plan I',
        )
        .replaceAll(
          'Faysal Islamic Financial Growth Fund (Faysal Islamic Financial Growth Plan II)',
          'Faysal Islamic Financial Growth Plan II',
        )
        .replaceAll(
          'Atlas Islamic Fund of Funds (Atlas Aggressive Allocation Islamic Plan)',
          'Atlas Islamic Fund of Funds (Aggressive)',
        )
        .replaceAll(
          'Atlas Islamic Fund of Funds (Atlas Conservative Allocation Islamic Plan)',
          'Atlas Islamic Fund of Funds (Conservative)',
        )
        .replaceAll(
          'Atlas Islamic Fund of Funds (Atlas Moderate Allocation Islamic Plan)',
          'Atlas Islamic Fund of Funds (Moderate)',
        )
        .replaceAll(
          'Alfalah GHP Islamic Prosperity Planning Fund (Alfalah GHP Islamic Moderate Allocation Plan)',
          'Alfalah GHP IPP Fund (Moderate)',
        )
        .replaceAll(
          'Alfalah GHP Islamic Prosperity Planning Fund (Alfalah GHP Islamic Active Allocation Plan II)',
          'Alfalah GHP IPP Fund (Active)',
        )
        .replaceAll(
          'Alfalah GHP Islamic Prosperity Planning Fund (Alfalah GHP Islamic Balance Allocation Plan)',
          'Alfalah GHP IPP Fund (Balance)',
        )
        .replaceAll(
          'Alfalah GHP Prosperity Planning Fund (Alfalah GHP Active Allocation Plan)',
          'Alfalah GHP PP Fund (Active)',
        )
        .replaceAll(
          'Alfalah GHP Prosperity Planning Fund (Alfalah GHP Conservative Allocation Plan)',
          'Alfalah GHP PP Fund (Conservative)',
        )
        .replaceAll(
          'Alfalah GHP Prosperity Planning Fund (Capital Preservation Plan IV)',
          'Alfalah GHP PP Fund (Capital Preservation Plan IV)',
        )
        .replaceAll(
          'Alfalah GHP Prosperity Planning Fund (Alfalah GHP Moderate Allocation Plan)',
          'Alfalah GHP PP Fund (Moderate)',
        )
        .replaceAll(
          'Alfalah Financial Value Fund (Alfalah Financial Value Plan I)',
          'Alfalah Financial Value Plan I',
        )
        .replaceAll(
          'Alfalah Islamic Sovereign Fund (Alfalah Islamic Sovereign Plan I)',
          'Alfalah Islamic Sovereign Plan I',
        )
        .replaceAll(
          'Alfalah Islamic Sovereign Fund (Alfalah Islamic Sovereign Plan II)',
          'Alfalah Islamic Sovereign Plan II',
        )
        .replaceAll(
          'Alfalah Islamic Sovereign Fund (Alfalah Islamic Sovereign Plan III)',
          'Alfalah Islamic Sovereign Plan III',
        )
        .replaceAll(
          'Meezan Financial Planning Fund of Funds (Very Conservative Allocation Plan)',
          'Meezan FP Fund of Funds (Very Conservative)',
        )
        .replaceAll(
          'Meezan Financial Planning Fund of Funds (Moderate)',
          'Meezan FP Fund of Funds (Moderate)',
        )
        .replaceAll(
          'Meezan Financial Planning Fund of Funds (Conservative)',
          'Meezan FP Fund of Funds (Conservative)',
        )
        .replaceAll(
          'Meezan Financial Planning Fund of Funds (MAAP I)',
          'Meezan FP Fund of Funds (MAAP-I)',
        )
        .replaceAll(
          'Meezan Financial Planning Fund of Funds (Aggressive)',
          'Meezan FP Fund of Funds (Aggressive)',
        )
        .replaceAll(
          'Meezan Dynamic Asset Allocation Fund (Meezan Dividend Yield Plan)',
          'Meezan Dynamic Asset Allocation Fund',
        )
        .replaceAll(
          'Meezan Daily Income Fund (Meezan Mahana Munafa Plan)',
          'Meezan Mahana Munafa Plan',
        )
        .replaceAll(
          'Meezan Daily Income Fund (Meezan Munafa Plan I)',
          'Meezan Munafa Plan I',
        )
        .replaceAll(
          'Meezan Daily Income Fund (Meezan Sehl Account Plan) (MSHP)',
          'Meezan Sehl Account Plan',
        )
        .replaceAll(
          'Meezan Daily Income Fund (Meezan Super Saver Plan) (MSSP)',
          'Meezan Super Saver Plan',
        )
        .replaceAll(
          'Meezan Capital Protected Fund III (Meezan Capital Secure Plan I)',
          'Meezan Capital Secure Plan I',
        )
        .replaceAll(
          'ABL Islamic Financial Planning Fund (Conservative Allocation Plan)',
          'ABL Islamic FP Fund (Conservative)',
        )
        .replaceAll(
          'ABL Financial Planning Fund (Strategic Allocation Plan)',
          'ABL FP Fund (Strategic Allocation Plan)',
        )
        .replaceAll(
          'ABL Financial Planning Fund (Conservative Plan)',
          'ABL Islamic FP Fund (Conservative)',
        )
        .replaceAll(
          'ABL Islamic Financial Planning Fund (Active Allocation Plan)',
          'ABL Islamic FP Fund (Active)',
        )
        .replaceAll(
          'ABL Islamic Financial Planning Fund (Capital Preservation Plan I)',
          'ABL Islamic FP Fund (Capital Preservation Plan I)',
        )
        .replaceAll(
          'ABL Special Saving Fund (ABL Special Saving Plan I)',
          'ABL Special Saving Plan I',
        )
        .replaceAll(
          'ABL Special Saving Fund (ABL Special Saving Plan II)',
          'ABL Special Saving Plan II',
        )
        .replaceAll(
          'ABL Special Saving Fund (ABL Special Saving Plan III)',
          'ABL Special Saving Plan III',
        )
        .replaceAll(
          'ABL Special Saving Fund (ABL Special Saving Plan IV)',
          'ABL Special Saving Plan IV',
        )
        .replaceAll(
          'ABL Special Saving Fund (ABL Special Saving Plan V)',
          'ABL Special Saving Plan V',
        )
        .replaceAll(
          'ABL Special Saving Fund (ABL Special Saving Plan VI)',
          'ABL Special Saving Plan VI',
        )
        .replaceAll('Government', 'Govt.')
        .trim();
  }

    try {
      final masterResponse = await supabase.from('master_funds').select();
      final statsResponse = await supabase
          .from('performance_stats')
          .select(
            'ticker, return_1d, return_mtd, return_30d, return_fytd, return_1y, return_3y, return_5y, return_10y, return_15y, return_20y, ter_mtd, ter_ytd, last_validity_date',
          );

      _benchmarkStats['KSE100'] = statsResponse.firstWhere(
        (s) => s['ticker'] == 'KSE100',
        orElse: () => <String, dynamic>{},
      );
      _benchmarkStats['KMI30'] = statsResponse.firstWhere(
        (s) => s['ticker'] == 'KMI30',
        orElse: () => <String, dynamic>{},
      );
      _benchmarkStats['GOLD_24K'] = statsResponse.firstWhere(
        (s) => s['ticker'] == 'GOLD_24K',
        orElse: () => <String, dynamic>{},
      );
      _benchmarkStats['CPI_PK'] = statsResponse.firstWhere(
        (s) => s['ticker'] == 'CPI_PK',
        orElse: () => <String, dynamic>{},
      );

      final List<Map<String, dynamic>> combined = [];

      for (var mf in masterResponse) {
        final ticker = mf['ticker'];
        final stats = statsResponse.firstWhere(
          (s) => s['ticker'] == ticker,
          orElse: () => <String, dynamic>{},
        );

        // Grab the raw MUFAP data
        final rawCat = mf['category']?.toString().trim() ?? '';
        final rawAmc = mf['amc_name']?.toString().trim() ?? '';
        final rawName = mf['fund_name']?.toString() ?? 'Unknown';

        combined.add({
          ...mf, // <-- This brings in the ORIGINAL long names so the Individual Page can use them!
          
          // --- THE TWO-KEY INJECTIONS (Short Names for the UI) ---
          'amc_name': amcMap[rawAmc] ?? rawAmc,
          'short_category': categoryMap[rawCat] ?? rawCat,
          'short_amc_name': amcMap[rawAmc] ?? rawAmc,
          'short_name': _cleanFundName(rawName),
          // -------------------------------------------------------

          'return_1d': stats['return_1d'],
          'return_mtd': stats['return_mtd'],
          'return_30d': stats['return_30d'],
          'return_fytd': stats['return_fytd'],
          'return_1y': stats['return_1y'],
          'return_3y': stats['return_3y'],
          'return_5y': stats['return_5y'],
          'return_10y': stats['return_10y'],
          'return_15y': stats['return_15y'],
          'return_20y': stats['return_20y'],
          'ter_mtd': stats['ter_mtd'],
          'ter_ytd': stats['ter_ytd'],
          'last_validity_date': stats['last_validity_date'],
        });
      }
      setState(() {
        _allFunds = combined;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          // Pass the error to the new helper instead of spitting out raw text
          _errorMessage = _getFriendlyErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  String _getGreetingText() {
    final hour = DateTime.now().hour; // 24-hour format (0 to 23)

    if (hour >= 5 && hour < 12) {
      return 'Good Morning';   // 5:00 AM to 11:59 AM
    } 
    if (hour >= 12 && hour < 17) {
      return 'Good Afternoon'; // 12:00 PM to 4:59 PM
    } 
    if (hour >= 17 && hour < 22) {
      return 'Good Evening';   // 5:00 PM to 9:59 PM
    } 
    
    // This catches everything else: 11:00 PM (23) and Midnight to 4:59 AM (0, 1, 2, 3, 4)
    return 'Good Night'; 
  }

  String _getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️';
    if (hour < 17) return '🌤️';
    if (hour < 20) return '🌙';
    return '🌙';
  }

  List<Map<String, dynamic>> _getTop5Funds(
    List<String> categories,
    String sortKey,
  ) {
    // 1. Initial Filter
    var filtered = _allFunds.where((f) {
      final cat = f['short_category']?.toString().trim() ?? '';
      final ticker = f['ticker']?.toString().trim() ?? ''; 
      return categories.contains(cat) && f[sortKey] != null && ticker != 'HBLTETF';
    }).toList();
    
    if (filtered.isEmpty) return [];

    // 2. Find the absolute latest date
    DateTime? latestDate;
    for (var f in filtered) {
      final dStr = f['last_validity_date']?.toString() ?? "";
      try {
        final d = DateTime.parse(dStr);
        if (latestDate == null || d.isAfter(latestDate)) {
          latestDate = d;
        }
      } catch (_) {}
    }

    // 3. The "Smart Weekend" Filter
    if (latestDate != null) {
      // Default to 1 day for normal weekdays (e.g., Wed keeps Wed & Tue. Drops Mon.)
      int allowedDaysBack = 1; 
      
      // DateTime weekdays: Monday=1, Tuesday=2... Saturday=6, Sunday=7
      if (latestDate.weekday == DateTime.monday) {
        allowedDaysBack = 3; // Reaches exactly back to Friday, drops Thursday
      } else if (latestDate.weekday == DateTime.sunday) {
        allowedDaysBack = 2; // Reaches back to Friday, drops Thursday
      }

      filtered = filtered.where((f) {
        final dStr = f['last_validity_date']?.toString() ?? "";
        try {
          final fundDate = DateTime.parse(dStr);
          final difference = latestDate!.difference(fundDate).inDays.abs();
          
          return difference <= allowedDaysBack; 
        } catch (_) {
          return false;
        }
      }).toList();
    }

    // 4. Sort strictly by return
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
          color: isSelected
              ? Colors.tealAccent.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.tealAccent
                : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.tealAccent : Colors.white70,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildTop5Card(String title, List<String> categories, String sortKey) {
    final topFunds = _getTop5Funds(categories, sortKey);

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20), // Reduced from 24
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.tealAccent.withOpacity(0.1), Colors.transparent],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(color: Colors.tealAccent, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            const SizedBox(height: 12), // Reduced gap
            if (topFunds.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text("No funds available.", style: TextStyle(color: Colors.white54))))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero, // Removes default ListView padding
                itemCount: topFunds.length,
                separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 16), // Reduced divider height
                itemBuilder: (context, index) {
                  final fund = topFunds[index];
                  final name = fund['short_name'] ?? fund['fund_name']?.toString() ?? 'Unknown';
                  final isShariah =
                      (fund['is_shariah'] == 1 ||
                      fund['is_shariah'] == '1' ||
                      fund['is_shariah'] == true);
                  final dateStr = fund['last_validity_date'] != null
                      ? DateFormat('dd MMM yyyy').format(
                          DateTime.tryParse(
                                fund['last_validity_date'].toString(),
                              ) ??
                              DateTime.now(),
                        )
                      : 'N/A';

                  final returnFactor = (fund[sortKey] as num).toDouble();
                  final double profitValue =
                      _investmentAmount * (returnFactor - 1.0);

                  String profitString = _currencyFormat.format(
                    profitValue.abs(),
                  );
                  String displayProfit = profitValue >= 0
                      ? '+$profitString'
                      : '-$profitString';
                  Color profitColor = profitValue >= 0
                      ? Colors.greenAccent
                      : Colors.redAccent.shade100;

                  return InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FundDetailsScreen(
                          fund: fund,
                          investmentAmount: _investmentAmount,
                          benchmarkStats: _benchmarkStats,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$name${isShariah ? " 🕌" : ""}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              displayProfit,
                              style: TextStyle(
                                color: profitColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              dateStr,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
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
  // MARKET OVERVIEW SECTION (Repaired Logic & Fallbacks)
  // ============================================================================

  Widget _buildMarketCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    String tickerKey,
    String dbKey,
  ) {
    // Find the real benchmark data from your database!
    final fund = _allFunds.firstWhere(
      (f) => f['ticker'] == tickerKey,
      orElse: () => {},
    );
    if (fund.isEmpty) return const SizedBox.shrink();

    final returnFactor = (fund[dbKey] as num?)?.toDouble() ?? 1.0;
    final double percent = (returnFactor - 1.0) * 100.0;
    final double profitValue = _investmentAmount * (returnFactor - 1.0);

    String profitString = _currencyFormat.format(profitValue.abs());
    String displayProfit = profitValue >= 0
        ? '+PKR $profitString'
        : '-PKR $profitString';
    Color statColor = profitValue >= 0
        ? Colors.greenAccent
        : Colors.redAccent.shade100;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => FundDetailsScreen(fund: fund, investmentAmount: _investmentAmount, benchmarkStats: _benchmarkStats)));
      },
      child: Container(
        width: 105, // Slightly narrower
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), // Massive padding reduction here
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12), // Tighter corners
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Ensures it wraps tightly
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 12), // Smaller icon
                const SizedBox(width: 4),
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4), // Tighter gap
            Text(
              displayProfit,
              style: TextStyle(color: statColor, fontSize: 12, fontWeight: FontWeight.w800, overflow: TextOverflow.ellipsis),
            ),
            Text(
              '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%',
              style: TextStyle(color: statColor.withOpacity(0.8), fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketOverviewSection(String dbKey) { // Removed periodLabel parameter
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'Market Benchmarks', // Removed the dynamic (1Y) text
            style: TextStyle(
              color: Colors.white,
              fontSize: 16, // Slightly tighter font size
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 12), // Tighter gap
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Container(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMarketCard('KSE 100', 'PSX Index', Icons.show_chart, Colors.blueAccent, 'KSE100', dbKey),
                const SizedBox(width: 12),
                _buildMarketCard('KMI 30', 'Islamic Index', Icons.mosque_outlined, Colors.green, 'KMI30', dbKey),
                const SizedBox(width: 12),
                _buildMarketCard('Gold', 'Per Tola', Icons.circle, Colors.amberAccent, 'GOLD_24K', dbKey),
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
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    String dbSortKey = _selectedDashboardPeriod == '30D'
        ? 'return_30d'
        : _selectedDashboardPeriod == '3Y'
        ? 'return_3y'
        : 'return_1y';

    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = screenWidth * 0.90; 
    final double sidePadding = (screenWidth - cardWidth) / 2;

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
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
                  border: Border(
                    bottom: BorderSide(color: Colors.tealAccent, width: 2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Image.asset(
                      'assets/app_icon_transparent.png',
                      width: 72,
                      height: 72,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.tealAccent,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Bachat Vault',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Version 1.0.0',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // 1. THE NEW EXPANDABLE INVESTMENT GUIDE MENU
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: const Icon(
                    Icons.menu_book_rounded,
                    color: Colors.tealAccent,
                    size: 22,
                  ),
                  title: const Text(
                    'Investment Guide',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  iconColor: Colors.tealAccent,
                  collapsedIconColor: Colors.tealAccent,
                  childrenPadding: const EdgeInsets.only(
                    left: 54,
                    bottom: 8,
                  ), // Indents the sub-items perfectly to align with the text
                  children: [
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: const Text(
                        'Your Financial Journey',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      onTap: () {
                        // Closes the drawer first
                        Navigator.pop(context);
                        // Navigates to the new screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const FinancialJourneyScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: const Text(
                        'Mutual Funds',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      onTap: () {
                        Navigator.pop(context); // Close the drawer
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MutualFundsScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: const Text(
                        'Pension Funds',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      onTap: () {
                        Navigator.pop(context); // Close the drawer
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PensionFundsScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: const Text(
                        'Exchange Traded Funds',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      onTap: () {
                        Navigator.pop(context); // Close the drawer
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EtfsScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: const Text(
                        'Overseas Investors',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      onTap: () {
                        Navigator.pop(context); // Close the drawer
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const OverseasInvestorsScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: const Text(
                        'Account Opening & Taxes',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AccountOpeningScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white12),
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
                child: Text(
                  'COMMUNITIES',
                  style: TextStyle(
                    color: Colors.tealAccent.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              _buildDrawerItem(
                Icons.facebook_rounded,
                'Facebook Page',
                () => _launchURL('https://www.facebook.com/MFInvestment'),
              ),
              _buildDrawerItem(
                Icons.groups_rounded,
                'Facebook Group',
                () => _launchURL(
                  'https://www.facebook.com/groups/2125880957874842',
                ),
              ),
              _buildDrawerItem(
                Icons.chat_rounded,
                'WhatsApp Group',
                () => _launchURL(
                  'https://chat.whatsapp.com/HHUBK1TR6h918qOlfx4n4v?mode=gi_t',
                ),
              ),
              _buildDrawerItem(
                Icons.campaign_rounded,
                'WhatsApp Channel',
                () => _launchURL(
                  'https://whatsapp.com/channel/0029Vb7Nr1k1t90jrhhvPp3j',
                ),
              ),
              _buildDrawerItem(
                Icons.camera_alt_rounded,
                'Instagram',
                () => _launchURL('https://www.instagram.com/mfi_pakistan/'),
              ),
              _buildDrawerItem(
                Icons.smart_display_rounded,
                'YouTube Channel',
                () => _launchURL('https://www.youtube.com/@the_mixedb4g'),
              ),
              const Divider(color: Colors.white12),
              _buildDrawerItem(Icons.gavel_rounded, 'Terms & Conditions', () {
                Navigator.pop(context); // Close the drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TermsConditionsScreen(),
                  ),
                );
              }),
              _buildDrawerItem(Icons.security_rounded, 'Privacy Policy', () {
                // Replace this URL with your actual Google Sites link!
                launchUrl(
                  Uri.parse(
                    'https://sites.google.com/view/bachatvault-privacy',
                  ),
                );
              }),

              // New Feedback & Support Launcher
              _buildDrawerItem(
                Icons.email_outlined,
                'Feedback & Support',
                () async {
                  final Uri emailLaunchUri = Uri(
                    scheme: 'mailto',
                    path:
                        'themixedb4g@gmail.com', // 👉 CHANGE THIS TO YOUR GMAIL
                    query: 'subject=Bachat Vault App Feedback',
                  );
                  // Make sure to import 'package:url_launcher/url_launcher.dart'; at the top of your file!
                  launchUrl(emailLaunchUri);
                },
              ),

              const SizedBox(
                height: 24,
              ), // Gives a little breathing room at the bottom of the scroll
            ],
          ),
        ),
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getGreetingText(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedEmoji(emoji: _getGreetingEmoji()),
            ],
          ),
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          
          // FIX 3: Removed the manual refresh button to support modern "Pull to Refresh"
          actions: const [
            // Top right corner can be used for profile login in the future.
            SizedBox(width: 48), 
          ],
          
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
            // FIX 3: Wrapped the entire main body in a RefreshIndicator
            child: RefreshIndicator(
              color: Colors.tealAccent,
              backgroundColor: const Color(0xFF1E293B),
              onRefresh: _fetchData,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.tealAccent),
                    )
                  : _errorMessage != null
                      // FIX 2: Beautiful integrated Error Screen instead of tiny red text
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(), // Important: allows pull-to-refresh even when empty/error
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                            const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 64),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                              ),
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(), // Important: allows pull-to-refresh
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Tighter top spacing
                            const SizedBox(height: 12), 
                            const Center(
                              child: Text(
                                'Your Investment Value',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13, // Slightly smaller
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            // 2. Removed the massive vertical: 4 padding on the TextField
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Center(
                                child: IntrinsicWidth(
                                  child: TextField(
                                    controller: _investmentController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [IndianNumberFormatter()],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32, // Slightly smaller to fit better
                                      fontWeight: FontWeight.w800,
                                      height: 1.2, // Tighter line height
                                    ),
                                    decoration: const InputDecoration(
                                      prefixText: 'PKR ',
                                      prefixStyle: TextStyle(
                                        color: Colors.tealAccent,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true, // Forces the textfield to shrink-wrap its content
                                      contentPadding: EdgeInsets.zero, // Removes hidden default padding
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _investmentAmount = double.tryParse(val.replaceAll(',', '')) ?? 0.0;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 8), // Tight gap to filters

                            // 3. Filter Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildDashFilterBtn('30D'),
                                const SizedBox(width: 8), // Tighter gap between buttons
                                _buildDashFilterBtn('1Y'),
                                const SizedBox(width: 8),
                                _buildDashFilterBtn('3Y'),
                              ],
                            ),
                            
                            const SizedBox(height: 16), // Gap before Benchmarks

                            // 4. Benchmarks Moved UP and made compact
                            _buildMarketOverviewSection(dbSortKey),

                            const SizedBox(height: 16), // Gap before Top 5 Cards

                            // --- TOP 5 CARDS (DYNAMIC HEIGHT CAROUSEL) ---
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              // Apply the dynamic padding here:
                              padding: EdgeInsets.symmetric(horizontal: sidePadding), 
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: cardWidth,
                                    child: _buildTop5Card('Top 5 Equity Funds', ['Equity'], dbSortKey),
                                  ),
                                  const SizedBox(width: 12), // Explicit, clean gap between cards
                                  SizedBox(
                                    width: cardWidth,
                                    child: _buildTop5Card('Top 5 ETFs', ['Exchange Traded Fund'], dbSortKey),
                                  ),
                                  const SizedBox(width: 12), // Explicit, clean gap between cards
                                  SizedBox(
                                    width: cardWidth,
                                    child: _buildTop5Card('Top 5 Money Market', ['Money Market'], dbSortKey),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                child: InkWell(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FullPerformanceScreen(
                                        allFunds: _allFunds,
                                        initialInvestment: _investmentAmount,
                                        benchmarkStats: _benchmarkStats,
                                      ),
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Colors.tealAccent, Colors.teal],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.tealAccent.withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.analytics_outlined,
                                          color: Colors.black87,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Explore Full Performance',
                                          style: TextStyle(
                                            color: Colors.black87,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
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
      ),
    );
  }
}

class AnimatedEmoji extends StatefulWidget {
  final String emoji;
  const AnimatedEmoji({super.key, required this.emoji});
  @override
  State<AnimatedEmoji> createState() => _AnimatedEmojiState();
}

class _AnimatedEmojiState extends State<AnimatedEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -0.15),
        end: const Offset(0, 0.15),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Text(widget.emoji, style: const TextStyle(fontSize: 22)),
    );
  }
}

class IndianNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleanText.split('.').length > 2)
      cleanText = oldValue.text.replaceAll(',', '');
    if (cleanText.isEmpty) return newValue.copyWith(text: '');
    List<String> parts = cleanText.split('.');
    String wholeNumber = parts[0];
    String decimalPart = parts.length > 1 ? '.${parts[1]}' : '';
    if (wholeNumber.isEmpty) return newValue.copyWith(text: cleanText);
    final formatter = NumberFormat.decimalPattern('en_IN');
    String formatted = formatter.format(int.parse(wholeNumber));
    String finalString = formatted + decimalPart;
    return TextEditingValue(
      text: finalString,
      selection: TextSelection.collapsed(offset: finalString.length),
    );
  }
}