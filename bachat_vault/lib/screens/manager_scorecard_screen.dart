import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bachat_vault/screens/dashboard.dart'; 
import 'package:bachat_vault/screens/fund_details_screen.dart';
import 'package:bachat_vault/screens/scorecard_engine.dart'; // Verify this path matches your project structure

class ManagerScorecardScreen extends StatefulWidget {
  const ManagerScorecardScreen({super.key});

  @override
  State<ManagerScorecardScreen> createState() => _ManagerScorecardScreenState();
}

class _ManagerScorecardScreenState extends State<ManagerScorecardScreen> {
  List<Map<String, dynamic>> _allRankedFunds = [];
  String _selectedCategory = 'All';
  
  // Updated list: Only showing actively managed core categories
  final List<String> _categories = ['All', 'Equity', 'Asset Allocation', 'Balanced'];

  @override
  void initState() {
    super.initState();
    // Generate the rankings instantly from our local memory vault
    _allRankedFunds = ScorecardEngine.generateRankings(AppData.allFunds);
  }

  // Filter the list based on the user's selected tab
  List<Map<String, dynamic>> get _displayedFunds {
    if (_selectedCategory == 'All') return _allRankedFunds;
    
    return _allRankedFunds.where((f) {
      String cat = (f['short_category'] ?? f['category'] ?? '').toString().toLowerCase();
      
      if (_selectedCategory == 'Equity') return cat.contains('equity') && !cat.contains('index') && !cat.contains('etf');
      if (_selectedCategory == 'Asset Allocation') return cat.contains('asset allocation');
      if (_selectedCategory == 'Balanced') return cat.contains('balanced');
      
      return false;
    }).toList();
  }

  // Helper to determine medal colors for Top 3
  Color _getRankColor(int index) {
    if (index == 0) return const Color(0xFFFFD700); // Gold
    if (index == 1) return const Color(0xFFC0C0C0); // Silver
    if (index == 2) return const Color(0xFFCD7F32); // Bronze
    return Colors.white24; // Standard
  }

  @override
  Widget build(BuildContext context) {
    final displayedFunds = _displayedFunds;

    return Theme(
      data: Theme.of(context).copyWith(textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Manager Scorecard', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: Colors.white),
        ),
        body: Container(
          width: double.infinity, height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF000000)]),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header Details
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Text(
                    'Ranked by profitability, risk-management, and cost efficiency in actively managed funds.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
                
                const SizedBox(height: 16),

                // Category Filter Scroll
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      bool isSelected = _selectedCategory == _categories[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: InkWell(
                          onTap: () => setState(() => _selectedCategory = _categories[index]),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.tealAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? Colors.tealAccent : Colors.transparent),
                            ),
                            child: Text(
                              _categories[index],
                              style: TextStyle(
                                color: isSelected ? Colors.tealAccent : Colors.white54,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Leaderboard List
                Expanded(
                  child: displayedFunds.isEmpty
                      ? const Center(child: Text('No funds have sufficient data to be ranked in this category.', style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          physics: const BouncingScrollPhysics(),
                          itemCount: displayedFunds.length,
                          itemBuilder: (context, index) {
                            final fund = displayedFunds[index];
                            final score = fund['bachat_score'] as double;
                            final isTop3 = index < 3;
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FundDetailsScreen(
                                        fund: fund,
                                        investmentAmount: 100000,
                                        benchmarkStats: AppData.benchmarkStats,
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isTop3 ? _getRankColor(index).withOpacity(0.5) : Colors.white.withOpacity(0.05)),
                                  ),
                                  child: Row(
                                    children: [
                                      // Rank Number
                                      Container(
                                        width: 32,
                                        alignment: Alignment.center,
                                        child: Text(
                                          '#${index + 1}',
                                          style: TextStyle(
                                            color: _getRankColor(index),
                                            fontSize: isTop3 ? 20 : 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      
                                      // Fund & Manager Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              fund['fund_manager']?.toString().isNotEmpty == true 
                                                  ? fund['fund_manager'] 
                                                  : 'Manager Unknown',
                                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                              maxLines: 1, overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              fund['short_name'] ?? fund['fund_name'],
                                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                                              maxLines: 1, overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              fund['short_amc_name'] ?? fund['amc_name'] ?? 'AMC',
                                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Score Display
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.tealAccent.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              score.toStringAsFixed(1),
                                              style: const TextStyle(color: Colors.tealAccent, fontSize: 18, fontWeight: FontWeight.w900),
                                            ),
                                            const Text(
                                              '/ 10',
                                              style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      )
                                    ],
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