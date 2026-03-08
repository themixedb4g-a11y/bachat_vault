import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _allFunds = [];
  List<String> _categories = ['All'];
  List<String> _amcs = ['All']; // New AMC List
  
  String _selectedCategory = 'All';
  String _selectedAmc = 'All'; // New AMC selection
  String _selectedPeriod = '1D'; 
  double _investmentAmount = 100.0;
  
  final TextEditingController _investmentController = TextEditingController(text: '100');
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '', decimalDigits: 0);

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
      final masterResponse = await supabase.from('master_funds').select();
      final statsResponse = await supabase.from('performance_stats').select();

      final List<Map<String, dynamic>> combined = [];
      final Set<String> categorySet = {};
      final Set<String> amcSet = {}; // Track unique AMCs

      for (var mf in masterResponse) {
        final ticker = mf['ticker'];
        final stats = statsResponse.firstWhere(
          (s) => s['ticker'] == ticker, 
          orElse: () => <String, dynamic>{},
        );

        combined.add({
          ...mf,
          'return_1d': stats['return_1d'],
          'return_30d': stats['return_30d'],
          'return_1y': stats['return_1y'],
          'return_3y': stats['return_3y'],
          'return_5y': stats['return_5y'],
          'return_10y': stats['return_10y'],
          'return_15y': stats['return_15y'],
          'return_20y': stats['return_20y'],
        });

        // Add to Categories
        final cat = mf['category'];
        if (cat != null && cat.toString().isNotEmpty) {
          categorySet.add(cat.toString().trim());
        }

        // Add to AMCs
        final amc = mf['amc_name'];
        if (amc != null && amc.toString().isNotEmpty) {
          amcSet.add(amc.toString().trim());
        }
      }

      final sortedCategories = categorySet.toList()..sort();
      final sortedAmcs = amcSet.toList()..sort();
      
      setState(() {
        _allFunds = combined;
        
        _categories = ['All', ...sortedCategories];
        if (!_categories.contains(_selectedCategory)) {
          _selectedCategory = 'All';
        }

        _amcs = ['All', ...sortedAmcs];
        if (!_amcs.contains(_selectedAmc)) {
          _selectedAmc = 'All';
        }

        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 20) return 'Good Evening';
    return 'Good Night';
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
      default: return 'return_1d';
    }
  }

  List<Map<String, dynamic>> _getFilteredAndSortedFunds() {
    final sortKey = _getSortKey();
    var filtered = _allFunds.where((f) => f[sortKey] != null).toList();

    if (_selectedCategory != 'All') {
      filtered = filtered.where((f) => f['category']?.toString().trim() == _selectedCategory).toList();
    }
    
    // Filter by AMC
    if (_selectedAmc != 'All') {
      filtered = filtered.where((f) => f['amc_name']?.toString().trim() == _selectedAmc).toList();
    }

    filtered.sort((a, b) {
      final valA = (a[sortKey] as num).toDouble();
      final valB = (b[sortKey] as num).toDouble();
      return valB.compareTo(valA); 
    });

    return filtered;
  }

  Widget _buildFilterButton(String label) {
    final isSelected = _selectedPeriod == label;
    // By using a smaller padding, tighter text, and less margin, we squeeze 8 items
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriod = label;
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 6), // Squeezed height
          decoration: BoxDecoration(
            color: isSelected ? Colors.tealAccent.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.tealAccent : Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.tealAccent : Colors.white70,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              fontSize: 11, // Smaller text to fit all natively
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedFunds = _getFilteredAndSortedFunds();
    final sortKey = _getSortKey();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _getGreeting(),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchData,
          )
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
            colors: [
              Color(0xFF0F2027),
              Color(0xFF203A43),
              Color(0xFF2C5364),
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
              : _errorMessage != null
                  ? Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.redAccent)))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Control Panel
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              
                              // Row: Investment Amount | AMC Name
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Left side: Investment Amount
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Investment Amount', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                        const SizedBox(height: 4),
                                        SizedBox(
                                          height: 48,
                                          child: TextField(
                                            controller: _investmentController,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            textAlignVertical: TextAlignVertical.center,
                                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                            decoration: InputDecoration(
                                              prefixText: 'PKR ',
                                              prefixStyle: const TextStyle(color: Colors.tealAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                              filled: true,
                                              fillColor: Colors.white.withOpacity(0.1),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide.none,
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                            ),
                                            onChanged: (val) {
                                              setState(() {
                                                _investmentAmount = double.tryParse(val) ?? 0.0;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Right side: AMC Dropdown
                                  Expanded(
                                    flex: 6,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('AMC Name', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                        const SizedBox(height: 4),
                                        Container(
                                          height: 48,
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: _selectedAmc,
                                              isExpanded: true,
                                              dropdownColor: const Color(0xFF203A43),
                                              icon: const Icon(Icons.arrow_drop_down, color: Colors.tealAccent),
                                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                              // isDense helps fit long text within standard heights without overflowing
                                              isDense: true, 
                                              items: _amcs.map((amc) {
                                                return DropdownMenuItem<String>(
                                                  value: amc,
                                                  child: Text(
                                                    amc,
                                                    maxLines: 2, 
                                                    overflow: TextOverflow.visible, 
                                                    style: const TextStyle(fontSize: 13),
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (val) {
                                                if (val != null) {
                                                  setState(() {
                                                    _selectedAmc = val;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              // Category Dropdown
                              const Text('Category', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 4),
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedCategory,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF203A43),
                                    icon: const Icon(Icons.arrow_drop_down, color: Colors.tealAccent),
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                    isDense: true,
                                    items: _categories.map((cat) {
                                      return DropdownMenuItem<String>(
                                        value: cat,
                                        child: Text(
                                          cat,
                                          maxLines: 2,
                                          overflow: TextOverflow.visible,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedCategory = val;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Squeezed Filters Toolbar (No scrolling, using a Row of Expandeds)
                              Row(
                                children: [
                                  _buildFilterButton('1D'),
                                  _buildFilterButton('30D'),
                                  _buildFilterButton('1Y'),
                                  _buildFilterButton('3Y'),
                                  _buildFilterButton('5Y'),
                                  _buildFilterButton('10Y'),
                                  _buildFilterButton('15Y'),
                                  _buildFilterButton('20Y'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 4),
                        const Divider(color: Colors.white24, height: 1),
                        
                        // Funds List
                        Expanded(
                          child: displayedFunds.isEmpty
                              ? const Center(child: Text('No funds found for this timeframe.', style: TextStyle(color: Colors.white70)))
                              : ListView.builder(
                                  padding: const EdgeInsets.only(top: 8, bottom: 40, left: 16, right: 16),
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: displayedFunds.length,
                                  itemBuilder: (context, index) {
                                    final fund = displayedFunds[index];
                                    final fundName = fund['fund_name'] ?? 'Unknown Fund';
                                    final amcName = fund['amc_name'] ?? '';
                                    final category = fund['category'] ?? '';
                                    final riskProfile = fund['risk_profile'] ?? '';
                                    
                                    final isShariah = (fund['is_shariah'] == 1 || fund['is_shariah'] == '1' || fund['is_shariah'] == true);
                                    
                                    final returnFactor = (fund[sortKey] as num).toDouble();
                                    
                                    final double profitValue = _investmentAmount * (returnFactor - 1.0);
                                    final double percentageValue = (returnFactor - 1.0) * 100.0;
                                    
                                    String profitString = _currencyFormat.format(profitValue.abs());
                                    String formattedValueDisplay = '';
                                    if (profitValue > 0) {
                                      formattedValueDisplay = '+$profitString';
                                    } else if (profitValue < 0) {
                                      formattedValueDisplay = '-$profitString';
                                    } else {
                                      formattedValueDisplay = '0';
                                    }

                                    String percentageString = '${percentageValue > 0 ? '+' : ''}${percentageValue.toStringAsFixed(2)}%';
                                    
                                    Color statColor = Colors.white70;
                                    if (returnFactor > 1.0) {
                                      statColor = Colors.greenAccent;
                                    } else if (returnFactor < 1.0) {
                                      statColor = Colors.redAccent.shade100;
                                    }

                                    // Tight Layout logic
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Top row: AMC Name | Risk Profile
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        amcName.toString().toUpperCase(),
                                                        style: const TextStyle(
                                                          color: Colors.tealAccent,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w600,
                                                          letterSpacing: 0.5,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        'Risk: $riskProfile',
                                                        style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                
                                                // Equal Vertical Spacing (Top)
                                                const SizedBox(height: 6),
                                                
                                                // Middle Row: Fund Name | Profit Value
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      flex: 6,
                                                      child: Text(
                                                        '$fundName${isShariah ? " 🕌" : ""}',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w800,
                                                          height: 1.2,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      flex: 4,
                                                      child: Text(
                                                        formattedValueDisplay,
                                                        textAlign: TextAlign.right,
                                                        style: TextStyle(
                                                          color: statColor,
                                                          fontSize: 15, // Same font size as Name
                                                          fontWeight: FontWeight.w800,
                                                          fontFeatures: const [FontFeature.tabularFigures()],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),

                                                // Equal Vertical Spacing (Bottom)
                                                const SizedBox(height: 6),
                                                
                                                // Bottom Row: Category | Percentage
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      flex: 6,
                                                      child: Text(
                                                        category.toString(),
                                                        style: TextStyle(
                                                          color: Colors.white.withOpacity(0.5),
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      flex: 4,
                                                      child: Text(
                                                        '($percentageString)',
                                                        textAlign: TextAlign.right,
                                                        style: TextStyle(
                                                          color: statColor,
                                                          fontSize: 11, // Match category size intuitively
                                                          fontWeight: FontWeight.w700,
                                                          fontFeatures: const [FontFeature.tabularFigures()],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
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
    );
  }
}
