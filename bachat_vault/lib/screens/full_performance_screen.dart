import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:bachat_vault/screens/fund_details_screen.dart';
import 'package:bachat_vault/screens/compare_funds_screen.dart';
import 'package:flutter/services.dart';

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

  List<String> _categories = ['All'];
  List<String> _amcs = ['All'];
  final List<String> _shariahOptions = ['All', 'Islamic', 'Conventional']; // ADDED: Shariah Options List
  String _selectedCategory = 'All';
  String _selectedAmc = 'All';
  String _selectedPeriod = '1D';
  String _selectedShariah = 'All'; // ADDED: Current Shariah State

  @override
  void initState() {
    super.initState();
    _investmentAmount = widget.initialInvestment;
    _investmentController = TextEditingController(text: _currencyFormat.format(_investmentAmount));
    _setupFilters();
  }

  @override
  void dispose() { 
    _investmentController.dispose(); 
    super.dispose(); 
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
      // Defaults to Equity if it exists in the list!
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
      default: return 'return_1d';
    }
  }

List<Map<String, dynamic>> _getFilteredAndSortedFunds() {
    final sortKey = _getSortKey();
    var filtered = widget.allFunds.where((f) => f[sortKey] != null).toList();
    
    // 1. Filter by Category
    if (_selectedCategory != 'All') {
      filtered = filtered.where((f) => f['category']?.toString().trim() == _selectedCategory).toList();
    }
    
    // 2. Filter by AMC
    if (_selectedAmc != 'All') {
      filtered = filtered.where((f) => f['amc_name']?.toString().trim() == _selectedAmc).toList();
    }
    
    // 3. Filter by Shariah (ADDED)
    if (_selectedShariah == 'Islamic') {
      filtered = filtered.where((f) => f['is_shariah'] == 1 || f['is_shariah'] == '1' || f['is_shariah'] == true).toList();
    } else if (_selectedShariah == 'Conventional') {
      filtered = filtered.where((f) => f['is_shariah'] != 1 && f['is_shariah'] != '1' && f['is_shariah'] != true).toList();
    }

    // 4. SMART SORTING: Date first for Absolute, Returns first for everything else
    filtered.sort((a, b) { 
      final valA = (a[sortKey] as num).toDouble(); 
      final valB = (b[sortKey] as num).toDouble(); 
      
      final logicA = a['return_logic']?.toString().trim() ?? '';
      final logicB = b['return_logic']?.toString().trim() ?? '';

      // If BOTH are Absolute, factor in the date
      if (logicA == 'Absolute' && logicB == 'Absolute') {
        final dateStrA = a['last_validity_date']?.toString();
        final dateStrB = b['last_validity_date']?.toString();
        
        // Parse dates safely (use a very old date as a fallback if null)
        final dateA = dateStrA != null ? (DateTime.tryParse(dateStrA) ?? DateTime(1970)) : DateTime(1970);
        final dateB = dateStrB != null ? (DateTime.tryParse(dateStrB) ?? DateTime(1970)) : DateTime(1970);

        // Compare dates (descending: newer dates bubble to the top)
        int dateComparison = dateB.compareTo(dateA);
        
        // If dates are different, sort by date
        if (dateComparison != 0) {
          return dateComparison;
        }
        // If dates are exactly the same, fall through and sort by return value
      }

      // Default sort purely by return value (Descending: highest return first)
      return valB.compareTo(valA); 
    });

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
                      
                      // ADDED: Split Row for Fund Type and Category (Swapped)
                      Row(
                        children: [
                          Expanded(
                            flex: 4, // CHANGED: Matches Investment Amount exactly
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Fund Type', style: TextStyle(color: Colors.white70, fontSize: 11)), const SizedBox(height: 4),
                                Container(
                                  height: 48, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedShariah, isExpanded: true, dropdownColor: const Color(0xFF203A43), menuMaxHeight: 350, icon: const Icon(Icons.arrow_drop_down, color: Colors.tealAccent), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500), isDense: true,
                                      items: _shariahOptions.map((opt) => DropdownMenuItem<String>(value: opt, child: Text(opt, style: const TextStyle(fontSize: 13)))).toList(),
                                      onChanged: (val) { if (val != null) setState(() { _selectedShariah = val; }); },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 6, // CHANGED: Matches AMC Name exactly
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Category', style: TextStyle(color: Colors.white70, fontSize: 11)), const SizedBox(height: 4),
                                Container(
                                  height: 48, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedCategory, isExpanded: true, dropdownColor: const Color(0xFF203A43), menuMaxHeight: 350, icon: const Icon(Icons.arrow_drop_down, color: Colors.tealAccent), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500), isDense: true,
                                      items: _categories.map((cat) => DropdownMenuItem<String>(value: cat, child: Text(cat, maxLines: 2, overflow: TextOverflow.visible, style: const TextStyle(fontSize: 13)))).toList(),
                                      onChanged: (val) { if (val != null) setState(() { _selectedCategory = val; }); },
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
                          children: ['1D', 'MTD', '30D', 'YTD', '1Y', '3Y', '5Y', '10Y', '15Y']
                              .map((period) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: _buildFilterButton(period),
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
                            final fundName = _cleanFundName(fund['fund_name']?.toString() ?? 'Unknown');
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