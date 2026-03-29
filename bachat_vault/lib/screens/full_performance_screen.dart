import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bachat_vault/screens/fund_details_screen.dart';
import 'package:bachat_vault/screens/compare_funds_screen.dart';
import 'package:flutter/services.dart';

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
  late double _investmentAmount;
  late TextEditingController _investmentController;
  late TextEditingController _searchController;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0);

  // Filters
  List<String> _categories = ['All'];
  List<String> _amcs = ['All'];
  final List<String> _shariahOptions = ['All', 'Islamic', 'Conventional'];
  String _selectedCategory = 'All';
  String _selectedAmc = 'All';
  String _selectedPeriod = '1D';
  String _selectedShariah = 'All';
  String _searchQuery = '';

  // Favorites Storage
  List<String> _favoriteTickers = [];
  bool _showFavoritesOnly = false;

  // Custom Date Range
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isCustomLoading = false;

  // Performance Optimization
  List<Map<String, dynamic>> _displayedFunds = [];
  bool _isFiltering = false;

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
    _applyFiltersAsync(); // Initial Load
  }

  @override
  void dispose() {
    _investmentController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- LOCAL STORAGE FOR FAVORITES ---
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

  // --- PERFORMANCE OPTIMIZATION (Fixes Dropdown Lag) ---
  void _onFilterChanged(VoidCallback updateState) {
    updateState();
    setState(() { _isFiltering = true; });
    // This tiny delay lets the UI animation finish BEFORE the heavy math starts
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
      final cat = mf['category']; if (cat != null && cat.toString().isNotEmpty) categorySet.add(cat.toString().trim());
      final amc = mf['amc_name']; if (amc != null && amc.toString().isNotEmpty) amcSet.add(amc.toString().trim());
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
      case 'Custom': return 'return_1d'; // Placeholder for custom
      default: return 'return_1d';
    }
  }

  List<Map<String, dynamic>> _getFilteredAndSortedFunds() {
    final sortKey = _getSortKey();
    var filtered = widget.allFunds.toList();

    // Favorites Filter
    if (_showFavoritesOnly) {
      filtered = filtered.where((f) => _favoriteTickers.contains(f['ticker'])).toList();
    }

    // SEARCH BAR BYPASS LOGIC
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((f) {
        final name = f['fund_name']?.toString().toLowerCase() ?? '';
        final amc = f['amc_name']?.toString().toLowerCase() ?? '';
        return name.contains(query) || amc.contains(query);
      }).toList();
    } else {
      // Normal Dropdown Filters apply ONLY if Search is empty
      if (_selectedCategory != 'All') {
        filtered = filtered.where((f) => f['category']?.toString().trim() == _selectedCategory).toList();
      }
      if (_selectedAmc != 'All') {
        filtered = filtered.where((f) => f['amc_name']?.toString().trim() == _selectedAmc).toList();
      }
      if (_selectedShariah == 'Islamic') {
        filtered = filtered.where((f) => f['is_shariah'] == 1 || f['is_shariah'] == '1' || f['is_shariah'] == true).toList();
      } else if (_selectedShariah == 'Conventional') {
        filtered = filtered.where((f) => f['is_shariah'] != 1 && f['is_shariah'] != '1' && f['is_shariah'] != true).toList();
      }
    }

    // Filter out null returns (Unless Custom is selected, we'll calculate that later)
    if (_selectedPeriod != 'Custom') {
      filtered = filtered.where((f) => f[sortKey] != null).toList();
    }

    // SMART SORTING
    filtered.sort((a, b) {
      final valA = (a[sortKey] as num?)?.toDouble() ?? 0.0;
      final valB = (b[sortKey] as num?)?.toDouble() ?? 0.0;
      
      final logicA = a['return_logic']?.toString().trim() ?? '';
      final logicB = b['return_logic']?.toString().trim() ?? '';

      if (logicA == 'Absolute' && logicB == 'Absolute') {
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

  // --- CUSTOM DATE PICKER WIDGETS ---
  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_customStartDate ?? DateTime.now().subtract(const Duration(days: 30))) : (_customEndDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
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

  void _calculateCustomReturns() async {
    if (_customStartDate == null || _customEndDate == null) return;
    
    setState(() { _isCustomLoading = true; });
    
    // TODO: This is where we will write the Supabase fetch and math logic!
    await Future.delayed(const Duration(seconds: 2)); // Simulating network request
    
    setState(() { _isCustomLoading = false; });
  }

  // --- NAME CLEANER ---
  String _cleanFundName(String name) {
    return name.replaceAll('Exchange Traded Fund', 'ETF').replaceAll('Government', 'Govt.').trim();
    // (I kept it brief here for visual clarity, but feel free to paste your giant 50-line replacement block right back in here!)
  }

  @override
  Widget build(BuildContext context) {
    final sortKey = _getSortKey();

    return Theme(
      data: Theme.of(context).copyWith(textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Performance', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 20)),
          backgroundColor: Colors.transparent, elevation: 0, leading: const BackButton(color: Colors.white),
          actions: [
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
                      // --- NEW: SEARCH BAR & FAVORITES TOGGLE ---
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

                      // Investment Amount and AMC Dropdown
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
                      
                      // Fund Type and Category
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
                      
                      // Time Periods List
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

                      // --- NEW: CUSTOM DATE UI EXPANSION ---
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
                            final fundName = _cleanFundName(fund['fund_name']?.toString() ?? 'Unknown');
                            final amcName = fund['amc_name'] ?? '';
                            final category = fund['category'] ?? '';
                            final riskProfile = fund['risk_profile'] ?? '';
                            final isShariah = (fund['is_shariah'] == 1 || fund['is_shariah'] == '1' || fund['is_shariah'] == true);
                            
                            // Return calculation math
                            final returnFactor = _selectedPeriod == 'Custom' ? 1.0 : (fund[sortKey] as num?)?.toDouble() ?? 1.0;
                            final double percent = _selectedPeriod == 'Custom' ? 0.0 : (returnFactor - 1.0) * 100.0;
                            final double profitValue = _selectedPeriod == 'Custom' ? 0.0 : _investmentAmount * (returnFactor - 1.0);
                            
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
                                                      if (_selectedPeriod == 'Custom') const Text('Pending...', style: TextStyle(color: Colors.white54, fontSize: 10))
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
                                                
                                                // --- NEW: THE HEART ICON ---
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

// Ensure your IndianNumberFormatter class remains at the bottom of the file exactly as you had it!
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