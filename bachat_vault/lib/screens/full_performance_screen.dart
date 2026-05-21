import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection; 
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bachat_vault/screens/fund_details_screen.dart';
import 'package:bachat_vault/screens/compare_funds_screen.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:gal/gal.dart';

class FullPerformanceScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allFunds;
  final double initialInvestment;
  final Map<String, dynamic> benchmarkStats;

  const FullPerformanceScreen({
    super.key,
    required this.allFunds,
    required this.initialInvestment,
    required this.benchmarkStats,
  });

  @override
  State<FullPerformanceScreen> createState() => _FullPerformanceScreenState();
}

class _FullPerformanceScreenState extends State<FullPerformanceScreen> {
  // 🚨 ADD YOUR EXCLUDED TICKERS HERE (e.g., 'TICKER1', 'TICKER2')
  final List<String> _excludedScreenshotFunds = [];

  late double _investmentAmount;
  late TextEditingController _investmentController;
  late TextEditingController _searchController;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0);

  List<String> _categories = ['All'];
  List<String> _amcs = ['All'];
  final List<String> _shariahOptions = ['All', 'Islamic', 'Conventional'];
  String _selectedCategory = 'All';
  String _selectedAmc = 'All';
  String _selectedPeriod = '1D';
  String _selectedShariah = 'All';
  String _searchQuery = '';

  List<String> _favoriteTickers = [];
  bool _showFavoritesOnly = false;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isCustomLoading = false;
  Map<String, double> _customReturnsMap = {};

  List<Map<String, dynamic>> _displayedFunds = [];
  bool _isFiltering = false;

  bool _isAdmin = false;
  int _secretTaps = 0;
  DateTime? _lastTapTime;
  
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _investmentAmount = widget.initialInvestment;
    _investmentController = TextEditingController(text: _currencyFormat.format(_investmentAmount));
    _searchController = TextEditingController();
    _searchController.addListener(() {
      _onFilterChanged(() {
        _searchQuery = _searchController.text.trim();
      });
    });
    _setupFilters();
    _loadFavorites();
    _loadAdminStatus(); 
    _applyFiltersAsync();
  }

  @override
  void dispose() {
    _investmentController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAdmin = prefs.getBool('is_admin') ?? false;
    });
  }

  Future<void> _handleSecretTap() async {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!).inSeconds > 1) {
      _secretTaps = 0;
    }
    _lastTapTime = now;
    _secretTaps++;

    if (_secretTaps >= 7) {
      _secretTaps = 0;
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isAdmin = !_isAdmin;
      });
      prefs.setBool('is_admin', _isAdmin);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isAdmin ? 'Developer Mode Unlocked 🔓' : 'Developer Mode Locked 🔒'),
          backgroundColor: _isAdmin ? Colors.green : Colors.red,
        ));
      }
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteTickers = prefs.getStringList('favorite_funds') ?? [];
    });
  }

  Future<void> _toggleFavorite(String ticker) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favoriteTickers.contains(ticker)) {
        _favoriteTickers.remove(ticker);
      } else {
        _favoriteTickers.add(ticker);
      }
      prefs.setStringList('favorite_funds', _favoriteTickers);
      if (_showFavoritesOnly) _applyFiltersAsync();
    });
  }

  void _onFilterChanged(VoidCallback updateState) {
    updateState();
    setState(() { _isFiltering = true; });
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _applyFiltersAsync();
    });
  }

  void _applyFiltersAsync() {
    setState(() {
      _displayedFunds = _getFilteredAndSortedFunds();
      _isFiltering = false;
    });
  }

  void _setupFilters() {
    final Set<String> categorySet = {};
    final Set<String> amcSet = {};
    for (var mf in widget.allFunds) {
      final cat = mf['short_category'] ?? mf['category'];
      if (cat != null && cat.toString().isNotEmpty) categorySet.add(cat.toString().trim());
      
      final amc = mf['short_amc_name'] ?? mf['amc_name'];
      if (amc != null && amc.toString().isNotEmpty) amcSet.add(amc.toString().trim());
    }
    
    setState(() {
      _categories = ['All', ...categorySet.toList()..sort()];
      _amcs = ['All', ...amcSet.toList()..sort()];
      if (_categories.contains('Equity')) {
        _selectedCategory = 'Equity';
      }
    });
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
      case 'MTD': return 'return_mtd';
      case 'YTD': return 'return_fytd';
      case 'Custom': return 'return_1d';
      default: return 'return_1d';
    }
  }

  List<Map<String, dynamic>> _getFilteredAndSortedFunds() {
    final sortKey = _getSortKey();
    var filtered = widget.allFunds.toList();
    if (_showFavoritesOnly) {
      filtered = filtered.where((f) => _favoriteTickers.contains(f['ticker'])).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((f) {
        final name = (f['short_name'] ?? f['fund_name'])?.toString().toLowerCase() ?? '';
        final amc = (f['short_amc_name'] ?? f['amc_name'])?.toString().toLowerCase() ?? '';
        return name.contains(query) || amc.contains(query);
      }).toList();
    } else {
      if (_selectedCategory != 'All') {
        filtered = filtered.where((f) => (f['short_category'] ?? f['category'])?.toString().trim() == _selectedCategory).toList();
      }
      if (_selectedAmc != 'All') {
        filtered = filtered.where((f) => (f['short_amc_name'] ?? f['amc_name'])?.toString().trim() == _selectedAmc).toList();
      }
      if (_selectedShariah == 'Islamic') {
        filtered = filtered.where((f) => f['is_shariah'] == 1 || f['is_shariah'] == '1' || f['is_shariah'] == true).toList();
      } else if (_selectedShariah == 'Conventional') {
        filtered = filtered.where((f) => f['is_shariah'] != 1 && f['is_shariah'] != '1' && f['is_shariah'] != true).toList();
      }
    }

    if (_selectedPeriod != 'Custom') {
      filtered = filtered.where((f) => f[sortKey] != null).toList();
    }

    filtered.sort((a, b) {
      final valA = _selectedPeriod == 'Custom' ? (_customReturnsMap[a['ticker']] ?? -999.0) : (a[sortKey] as num?)?.toDouble() ?? -999.0;
      final valB = _selectedPeriod == 'Custom' ? (_customReturnsMap[b['ticker']] ?? -999.0) : (b[sortKey] as num?)?.toDouble() ?? -999.0;
      
      final logicA = a['return_logic']?.toString().trim() ?? '';
      final logicB = b['return_logic']?.toString().trim() ?? '';
      final isShortTerm = ['return_1d', 'return_mtd', 'return_30d', 'return_fytd', 'return_ytd', 'return_1y'].contains(sortKey);
      
      if (isShortTerm && logicA == 'Absolute' && logicB == 'Absolute') {
        final dateStrA = a['last_validity_date']?.toString();
        final dateStrB = b['last_validity_date']?.toString();
        final dateA = dateStrA != null ? (DateTime.tryParse(dateStrA) ?? DateTime(1970)) : DateTime(1970);
        final dateB = dateStrB != null ? (DateTime.tryParse(dateStrB) ?? DateTime(1970)) : DateTime(1970);
        int dateComparison = dateB.compareTo(dateA);
        if (dateComparison != 0) return dateComparison;
      }
      
      return valB.compareTo(valA);
    });

    return filtered;
  }

  // --- 📸 EXPORT MENU ---
  void _showExportMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Select Export Type', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.star_rounded, color: Colors.amberAccent),
                title: const Text('Top 25 Market Leaders (1D)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Equity, Index & ETFs (No delayed funds)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _exportTop25Report();
                },
              ),
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.category_outlined, color: Colors.tealAccent),
                title: const Text('Top 10 Category-wise', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _exportReports();
                },
              ),
              ListTile(
                leading: const Icon(Icons.domain_outlined, color: Colors.tealAccent),
                title: const Text('All Funds AMC-wise', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  final uniqueAmcs = widget.allFunds
                      .map((f) => (f['short_amc_name'] ?? f['amc_name']).toString().trim())
                      .where((a) => a.isNotEmpty && a != 'All')
                      .toSet();
                  _showAmcSelectionDialog(uniqueAmcs);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      }
    );
  }

  // --- 📸 AMC CHECKBOX DIALOG ---
  Future<void> _showAmcSelectionDialog(Set<String> uniqueAmcs) async {
    List<String> amcList = uniqueAmcs.toList()..sort();
    List<String> selectedAmcs = List.from(amcList);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text('Select AMCs', style: TextStyle(color: Colors.white)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(onPressed: () => setState(() => selectedAmcs = List.from(amcList)), child: const Text('Select All', style: TextStyle(color: Colors.tealAccent))),
                        TextButton(onPressed: () => setState(() => selectedAmcs.clear()), child: const Text('Clear All', style: TextStyle(color: Colors.tealAccent))),
                      ]
                    ),
                    const Divider(color: Colors.white24),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: amcList.length,
                        itemBuilder: (context, index) {
                          final amc = amcList[index];
                          return CheckboxListTile(
                            activeColor: Colors.tealAccent,
                            checkColor: Colors.black,
                            title: Text(amc, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            value: selectedAmcs.contains(amc),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) selectedAmcs.add(amc);
                                else selectedAmcs.remove(amc);
                              });
                            }
                          );
                        }
                      )
                    )
                  ]
                )
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                  onPressed: () {
                    Navigator.pop(context);
                    if (selectedAmcs.isNotEmpty) {
                      _exportAmcReports(selectedAmcs);
                    }
                  }, 
                  child: const Text('Export')
                )
              ]
            );
          }
        );
      }
    );
  }

  // --- 📸 NEW: TOP 25 EXPORT LOGIC ---
  Future<void> _exportTop25Report() async {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          backgroundColor: Color(0xFF1E293B),
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.tealAccent),
                SizedBox(width: 20),
                Text("Generating Top 25 Report...", style: TextStyle(color: Colors.white)), // Changed to 25
              ],
            ),
          ),
        );
      },
    );
    try {
      DateTime maxAbsoluteDate = DateTime(1970);
      for (var f in widget.allFunds) {
        final cat = (f['short_category'] ?? f['category'])?.toString().trim() ?? '';
        final t = f['ticker']?.toString() ?? '';
        if (t == 'HBLTETF' || t == 'GOLD_24K') continue;
        final isAbsoluteCat = ['Equity', 'Index Tracker', 'Exchange Traded Fund', 'Asset Allocation', 'Balanced'].contains(cat);
        if (isAbsoluteCat && f['last_validity_date'] != null) {
          final dt = DateTime.tryParse(f['last_validity_date'].toString());
          if (dt != null) {
            DateTime dOnly = DateTime(dt.year, dt.month, dt.day);
            if (dOnly.isAfter(maxAbsoluteDate)) maxAbsoluteDate = dOnly;
          }
        }
      }

      var eligibleFunds = widget.allFunds.where((f) {
        final cat = (f['short_category'] ?? f['category'])?.toString().trim() ?? '';
        final t = f['ticker']?.toString() ?? '';
        
        if (t == 'HBLTETF' || t == 'GOLD_24K') return false;
        if (_excludedScreenshotFunds.contains(t)) return false;
        if (!['Equity', 'Index Tracker', 'Exchange Traded Fund'].contains(cat)) return false;
        if (f['return_1d'] == null) return false;

        // Strict Delay Check
        if (f['last_validity_date'] != null) {
          final dt = DateTime.tryParse(f['last_validity_date'].toString());
          if (dt != null) {
            final dOnly = DateTime(dt.year, dt.month, dt.day);
            if (dOnly.isBefore(maxAbsoluteDate)) return false; 
          } else return false;
        } else return false;

        return true;
      }).toList();
      
      eligibleFunds.sort((a, b) => ((b['return_1d'] as num?)?.toDouble() ?? -999.0).compareTo((a['return_1d'] as num?)?.toDouble() ?? -999.0));
      
      // Changed .take(30) to .take(25)
      var top25 = eligibleFunds.take(25).toList();
      
      // Changed Title string passed to the screenshot generator
      await _captureAndSaveLight('Top 25 Market Leaders', top25, true);

      if (mounted) {
        Navigator.of(context).pop();
        // Changed SnackBar success message
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Top 25 Report saved to Gallery!'), backgroundColor: Colors.green, duration: Duration(seconds: 4)));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // --- 📸 1. CATEGORY-WISE EXPORT LOGIC ---
  Future<void> _exportReports() async {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          backgroundColor: Color(0xFF1E293B),
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.tealAccent),
                SizedBox(width: 20),
                Text("Generating High-Res Reports...", style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        );
      },
    );

    try {
      List<Map<String, dynamic>> getTop10(List<String> categoryMatches, String primarySortKey) {
        var list = widget.allFunds.where((f) {
          final ticker = f['ticker']?.toString() ?? '';
          if (ticker == 'HBLTETF' || ticker == 'GOLD_24K') return false;
          if (_excludedScreenshotFunds.contains(ticker)) return false;

          final cat = (f['short_category'] ?? f['category'])?.toString().trim() ?? '';
          return categoryMatches.contains(cat);
        }).toList();

        var matureFunds = list.where((f) => f[primarySortKey] != null).toList();
        matureFunds.sort((a, b) {
          final valA = (a[primarySortKey] as num?)?.toDouble() ?? -999.0;
          final valB = (b[primarySortKey] as num?)?.toDouble() ?? -999.0;
          return valB.compareTo(valA);
        });
        return matureFunds.take(10).toList();
      }

      final mmList = getTop10(['Money Market'], 'return_30d');
      final incList = getTop10(['Income'], 'return_30d');
      final eqList = getTop10(['Equity', 'Index Tracker'], 'return_1y'); 
      final etfList = getTop10(['Exchange Traded Fund'], 'return_1y');
      final commList = getTop10(['Commodities'], 'return_1d');
      final aaList = getTop10(['Asset Allocation'], 'return_1y');
      final balList = getTop10(['Balanced'], 'return_1y');

      await _captureAndSaveLight('Top Money Market Funds', mmList, false);
      await _captureAndSaveLight('Top Income Funds', incList, false);
      await _captureAndSaveLight('Top Equity Funds', eqList, true);
      await _captureAndSaveLight('Top Asset Allocation Funds', aaList, true);
      await _captureAndSaveLight('Top Balanced Funds', balList, true);
      await _captureAndSaveLight('Top Commodity Funds', commList, true);
      await _captureAndSaveLight('Top ETFs', etfList, true);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 7 Reports saved to Gallery!'), backgroundColor: Colors.green, duration: Duration(seconds: 4)));
      }

    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // --- THE SHARED LIGHT THEME CAPTURE LOGIC ---
  Future<void> _captureAndSaveLight(String title, List<Map<String, dynamic>> funds, bool isLongTerm) async {
    if (funds.isEmpty) return;

    DateTime maxAbsoluteDate = DateTime(1970);
    for (var f in widget.allFunds) {
      final cat = (f['short_category'] ?? f['category'])?.toString().trim() ?? '';
      final t = f['ticker']?.toString() ?? '';
      if (t == 'HBLTETF' || t == 'GOLD_24K') continue;
      final isAbsoluteCat = ['Equity', 'Index Tracker', 'Exchange Traded Fund', 'Asset Allocation', 'Balanced'].contains(cat);
      if (isAbsoluteCat && f['last_validity_date'] != null) {
        final dt = DateTime.tryParse(f['last_validity_date'].toString());
        if (dt != null) {
          DateTime dOnly = DateTime(dt.year, dt.month, dt.day);
          if (dOnly.isAfter(maxAbsoluteDate)) maxAbsoluteDate = dOnly;
        }
      }
    }

    // Compress row height for Top 25 to save massive vertical space
    double rowHeight = title == 'Top 25 Market Leaders' ? 75.0 : 100.0;
    double contentHeight = 120.0 + 120.0 + 40.0 + 20.0 + 40.0 + 20.0;
    contentHeight += funds.length * rowHeight; 
    
    if (title == 'Top Equity Funds' || title == 'Top 25 Market Leaders') {
      contentHeight += 40.0 + 220.0; 
    }

    double dynamicHeight = contentHeight + 100.0;

    Widget reportCard = MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.noScaling),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: OverflowBox(
          minWidth: 1080, maxWidth: 1080,
          minHeight: dynamicHeight, maxHeight: dynamicHeight,
          alignment: Alignment.topCenter,
          child: Material(
            color: Colors.white, 
            child: Container(
              width: 1080, height: dynamicHeight,
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.all(60.0), 
              child: Column(
                mainAxisSize: MainAxisSize.min, 
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                        height: title == 'Top 25 Market Leaders' ? 140 : 120, // Expanded to fit 3 lines
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SizedBox(
                              width: 600,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(title, style: GoogleFonts.poppins(color: Colors.teal.shade800, fontSize: 48, fontWeight: FontWeight.bold), maxLines: 1),
                                  Text('Investment: PKR 1,00,000', style: GoogleFonts.poppins(color: Colors.black87, fontSize: 24), maxLines: 1),
                                  if (title == 'Top 25 Market Leaders')
                                    Text('As of ${DateFormat('dd MMM yyyy').format(maxAbsoluteDate)}', style: GoogleFonts.poppins(color: Colors.black54, fontSize: 20), maxLines: 1),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.teal.shade800)),
                              child: Text('Bachat Vault', style: GoogleFonts.poppins(color: Colors.teal.shade800, fontSize: 28, fontWeight: FontWeight.w800)),
                            )
                          ],
                        ),
                      ),
                      SizedBox(height: title == 'Top 25 Market Leaders' ? 16 : 40), // Reduced gap for Top 25
                      const Divider(color: Colors.black12, thickness: 2, height: 20),
                  
                  SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        SizedBox(width: 500, child: Text('Fund Name', style: GoogleFonts.poppins(color: Colors.black54, fontSize: 24, fontWeight: FontWeight.bold))),
                        SizedBox(width: 230, child: Text('1D Return', textAlign: TextAlign.right, style: GoogleFonts.poppins(color: Colors.black54, fontSize: 24, fontWeight: FontWeight.bold))),
                        SizedBox(width: 230, child: Text(isLongTerm ? '1Y Return' : '30D Return', textAlign: TextAlign.right, style: GoogleFonts.poppins(color: Colors.black54, fontSize: 24, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  ...funds.map((f) {
                    final name = f['short_name'] ?? f['fund_name']?.toString() ?? 'Unknown';
                    final amc = f['short_amc_name'] ?? f['amc_name']?.toString() ?? '';
                    final isShariah = (f['is_shariah'] == 1 || f['is_shariah'] == '1' || f['is_shariah'] == true);
                    final displayName = '$name${isShariah ? " 🕌" : ""}';
                    final cat = (f['short_category'] ?? f['category'])?.toString().trim() ?? '';
                    final logic = f['return_logic']?.toString().trim() ?? '';
                    
                    bool isStale = false;
                    if (f['last_validity_date'] != null) {
                      final dt = DateTime.tryParse(f['last_validity_date'].toString());
                      if (dt != null) {
                        final dOnly = DateTime(dt.year, dt.month, dt.day);
                        if (cat == 'Commodities') {
                          if (dOnly.isBefore(maxAbsoluteDate.subtract(const Duration(days: 1)))) isStale = true;
                        } else if (cat == 'Money Market' || cat == 'Income' || logic == 'Annualized') {
                          if (dOnly.isBefore(maxAbsoluteDate)) isStale = true;
                        } else {
                          if (dOnly.isBefore(maxAbsoluteDate)) isStale = true;
                        }
                      } else isStale = true;
                    } else isStale = true;
                    
                    String validityDateStr = f['last_validity_date'] != null ? DateFormat('dd MMM yyyy').format(DateTime.tryParse(f['last_validity_date'].toString()) ?? DateTime.now()) : 'N/A';
                    if (isStale) validityDateStr += ' (Delayed)';
                    Color validityColor = isStale ? Colors.red.shade700 : Colors.black54;

                    final r1d = f['return_1d'];
                    final key2 = isLongTerm ? 'return_1y' : 'return_30d';
                    final r2 = f[key2];

                    String formatPkr(dynamic r) {
                      if (r == null) return 'N/A';
                      double val = (r as num).toDouble();
                      double pkr = 100000.0 * (val - 1.0);
                      final format = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0);
                      return '${pkr > 0 ? '+' : pkr < 0 ? '-' : ''}${format.format(pkr.abs())}';
                    }
                    
                    Color getColor(dynamic r) {
                      if (r == null) return Colors.black54;
                      double val = (r as num).toDouble();
                      return val >= 1.0 ? Colors.green.shade700 : Colors.red.shade700;
                    }

                    return SizedBox(
                      height: rowHeight, // Use dynamic height
                      child: Container(
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 500, 
                              child: Padding(
                                padding: const EdgeInsets.only(right: 16.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (title != 'Top 25 Market Leaders')
                                      Row(
                                        children: [
                                          Flexible(child: Text(amc.toUpperCase(), style: GoogleFonts.poppins(color: Colors.teal.shade800, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                          const SizedBox(width: 12),
                                          Text('•', style: GoogleFonts.poppins(color: Colors.black26, fontSize: 16)),
                                          const SizedBox(width: 12),
                                          Text(validityDateStr, style: GoogleFonts.poppins(color: validityColor, fontSize: 14, fontWeight: FontWeight.w600)),
                                        ],
                                      )
                                    else
                                      Text(amc.toUpperCase(), style: GoogleFonts.poppins(color: Colors.teal.shade800, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    
                                    FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(displayName, style: GoogleFonts.poppins(color: Colors.black87, fontSize: 26, fontWeight: FontWeight.w600))),
                                  ],
                                ),
                              )
                            ),
                            SizedBox(
                              width: 230, 
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  FittedBox(fit: BoxFit.scaleDown, child: Text(formatPkr(r1d), style: GoogleFonts.poppins(color: getColor(r1d), fontSize: 24, fontWeight: FontWeight.bold))),
                                ]
                              )
                            ),
                            SizedBox(
                              width: 230, 
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  FittedBox(fit: BoxFit.scaleDown, child: Text(formatPkr(r2), style: GoogleFonts.poppins(color: getColor(r2), fontSize: 24, fontWeight: FontWeight.bold))),
                                ]
                              )
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  
                  if (title == 'Top Equity Funds' || title == 'Top 25 Market Leaders') ...[
                    const SizedBox(height: 40),
                    SizedBox(
                      height: 220, 
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Market Benchmarks', style: GoogleFonts.poppins(color: Colors.black87, fontSize: 28, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 24),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildBenchmarkStatLight('KSE-100 (1D)', widget.benchmarkStats['KSE100']?['return_1d']),
                                  _buildBenchmarkStatLight('KSE-100 (1Y)', widget.benchmarkStats['KSE100']?['return_1y']),
                                  _buildBenchmarkStatLight('KMI-30 (1D)', widget.benchmarkStats['KMI30']?['return_1d']),
                                  _buildBenchmarkStatLight('KMI-30 (1Y)', widget.benchmarkStats['KMI30']?['return_1y']),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    )
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Uint8List capturedImage = await _screenshotController.captureFromWidget(
      reportCard, 
      delay: const Duration(milliseconds: 100),
      targetSize: Size(1080, dynamicHeight),
      pixelRatio: 1.0, 
    );
    await Gal.putImageBytes(capturedImage, name: 'BachatVault_${title.replaceAll(' ', '')}_Report');
  }

  Widget _buildBenchmarkStatLight(String label, dynamic returnFactor) {
    if (returnFactor == null) return const SizedBox.shrink();
    double r = (returnFactor as num).toDouble();
    double pct = (r - 1.0) * 100.0;
    Color c = pct >= 0 ? Colors.green.shade700 : Colors.red.shade700;
    String sign = pct > 0 ? '+' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(color: Colors.black54, fontSize: 20)),
        FittedBox(fit: BoxFit.scaleDown, child: Text('$sign${pct.toStringAsFixed(2)}%', style: GoogleFonts.poppins(color: c, fontSize: 32, fontWeight: FontWeight.bold))),
      ],
    );
  }

  // --- 📸 2. AMC-WISE EXPORT LOGIC (LIGHT THEME OPTIMIZED) ---
  Future<void> _exportAmcReports(List<String> selectedAmcs) async {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          backgroundColor: Color(0xFF1E293B),
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.tealAccent),
                SizedBox(width: 20),
                Text("Generating AMC Reports...", style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        );
      },
    );

    try {
      int imagesSaved = 0;
      int getCatPriority(String cat) {
        switch(cat) {
          case 'Money Market': return 1;
          case 'Income': return 2;
          case 'Balanced': return 3;
          case 'Asset Allocation': return 4;
          case 'Equity': return 5;
          case 'Index Tracker': return 6;
          case 'Exchange Traded Fund': return 7;
          case 'Commodities': return 8; 
          default: return 99;
        }
      }

      DateTime maxAbsoluteDate = DateTime(1970);
      for (var f in widget.allFunds) {
        final cat = (f['short_category'] ?? f['category'])?.toString().trim() ?? '';
        final t = f['ticker']?.toString() ?? '';
        
        if (t == 'HBLTETF' || t == 'GOLD_24K') continue;
        final isAbsoluteCat = ['Equity', 'Index Tracker', 'Exchange Traded Fund', 'Asset Allocation', 'Balanced'].contains(cat);
        if (isAbsoluteCat && f['last_validity_date'] != null) {
          final dt = DateTime.tryParse(f['last_validity_date'].toString());
          if (dt != null) {
            DateTime dOnly = DateTime(dt.year, dt.month, dt.day);
            if (dOnly.isAfter(maxAbsoluteDate)) maxAbsoluteDate = dOnly;
          }
        }
      }

      for (String amc in selectedAmcs) {
        var amcFunds = widget.allFunds.where((f) {
          final a = (f['short_amc_name'] ?? f['amc_name']).toString().trim();
          final t = f['ticker']?.toString() ?? '';
          final n = f['fund_name']?.toString() ?? '';
          final sn = f['short_name']?.toString() ?? '';

          if (t == 'HBLTETF' || t == 'GOLD_24K') return false;
          if (_excludedScreenshotFunds.contains(t)) return false;

          final excludeNames = [
            'Meezan Daily Income Fund (Meezan Mahana Munafa Plan)', 'Meezan Daily Income Fund (MDIP I)',
            'Meezan Rozana Amdani Fund', 'Alhamra Daily Dividend Fund', 'NBP Cash Plan II',
            'Pak Qatar Daily Dividend Plan', 'Meezan Mahana Munafa Plan', 'Meezan Munafa Plan I'
          ];

          if (excludeNames.contains(n) || excludeNames.contains(sn)) return false;
          if (n.contains('Meezan Rozana Amdani') || n.contains('NBP Cash Plan II') || n.contains('Pak Qatar Daily Dividend') || n.contains('Alhamra Daily Dividend')) return false;

          return a == amc;
        }).toList();

        if (amcFunds.isEmpty) continue;

        var groupA = amcFunds.where((f) {
          final cat = f['short_category']?.toString().trim() ?? '';
          return cat == 'Money Market' || cat == 'Income';
        }).toList();
        groupA.sort((a, b) => getCatPriority(a['short_category'] ?? '').compareTo(getCatPriority(b['short_category'] ?? '')));

        var groupB = amcFunds.where((f) {
          final cat = f['short_category']?.toString().trim() ?? '';
          return ['Balanced', 'Asset Allocation', 'Equity', 'Index Tracker', 'Exchange Traded Fund', 'Commodities'].contains(cat);
        }).toList();
        groupB.sort((a, b) => getCatPriority(a['short_category'] ?? '').compareTo(getCatPriority(b['short_category'] ?? '')));

        if (groupA.isEmpty && groupB.isEmpty) continue;

        double contentHeight = 120.0 + 120.0 + 40.0 + 20.0;
        if (groupA.isNotEmpty) contentHeight += 80.0 + (groupA.length * 100.0);
        if (groupB.isNotEmpty) {
          if (groupA.isNotEmpty) contentHeight += 40.0;
          contentHeight += 80.0 + (groupB.length * 100.0);
        }
        double dynamicHeight = contentHeight + 100.0;

        Widget buildFundRow(Map<String, dynamic> f, bool isLongTerm) {
          final name = f['short_name'] ?? f['fund_name']?.toString() ?? 'Unknown';
          final cat = f['short_category']?.toString() ?? '';
          final logic = f['return_logic']?.toString().trim() ?? '';
          final isShariah = (f['is_shariah'] == 1 || f['is_shariah'] == '1' || f['is_shariah'] == true);
          final displayName = '$name${isShariah ? " 🕌" : ""}';
          
          bool isStale = false;
          if (f['last_validity_date'] != null) {
            final dt = DateTime.tryParse(f['last_validity_date'].toString());
            if (dt != null) {
              final dOnly = DateTime(dt.year, dt.month, dt.day);
              if (cat == 'Commodities') {
                if (dOnly.isBefore(maxAbsoluteDate.subtract(const Duration(days: 1)))) isStale = true;
              } else if (cat == 'Money Market' || cat == 'Income' || logic == 'Annualized') {
                if (dOnly.isBefore(maxAbsoluteDate)) isStale = true;
              } else {
                if (dOnly.isBefore(maxAbsoluteDate)) isStale = true;
              }
            } else isStale = true;
          } else isStale = true;
          
          String validityDateStr = f['last_validity_date'] != null ? DateFormat('dd MMM yyyy').format(DateTime.tryParse(f['last_validity_date'].toString()) ?? DateTime.now()) : 'N/A';
          if (isStale) validityDateStr += ' (Delayed)';
          Color validityColor = isStale ? Colors.red.shade700 : Colors.black54;

          final r1d = f['return_1d'];
          final r2 = f[isLongTerm ? 'return_1y' : 'return_30d'];

          String formatPkr(dynamic r) {
            if (r == null) return 'N/A';
            double val = (r as num).toDouble();
            double pkr = 100000.0 * (val - 1.0);
            final format = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0);
            return '${pkr > 0 ? '+' : pkr < 0 ? '-' : ''}${format.format(pkr.abs())}';
          }

          Color getColor(dynamic r) {
            if (r == null) return Colors.black54;
            double val = (r as num).toDouble();
            return val >= 1.0 ? Colors.green.shade700 : Colors.red.shade700;
          }

          return SizedBox(
            height: 100, 
            child: Container(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
              child: Row(
                children: [
                  SizedBox(
                    width: 500, 
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(cat.toUpperCase(), style: GoogleFonts.poppins(color: Colors.teal.shade800, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 12),
                              Text('•', style: GoogleFonts.poppins(color: Colors.black26, fontSize: 16)),
                              const SizedBox(width: 12),
                              Text(validityDateStr, style: GoogleFonts.poppins(color: validityColor, fontSize: 14, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(displayName, style: GoogleFonts.poppins(color: Colors.black87, fontSize: 26, fontWeight: FontWeight.w600))),
                        ],
                      ),
                    )
                  ),
                  SizedBox(
                    width: 230, 
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(fit: BoxFit.scaleDown, child: Text(formatPkr(r1d), style: GoogleFonts.poppins(color: getColor(r1d), fontSize: 24, fontWeight: FontWeight.bold))),
                      ]
                    )
                  ),
                  SizedBox(
                    width: 230, 
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(fit: BoxFit.scaleDown, child: Text(formatPkr(r2), style: GoogleFonts.poppins(color: getColor(r2), fontSize: 24, fontWeight: FontWeight.bold))),
                      ]
                    )
                  ),
                ],
              ),
            ),
          );
        }

        Widget reportCard = MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.noScaling),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: OverflowBox(
              minWidth: 1080, maxWidth: 1080,
              minHeight: dynamicHeight, maxHeight: dynamicHeight,
              alignment: Alignment.topCenter,
              child: Material(
                color: Colors.white, 
                child: Container(
                  width: 1080, height: dynamicHeight,
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.all(60.0), 
                  child: Column(
                    mainAxisSize: MainAxisSize.min, 
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 120,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SizedBox(
                              width: 600,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(amc, style: GoogleFonts.poppins(color: Colors.teal.shade800, fontSize: 48, fontWeight: FontWeight.bold))),
                                  Text('Investment: PKR 1,00,000', style: GoogleFonts.poppins(color: Colors.black87, fontSize: 24), maxLines: 1),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.teal.shade800)),
                              child: Text('Bachat Vault', style: GoogleFonts.poppins(color: Colors.teal.shade800, fontSize: 28, fontWeight: FontWeight.w800)),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Divider(color: Colors.black12, thickness: 2, height: 20),
                      
                      if (groupA.isNotEmpty) ...[
                        SizedBox(
                          height: 80,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              SizedBox(width: 500, child: Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text('Money Market & Income', style: GoogleFonts.poppins(color: Colors.black54, fontSize: 24, fontWeight: FontWeight.bold)))),
                              SizedBox(width: 230, child: Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text('1D Return', textAlign: TextAlign.right, style: GoogleFonts.poppins(color: Colors.black54, fontSize: 24, fontWeight: FontWeight.bold)))),
                              SizedBox(width: 230, child: Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text('30D Return', textAlign: TextAlign.right, style: GoogleFonts.poppins(color: Colors.black54, fontSize: 24, fontWeight: FontWeight.bold)))),
                            ],
                          ),
                        ),
                        ...groupA.map((f) => buildFundRow(f, false)),
                      ],

                      if (groupA.isNotEmpty && groupB.isNotEmpty) const SizedBox(height: 40),

                      if (groupB.isNotEmpty) ...[
                        SizedBox(
                          height: 80,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              SizedBox(width: 500, child: Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text('Equity, Balanced & ETFs', style: GoogleFonts.poppins(color: Colors.black54, fontSize: 24, fontWeight: FontWeight.bold)))),
                              SizedBox(width: 230, child: Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text('1D Return', textAlign: TextAlign.right, style: GoogleFonts.poppins(color: Colors.black54, fontSize: 24, fontWeight: FontWeight.bold)))),
                              SizedBox(width: 230, child: Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text('1Y Return', textAlign: TextAlign.right, style: GoogleFonts.poppins(color: Colors.black54, fontSize: 24, fontWeight: FontWeight.bold)))),
                            ],
                          ),
                        ),
                        ...groupB.map((f) => buildFundRow(f, true)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        Uint8List capturedImage = await _screenshotController.captureFromWidget(
          reportCard, 
          delay: const Duration(milliseconds: 100),
          targetSize: Size(1080, dynamicHeight),
          pixelRatio: 1.0, 
        );
        await Gal.putImageBytes(capturedImage, name: 'BachatVault_AMC_${amc.replaceAll(' ', '')}');
        imagesSaved++;
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ $imagesSaved AMC Reports saved!'), backgroundColor: Colors.green, duration: const Duration(seconds: 4)));
      }

    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // --- CUSTOM DATE RANGE ENGINE ---
  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final defaultStart = now.subtract(const Duration(days: 30));

    DateTime initDate = isStart ? (_customStartDate ?? defaultStart) : (_customEndDate ?? now);

    if (initDate.isAfter(todayEnd)) initDate = todayEnd;
    if (initDate.isBefore(DateTime(2000))) initDate = DateTime(2000);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initDate,
      firstDate: DateTime(2000),
      lastDate: todayEnd,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: Colors.tealAccent, onPrimary: Colors.black, surface: Color(0xFF1E293B), onSurface: Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _customStartDate = picked;
        } else {
          _customEndDate = picked;
        }
      });
    }
  }

  Future<void> _calculateCustomReturns() async {
    if (_customStartDate == null || _customEndDate == null) return;
    setState(() { _isCustomLoading = true; _customReturnsMap.clear(); });
    
    try {
      final supabase = Supabase.instance.client;
      final DateFormat dbFormat = DateFormat('yyyy-MM-dd');

      DateTime trueBaseDate = _customStartDate!.subtract(const Duration(days: 1));
      final startLimit = dbFormat.format(trueBaseDate.subtract(const Duration(days: 7)));
      final startTarget = dbFormat.format(trueBaseDate);
      
      final endLimit = dbFormat.format(_customEndDate!.subtract(const Duration(days: 7)));
      final endTarget = dbFormat.format(_customEndDate!);
      final List<String> targetTickers = _displayedFunds.map((f) => f['ticker'].toString()).toList();
      if (targetTickers.isEmpty) {
        setState(() { _isCustomLoading = false; });
        return;
      }

      final startData = await supabase.from('daily_nav')
          .select('ticker, nav, validity_date')
          .inFilter('ticker', targetTickers)
          .gte('validity_date', startLimit)
          .lte('validity_date', startTarget);
      final endData = await supabase.from('daily_nav')
          .select('ticker, nav, validity_date')
          .inFilter('ticker', targetTickers)
          .gte('validity_date', endLimit)
          .lte('validity_date', endTarget);
      final payoutData = await supabase.from('payout_history')
          .select('ticker, payout_amount, ex_nav, payout_date')
          .inFilter('ticker', targetTickers)
          .gte('payout_date', startTarget)
          .lte('payout_date', endTarget);
      double? getLatestNav(List<dynamic> rows, String ticker) {
        var tickerRows = rows.where((r) => r['ticker'] == ticker).toList();
        if (tickerRows.isEmpty) return null;
        tickerRows.sort((a, b) => b['validity_date'].toString().compareTo(a['validity_date'].toString()));
        return (tickerRows[0]['nav'] as num).toDouble();
      }

      Map<String, double> newCalculations = {};
      for (String ticker in targetTickers) {
        double? startNav = getLatestNav(startData, ticker);
        double? endNav = getLatestNav(endData, ticker);

        if (startNav == null || endNav == null || startNav <= 0) continue;
        double currentUnits = 1.0;
        
        var specificPayouts = payoutData.where((p) => p['ticker'] == ticker).toList();
        for (var p in specificPayouts) {
          double pAmt = (p['payout_amount'] as num).toDouble();
          double exNav = (p['ex_nav'] as num).toDouble();
          if (exNav > 0) {
            currentUnits = currentUnits * (1 + (pAmt / exNav));
          }
        }

        double finalValue = currentUnits * endNav;
        double returnFactor = finalValue / startNav;
        
        newCalculations[ticker] = returnFactor;
      }

      setState(() {
        _customReturnsMap = newCalculations;
      });
      _applyFiltersAsync(); 
    } catch (e) {
      debugPrint("Error calculating custom returns: $e");
    } finally {
      setState(() { _isCustomLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortKey = _getSortKey();
    return Theme(
      data: Theme.of(context).copyWith(textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: GestureDetector(
            onTap: _handleSecretTap, 
            child: const Text('Performance', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 20))
          ),
          
          backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.white),
          actions: [
            if (_isAdmin)
              IconButton(
                icon: const Icon(Icons.camera_alt_outlined, color: Colors.amberAccent),
                onPressed: _showExportMenu, 
                tooltip: 'Export Reports',
              ),
            
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CompareFundsScreen(
                    allFunds: widget.allFunds, investmentAmount: _investmentAmount, benchmarkStats: widget.benchmarkStats, initialPeriod: _selectedPeriod,
                  )));
                },
                icon: const Icon(Icons.compare_arrows_rounded, color: Colors.tealAccent, size: 18),
                label: const Text('Compare', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), backgroundColor: Colors.tealAccent.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              ),
            )
          ],
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
                        children: [
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Search funds, AMCs...',
                                  hintStyle: const TextStyle(color: Colors.white38),
                                  prefixIcon: const Icon(Icons.search, color: Colors.tealAccent),
                                  suffixIcon: _searchQuery.isNotEmpty 
                                      ? IconButton(icon: const Icon(Icons.clear, color: Colors.white54, size: 18), onPressed: () { _searchController.clear(); FocusScope.of(context).unfocus(); }) 
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _onFilterChanged(() { _showFavoritesOnly = !_showFavoritesOnly; }),
                            child: Container(
                              height: 48, padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: _showFavoritesOnly ? Colors.redAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                                border: Border.all(color: _showFavoritesOnly ? Colors.redAccent : Colors.white.withOpacity(0.1)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text('❤️ Favs', style: TextStyle(color: _showFavoritesOnly ? Colors.redAccent : Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

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
                                      onChanged: (val) { if (val != null) _onFilterChanged(() { _selectedAmc = val; }); },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Fund Type', style: TextStyle(color: Colors.white70, fontSize: 11)), const SizedBox(height: 4),
                                Container(
                                  height: 48, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedShariah, isExpanded: true, dropdownColor: const Color(0xFF203A43), icon: const Icon(Icons.arrow_drop_down, color: Colors.tealAccent), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                      items: _shariahOptions.map((opt) => DropdownMenuItem<String>(value: opt, child: Text(opt))).toList(),
                                      onChanged: (val) { if (val != null) _onFilterChanged(() { _selectedShariah = val; }); },
                                    ),
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
                                const Text('Category', style: TextStyle(color: Colors.white70, fontSize: 11)), const SizedBox(height: 4),
                                Container(
                                  height: 48, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedCategory, isExpanded: true, dropdownColor: const Color(0xFF203A43), icon: const Icon(Icons.arrow_drop_down, color: Colors.tealAccent), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                      items: _categories.map((cat) => DropdownMenuItem<String>(value: cat, child: Text(cat, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                                      onChanged: (val) { if (val != null) _onFilterChanged(() { _selectedCategory = val; }); },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: ['1D', 'MTD', '30D', 'YTD', '1Y', '3Y', '5Y', '10Y', '15Y', 'Custom']
                              .map((period) {
                            final isSelected = _selectedPeriod == period;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: GestureDetector(
                                onTap: () => _onFilterChanged(() { _selectedPeriod = period; }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(color: isSelected ? Colors.tealAccent.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected ? Colors.tealAccent : Colors.white.withOpacity(0.2))),
                                  child: Row(
                                    children: [
                                      if (period == 'Custom') const Icon(Icons.date_range, size: 12, color: Colors.white70),
                                      if (period == 'Custom') const SizedBox(width: 4),
                                      Text(period, style: TextStyle(color: isSelected ? Colors.tealAccent : Colors.white70, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      if (_selectedPeriod == 'Custom')
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.tealAccent.withOpacity(0.3))),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _selectDate(context, true),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Start Date', style: TextStyle(color: Colors.white54, fontSize: 10)),
                                        Text(_customStartDate != null ? DateFormat('dd MMM yyyy').format(_customStartDate!) : 'Select Date', style: const TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_rounded, color: Colors.white38, size: 16),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _selectDate(context, false),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('End Date', style: TextStyle(color: Colors.white54, fontSize: 10)),
                                        Text(_customEndDate != null ? DateFormat('dd MMM yyyy').format(_customEndDate!) : 'Select Date', style: const TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: (_customStartDate != null && _customEndDate != null) ? _calculateCustomReturns : null,
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0)),
                                  child: _isCustomLoading 
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                      : const Text('Go', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4), const Divider(color: Colors.white24, height: 1),
                
                // --- LIST VIEW ---
                Expanded(
                  child: _isFiltering 
                    ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
                    : _displayedFunds.isEmpty
                      ? const Center(child: Text('No funds found.', style: TextStyle(color: Colors.white70)))
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 40, left: 16, right: 16), physics: const BouncingScrollPhysics(), itemCount: _displayedFunds.length,
                          itemBuilder: (context, index) {
                            final fund = _displayedFunds[index];
                            final ticker = fund['ticker'] ?? '';
                            final isFav = _favoriteTickers.contains(ticker);
                            final fundName = fund['short_name'] ?? fund['fund_name']?.toString() ?? 'Unknown';
                            final amcName = fund['short_amc_name'] ?? fund['amc_name'] ?? '';
                            final category = fund['short_category'] ?? fund['category'] ?? '';
                            final riskProfile = fund['risk_profile'] ?? '';
                            final isShariah = (fund['is_shariah'] == 1 || fund['is_shariah'] == '1' || fund['is_shariah'] == true);
                            
                            final returnFactor = _selectedPeriod == 'Custom' ? (_customReturnsMap[ticker] ?? 1.0) : (fund[sortKey] as num?)?.toDouble() ?? 1.0;
                            final double percent = _selectedPeriod == 'Custom' && !_customReturnsMap.containsKey(ticker) ? 0.0 : (returnFactor - 1.0) * 100.0;
                            final double profitValue = _selectedPeriod == 'Custom' && !_customReturnsMap.containsKey(ticker) ? 0.0 : _investmentAmount * (returnFactor - 1.0);
                            
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
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: isFav ? Colors.redAccent.withOpacity(0.3) : Colors.white.withOpacity(0.1), width: 1)),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, 
                                              children: [
                                                Expanded(flex: 6, child: Text(amcName.toString().toUpperCase(), style: const TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis)), 
                                                const SizedBox(width: 8), 
                                                Expanded(flex: 4, child: fund['last_validity_date'] != null ? Text('Validity: $lastValidityDate', textAlign: TextAlign.right, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w500)) : const SizedBox.shrink())
                                              ]
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, 
                                              children: [
                                                Expanded(flex: 7, child: Text('$fundName${isShariah ? " 🕌" : ""}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis)), 
                                                const SizedBox(width: 8), 
                                                Expanded(
                                                  flex: 4, 
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.end,
                                                    children: [
                                                      Text(formattedValueDisplay, textAlign: TextAlign.right, style: TextStyle(color: statColor, fontSize: 15, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
                                                      if (_selectedPeriod == 'Custom') 
                                                        Text(_isCustomLoading ? 'Calculating...' : (!_customReturnsMap.containsKey(ticker) ? 'No Data' : ''), style: const TextStyle(color: Colors.white54, fontSize: 10))
                                                    ],
                                                  )
                                                )
                                              ]
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                                              children: [
                                                Expanded(flex: 7, child: Row(children: [if (riskProfile.toString().isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text('Risk: $riskProfile', style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600))), Expanded(child: Text(category.toString(), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis))])), 
                                                const SizedBox(width: 8), 
                                                Row(
                                                  children: [
                                                    Text('($percentageString)', textAlign: TextAlign.right, style: TextStyle(color: statColor, fontSize: 11, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
                                                    const SizedBox(width: 8),
                                                    GestureDetector(
                                                      onTap: () => _toggleFavorite(ticker),
                                                      child: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.redAccent : Colors.white38, size: 20),
                                                    )
                                                  ],
                                                )
                                              ]
                                            )
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

class IndianNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final cleanText = newValue.text.replaceAll(',', '');
    if (cleanText.isEmpty) return newValue;
    
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0);
    try {
      final number = double.parse(cleanText);
      final formatted = formatter.format(number);
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    } catch (e) {
      return oldValue;
    }
  }
}