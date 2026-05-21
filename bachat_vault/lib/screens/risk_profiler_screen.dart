import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:bachat_vault/screens/fund_details_screen.dart';

class RiskProfilerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allFunds;
  final Map<String, dynamic> benchmarkStats;

  const RiskProfilerScreen({
    super.key,
    required this.allFunds,
    required this.benchmarkStats,
  });

  @override
  State<RiskProfilerScreen> createState() => _RiskProfilerScreenState();
}

class _RiskProfilerScreenState extends State<RiskProfilerScreen> {
  int _currentIndex = 0;
  final Map<int, int> _answers = {}; 
  bool _quizCompleted = false;
  
  // Two-way toggle state: 'Islamic', 'All'
  String _fundPreference = 'Islamic'; 

  final List<Map<String, dynamic>> _questions = [
    // --- DIMENSION A: RISK CAPACITY (The Math) ---
    {
      'question': 'When do you plan to withdraw a significant portion of this money?',
      'options': [
        {'text': 'Less than 1 year', 'score': 1}, // Hard Override
        {'text': '1 to 3 years', 'score': 2},
        {'text': '3 to 7 years', 'score': 3},
        {'text': 'More than 7 years', 'score': 4},
      ]
    },
    {
      'question': 'If you suddenly lost your primary income, how would you survive?',
      'options': [
        {'text': 'I would have to withdraw this investment immediately.', 'score': 1},
        {'text': 'I have other savings for a few months.', 'score': 2},
        {'text': 'I have a solid emergency fund; I won\'t touch this.', 'score': 3},
      ]
    },
    // --- DIMENSION B: RISK TOLERANCE (The Psychology) ---
    {
      'question': 'The PSX is highly volatile. If your portfolio dropped by 30% in a few months, what would you do?',
      'options': [
        {'text': 'Sell everything immediately to stop losses.', 'score': 1},
        {'text': 'Move half of it to safer funds.', 'score': 2},
        {'text': 'Wait it out. Markets eventually recover.', 'score': 3},
        {'text': 'Invest more money while prices are cheap.', 'score': 4},
      ]
    },
    {
      'question': 'Inflation eats your purchasing power. Which scenario do you prefer?',
      'options': [
        {'text': 'Guaranteed, stable returns, even if they fall slightly behind inflation.', 'score': 1},
        {'text': 'A mix of stability and growth to try and match inflation.', 'score': 2},
        {'text': 'High volatility to significantly beat inflation over the long term.', 'score': 3},
      ]
    },
  ];

