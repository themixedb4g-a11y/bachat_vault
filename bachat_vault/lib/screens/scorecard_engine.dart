class ScorecardEngine {
  /// Parses the raw Supabase list and returns a ranked list of actively managed funds
  static List<Map<String, dynamic>> generateRankings(List<Map<String, dynamic>> allFunds) {
    List<Map<String, dynamic>> rankedFunds = [];

    // 1. Group funds by their clean category (Only Active Management Categories)
    Map<String, List<Map<String, dynamic>>> groupedByCategory = {};
    for (var fund in allFunds) {
      String cat = (fund['short_category'] ?? fund['category'] ?? '').toString().toLowerCase().trim();
      if (cat.isEmpty) continue;
      
      // EXCLUDE Passive, Debt, and Commodities
      if (cat.contains('index') || cat.contains('etf') || cat.contains('exchange traded')) continue;
      
      // INCLUDE Only Equity, Asset Allocation, and Balanced
      bool isEquity = cat.contains('equity');
      bool isAssetAlloc = cat.contains('asset allocation');
      bool isBalanced = cat.contains('balanced');
      
      if (isEquity || isAssetAlloc || isBalanced) {
        // Group them by their exact category to compare apples to apples
        groupedByCategory.putIfAbsent(cat, () => []).add(fund);
      }
    }

    // 2. Process each category in isolation
    groupedByCategory.forEach((categoryName, fundsInCategory) {
      
      // 3. APPLY CORE METRIC FILTER: Must have Return(3Y), TER, and Std Dev
      List<Map<String, dynamic>> validFunds = fundsInCategory.where((f) {
        double? returns = _val(f, 'return_3y'); 
        double? ter = _val(f, 'ter_mtd') ?? _val(f, 'ter_ytd');
        double? sd = _val(f, 'standard_deviation');

        return returns != null && ter != null && sd != null;
      }).toList();

      if (validFunds.isEmpty) return;

      // 4. Calculate Category Averages for Missing Secondary Metrics
      double avgSharpe = _calcAverage(validFunds, 'sharpe_ratio');
      double avgIR = _calcAverage(validFunds, 'info_ratio');
      double avgBeta = _calcAverage(validFunds, 'beta');
      double avgTurnover = _calcAverage(validFunds, 'portfolio_turnover');

      // 5. Find Category Min/Max to establish the scoring curve
      // For Min/Max, we inject the average if the value is missing, so the curve remains stable.
      double maxRet = _findMax(validFunds, 'return_3y', null);
      double minRet = _findMin(validFunds, 'return_3y', null);
      
      double maxTER = _findMax(validFunds, 'ter_mtd', null); 
      double minTER = _findMin(validFunds, 'ter_mtd', null);
      
      double maxSD = _findMax(validFunds, 'standard_deviation', null);
      double minSD = _findMin(validFunds, 'standard_deviation', null);
      
      double maxSharpe = _findMax(validFunds, 'sharpe_ratio', avgSharpe);
      double minSharpe = _findMin(validFunds, 'sharpe_ratio', avgSharpe);
      
      double maxIR = _findMax(validFunds, 'info_ratio', avgIR);
      double minIR = _findMin(validFunds, 'info_ratio', avgIR);
      
      double maxBeta = _findMax(validFunds, 'beta', avgBeta);
      double minBeta = _findMin(validFunds, 'beta', avgBeta);
      
      double maxTurnover = _findMax(validFunds, 'portfolio_turnover', avgTurnover);
      double minTurnover = _findMin(validFunds, 'portfolio_turnover', avgTurnover);

      // 6. Score Each Fund
      for (var f in validFunds) {
        double score = 0.0;
        
        // --- CORE METRICS (Guaranteed to exist) ---
        double retVal = _val(f, 'return_3y')!;
        double terVal = _val(f, 'ter_mtd') ?? _val(f, 'ter_ytd')!;
        double sdVal = _val(f, 'standard_deviation')!;

        // Calculate Core Points
        score += _calcScore(val: retVal, min: minRet, max: maxRet, weight: 3.5, higherIsBetter: true); // 35%
        score += _calcScore(val: sdVal, min: minSD, max: maxSD, weight: 1.0, higherIsBetter: false); // 10%
        score += _calcScore(val: terVal, min: minTER, max: maxTER, weight: 1.0, higherIsBetter: false); // 10%

        // --- SECONDARY METRICS (Use fund value, or fallback to Category Average) ---
        double sharpeVal = _val(f, 'sharpe_ratio') ?? avgSharpe;
        score += _calcScore(val: sharpeVal, min: minSharpe, max: maxSharpe, weight: 2.0, higherIsBetter: true); // 20%

        double irVal = _val(f, 'info_ratio') ?? avgIR;
        score += _calcScore(val: irVal, min: minIR, max: maxIR, weight: 1.5, higherIsBetter: true); // 15%

        double betaVal = _val(f, 'beta') ?? avgBeta;
        score += _calcScore(val: betaVal, min: minBeta, max: maxBeta, weight: 0.5, higherIsBetter: false); // 5%

        double turnVal = _val(f, 'portfolio_turnover') ?? avgTurnover;
        score += _calcScore(val: turnVal, min: minTurnover, max: maxTurnover, weight: 0.5, higherIsBetter: false); // 5%

        // 7. Save the final score back into the map
        Map<String, dynamic> scoredFund = Map.from(f); // Clone it
        scoredFund['bachat_score'] = double.parse(score.toStringAsFixed(2)); // Cap at 2 decimals
        rankedFunds.add(scoredFund);
      }
    });

    // 8. Sort globally by Score (Highest First)
    rankedFunds.sort((a, b) => (b['bachat_score'] as double).compareTo(a['bachat_score'] as double));

    return rankedFunds;
  }

  // ==========================================
  // MATHEMATICAL HELPERS
  // ==========================================

  static double? _val(Map<String, dynamic> fund, String key) {
    if (fund[key] == null || fund[key].toString().trim().isEmpty) return null;
    return double.tryParse(fund[key].toString());
  }

  static double _calcScore({required double val, required double min, required double max, required double weight, required bool higherIsBetter}) {
    if (max == min) return weight; // Prevent division by zero
    
    if (higherIsBetter) {
      return ((val - min) / (max - min)) * weight;
    } else {
      return ((max - val) / (max - min)) * weight;
    }
  }

  /// Calculates the average of a metric across all funds in a category
  static double _calcAverage(List<Map<String, dynamic>> funds, String key) {
    double sum = 0;
    int count = 0;
    for (var f in funds) {
      double? v = _val(f, key);
      if (v != null) {
        sum += v;
        count++;
      }
    }
    return count > 0 ? (sum / count) : 0.0;
  }

  static double _findMax(List<Map<String, dynamic>> funds, String key, double? fallbackAvg) {
    double maxVal = -999999.0;
    for (var f in funds) {
      double v = _val(f, key) ?? fallbackAvg ?? -999999.0;
      if (v > maxVal) maxVal = v;
    }
    return maxVal;
  }

  static double _findMin(List<Map<String, dynamic>> funds, String key, double? fallbackAvg) {
    double minVal = 999999.0;
    for (var f in funds) {
      double v = _val(f, key) ?? fallbackAvg ?? 999999.0;
      if (v < minVal) minVal = v;
    }
    return minVal;
  }
}