import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';

class RiskProfilerScreen extends StatefulWidget {
  const RiskProfilerScreen({super.key});

  @override
  State<RiskProfilerScreen> createState() => _RiskProfilerScreenState();
}

class _RiskProfilerScreenState extends State<RiskProfilerScreen> {
  int _currentIndex = 0;
  int _totalScore = 0;
  bool _quizCompleted = false;

  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'When do you plan to withdraw a significant portion of this money?',
      'options': [
        {'text': 'Less than 1 year', 'score': 1},
        {'text': '1 to 3 years', 'score': 2},
        {'text': '3 to 7 years', 'score': 3},
        {'text': 'More than 7 years', 'score': 4},
      ]
    },
    {
      'question': 'What is your main objective for this portfolio?',
      'options': [
        {'text': 'Protect my money (Capital Preservation)', 'score': 1},
        {'text': 'Generate steady income', 'score': 2},
        {'text': 'Moderate growth with some safety', 'score': 3},
        {'text': 'Maximum long-term growth', 'score': 4},
      ]
    },
    {
      'question': 'If your portfolio dropped 20% in a month due to a market crash, what would you do?',
      'options': [
        {'text': 'Panic and sell everything', 'score': 1},
        {'text': 'Sell some to be safe', 'score': 2},
        {'text': 'Do nothing and wait it out', 'score': 3},
        {'text': 'Buy more at a discount', 'score': 4},
      ]
    },
    {
      'question': 'Which hypothetical portfolio would you choose?',
      'options': [
        {'text': 'Avg 5% gain / Max 0% drop', 'score': 1},
        {'text': 'Avg 10% gain / Max 5% drop', 'score': 2},
        {'text': 'Avg 15% gain / Max 15% drop', 'score': 3},
        {'text': 'Avg 20% gain / Max 25% drop', 'score': 4},
      ]
    },
    {
      'question': 'How stable is your current primary source of income?',
      'options': [
        {'text': 'Very unstable', 'score': 1},
        {'text': 'Somewhat stable', 'score': 2},
        {'text': 'Very stable', 'score': 4},
      ]
    },
  ];

  void _answerQuestion(int score) {
    _totalScore += score;
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      setState(() => _quizCompleted = true);
    }
  }

  void _resetQuiz() {
    setState(() {
      _currentIndex = 0;
      _totalScore = 0;
      _quizCompleted = false;
    });
  }

  Map<String, dynamic> _getProfile() {
    if (_totalScore <= 9) {
      return {
        'title': 'Conservative',
        'desc': 'You prioritize safety over high returns. A stable, low-risk portfolio is best for you.',
        'color': Colors.blueAccent,
        'allocations': [
          {'name': 'Money Market', 'val': 70.0, 'color': Colors.blueAccent},
          {'name': 'Income/Debt', 'val': 20.0, 'color': Colors.tealAccent},
          {'name': 'Gold/Commodity', 'val': 10.0, 'color': Colors.yellowAccent},
        ],
        'targetCategories': ['Money Market', 'Income']
      };
    } else if (_totalScore <= 15) {
      return {
        'title': 'Moderate',
        'desc': 'You want a balance of growth and stability. A diversified mix of equity and debt suits you.',
        'color': Colors.orangeAccent,
        'allocations': [
          {'name': 'Equity', 'val': 50.0, 'color': Colors.orangeAccent},
          {'name': 'Money Market', 'val': 30.0, 'color': Colors.blueAccent},
          {'name': 'Income/Debt', 'val': 20.0, 'color': Colors.tealAccent},
        ],
        'targetCategories': ['Equity', 'Asset Allocation', 'Income']
      };
    } else {
      return {
        'title': 'Aggressive',
        'desc': 'You are willing to take significant risks for maximum long-term growth.',
        'color': Colors.redAccent,
        'allocations': [
          {'name': 'Equity', 'val': 80.0, 'color': Colors.redAccent},
          {'name': 'Gold/Commodity', 'val': 10.0, 'color': Colors.yellowAccent},
          {'name': 'Money Market', 'val': 10.0, 'color': Colors.blueAccent},
        ],
        'targetCategories': ['Equity', 'Commodity']
      };
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSuggestedFunds(List<String> categories) async {
    final res = await Supabase.instance.client
        .from('master_funds')
        .select('fund_name, category, ticker, amc_name')
        .filter('category', 'in', categories)
        .limit(5); // In Phase 4, we will order this by the Bachat Vault Score!
    return List<Map<String, dynamic>>.from(res);
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
          const Align(alignment: Alignment.centerLeft, child: Text('Suggested Funds For You', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
          const SizedBox(height: 16),
          
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchSuggestedFunds(List<String>.from(profile['targetCategories'])),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.tealAccent));
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text('No funds found.', style: TextStyle(color: Colors.white54));
              
              return Column(
                children: snapshot.data!.map((fund) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      const Icon(Icons.trending_up, color: Colors.tealAccent),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fund['fund_name'], style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(fund['category'], style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )).toList(),
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
}