  void _answerQuestion(int score) {
    _answers[_currentIndex] = score;

    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      setState(() => _quizCompleted = true);
    }
  }

  void _resetQuiz() {
    setState(() {
      _currentIndex = 0;
      _answers.clear();
      _quizCompleted = false;
      _fundPreference = 'Islamic'; // Reset toggle to default
    });
  }

  // --- THE 2D SCORING ENGINE ---
  Map<String, dynamic> _getProfile() {
    int q1 = _answers[0] ?? 1;
    int q2 = _answers[1] ?? 1;
    int q3 = _answers[2] ?? 1;
    int q4 = _answers[3] ?? 1;

    int capacity = q1 + q2; 
    int tolerance = q3 + q4; 

    // THE GOLDEN RULE: If Horizon is < 1 year, nothing else matters.
    if (q1 == 1) return _buildProfile('Conservative');

    if (capacity <= 3) {
      return _buildProfile('Conservative');
    } else if (capacity <= 5) {
      if (tolerance <= 4) return _buildProfile('Conservative');
      return _buildProfile('Moderate');
    } else {
      if (tolerance <= 3) return _buildProfile('Conservative');
      if (tolerance <= 5) return _buildProfile('Moderate');
      return _buildProfile('Aggressive');
    }
  }

  Map<String, dynamic> _buildProfile(String type) {
    if (type == 'Conservative') {
      return {
        'title': 'Conservative',
        'desc': 'Your capacity or tolerance for risk is low. A stable portfolio designed to protect your capital from market crashes is essential.',
        'color': Colors.blueAccent,
        'allocations': [
          {'name': 'Money Market', 'val': 80.0, 'color': Colors.blueAccent},
          {'name': 'Income', 'val': 20.0, 'color': Colors.tealAccent},
        ],
        'targetCategories': ['Money Market', 'Income']
      };
    } else if (type == 'Moderate') {
      return {
        'title': 'Moderate',
        'desc': 'You need a balanced approach. This portfolio uses Equity for long-term growth and Money Market/Income for stability during PSX corrections.',
        'color': Colors.orangeAccent,
        'allocations': [
          {'name': 'Equity', 'val': 40.0, 'color': Colors.orangeAccent},
          {'name': 'Money Market', 'val': 30.0, 'color': Colors.blueAccent},
          {'name': 'Income', 'val': 20.0, 'color': Colors.tealAccent},
          {'name': 'Commodities', 'val': 10.0, 'color': Colors.yellowAccent},
        ],
        'targetCategories': ['Equity', 'Money Market', 'Income', 'Commodities']
      };
    } else {
      return {
        'title': 'Aggressive',
        'desc': 'You have a long time horizon and nerves of steel. This portfolio aggressively targets the PSX and Commodities to beat inflation, accepting high volatility.',
        'color': Colors.redAccent,
        'allocations': [
          {'name': 'Equity', 'val': 70.0, 'color': Colors.redAccent},
          {'name': 'Money Market', 'val': 20.0, 'color': Colors.blueAccent},
          {'name': 'Commodities', 'val': 10.0, 'color': Colors.yellowAccent},
        ],
        'targetCategories': ['Equity', 'Money Market', 'Commodities']
      };
    }
  }

  // --- LOCAL MEMORY FILTERING ENGINE ---
  Future<Map<String, List<Map<String, dynamic>>>> _getSuggestedFunds(List<String> requestedGenericCategories) async {
    // 1. Simplified mappings (Dashboard already mapped short_category)
    final Map<String, List<String>> categoryMap = {
      'Money Market': ['money market', 'cash'],
      'Income': ['income'],
      'Equity': ['equity', 'index tracker', 'exchange traded fund', 'etf'],
      'Commodities': ['commodities', 'gold']
    };

    // 2. Clone the pre-loaded global data passed from Tools screen
    List<Map<String, dynamic>> allMatched = List.from(widget.allFunds);

    // 3. THE GREAT PURGE: Remove Benchmarks, Indices, AND VPS/Pension Funds
    final excludedTickers = ['GOLD_24K', 'KSE100', 'KMI30', 'CPI_PK', 'USDPKR', 'HBLTETF'];
    allMatched.removeWhere((f) {
      final ticker = f['ticker']?.toString().toUpperCase() ?? '';
      final amc = (f['amc_name'] ?? f['short_amc_name'])?.toString().toLowerCase() ?? '';
      final fundName = (f['fund_name'] ?? f['short_name'])?.toString().toLowerCase() ?? '';
      final category = (f['category'] ?? f['short_category'])?.toString().toLowerCase() ?? '';

      // Rule A: Is it a benchmark or index?
      bool isNoise = excludedTickers.contains(ticker) || amc.contains('benchmark') || amc.contains('indices');
      
      // Rule B: Is it a Voluntary Pension Scheme?
      bool isVPS = fundName.contains('vps') || fundName.contains('pension') || category.contains('vps') || category.contains('pension');

      return isNoise || isVPS;
    });

    // 4. Apply 2-Way Toggle (Islamic, All)
    allMatched = allMatched.where((f) {
      bool fundIsShariah = f['is_shariah'] == 1 || f['is_shariah'] == '1' || f['is_shariah'] == true;
      if (_fundPreference == 'Islamic') return fundIsShariah;
      return true; // If 'All', return both Islamic and Conventional
    }).toList();

    // 5. Group, Sort, and Slice
    Map<String, List<Map<String, dynamic>>> groupedFunds = {};
    
    for (String genericCat in requestedGenericCategories) {
      var specificFunds = allMatched.where((f) {
        String dbCat = (f['category'] ?? f['short_category'] ?? '').toString().toLowerCase();
        List<String> targets = categoryMap[genericCat] ?? [];
        return targets.any((t) => dbCat.contains(t));
      }).toList();
      
      // Sort Logic: Equity/Commodities use 3Y, Money Market/Income use 30D
      if (genericCat == 'Equity' || genericCat == 'Commodities') {
        specificFunds.sort((a, b) => ((b['return_3y'] as num?)?.toDouble() ?? -999.0).compareTo((a['return_3y'] as num?)?.toDouble() ?? -999.0));
      } else {
        specificFunds.sort((a, b) => ((b['return_30d'] as num?)?.toDouble() ?? -999.0).compareTo((a['return_30d'] as num?)?.toDouble() ?? -999.0));
      }

      if (specificFunds.isNotEmpty) {
        groupedFunds[genericCat] = specificFunds.take(2).toList();
      }
    }
    
    return groupedFunds;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Smart Risk Profiler', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: Colors.white),
        ),
        body: Container(
          width: double.infinity, height: double.infinity,
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF000000)])),
          child: SafeArea(
            child: _quizCompleted ? _buildResultsScreen() : _buildQuizScreen(),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizScreen() {
    final question = _questions[_currentIndex];
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Question ${_currentIndex + 1} of ${_questions.length}', style: const TextStyle(color: Colors.tealAccent, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Text(question['question'], style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.3)),
          const SizedBox(height: 32),
          ...List.generate(question['options'].length, (index) {
            final option = question['options'][index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: InkWell(
                onTap: () => _answerQuestion(option['score']),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Text(option['text'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResultsScreen() {
    final profile = _getProfile();
    final allocations = profile['allocations'] as List;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.psychology, color: Colors.white, size: 60),
          const SizedBox(height: 16),
          const Text('Your Investor Profile', style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w600)),
          Text(profile['title'], style: TextStyle(color: profile['color'], fontSize: 32, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text(profile['desc'], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
          
          const SizedBox(height: 40),
          const Text('Recommended Asset Allocation', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2, centerSpaceRadius: 60,
                    sections: allocations.map((e) => PieChartSectionData(
                      color: e['color'], value: e['val'], radius: 25, showTitle: false,
                    )).toList(),
                  ),
                ),
                Text('100%', style: TextStyle(color: profile['color'], fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          ...allocations.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: e['color'], shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(child: Text(e['name'], style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500))),
                Text('${e['val'].toInt()}%', style: TextStyle(color: e['color'], fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          )),

          const SizedBox(height: 40),
          const Align(alignment: Alignment.centerLeft, child: Text('Top Suggested Funds', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
          const SizedBox(height: 16),

          // --- 2-WAY SHARIAH TOGGLE UI ---
          Container(
            height: 45,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
            child: Row(
              children: [
                _buildToggleOption('Islamic', '🕌'),
                _buildToggleOption('All', '🌍'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
            future: _getSuggestedFunds(List<String>.from(profile['targetCategories'])),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: Colors.tealAccent)));
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text('No matching funds found for this preference.', style: TextStyle(color: Colors.white54));
              
              final groupedFunds = snapshot.data!;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: groupedFunds.entries.map((entry) {
                  String categoryName = entry.key;
                  List<Map<String, dynamic>> funds = entry.value;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
                        child: Text(categoryName.toUpperCase(), style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                      ),
                      ...funds.map((fund) {
                        bool isLongTerm = (categoryName == 'Equity' || categoryName == 'Commodities');
                        double? returnVal = (isLongTerm ? fund['return_3y'] : fund['return_30d'])?.toDouble();
                        String returnText = returnVal != null ? '${((returnVal - 1.0) * 100).toStringAsFixed(2)}%' : 'N/A';
                        String returnLabel = isLongTerm ? '3Y Return' : '30D Yield';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FundDetailsScreen(
                                    fund: fund,
                                    investmentAmount: 100000, 
                                    benchmarkStats: widget.benchmarkStats,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05), 
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.account_balance_wallet, color: Colors.white38),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(fund['short_name'] ?? fund['fund_name'], style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text(fund['short_amc_name'] ?? fund['amc_name'] ?? 'AMC', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(returnText, style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                                      Text(returnLabel, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                  );
                }).toList(),
              );
            },
          ),
          
          const SizedBox(height: 32),
          TextButton.icon(
            onPressed: _resetQuiz,
            icon: const Icon(Icons.refresh, color: Colors.white54),
            label: const Text('Retake Quiz', style: TextStyle(color: Colors.white54)),
          )
        ],
      ),
    );
  }

  Widget _buildToggleOption(String title, String emoji) {
    bool isSelected = _fundPreference == title;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _fundPreference = title),
        child: Container(
          decoration: BoxDecoration(color: isSelected ? Colors.tealAccent.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Text('$title $emoji', style: TextStyle(color: isSelected ? Colors.tealAccent : Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }
}