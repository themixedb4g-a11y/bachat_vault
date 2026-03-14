import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'dart:math' as math; 

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

  // ADDED: The Name Shortener
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
        .replaceAll('Faysal Khushal Mustaqbil Fund (Faysal Nu�umah Women Savers Plan)', 'Faysal Nuumah Women Savers Plan')
        .replaceAll('Faysal Islamic Financial Planning Fund II (Faysal Priority Ascend Plan I)', 'Faysal Priority Ascend Plan I')
        .replaceAll('Faysal Islamic Financial Planning Fund II (Faysal Priority Ascend Plan II)', 'Faysal Priority Ascend Plan II')
        .replaceAll('Faysal Islamic Financial Planning Fund II (Faysal Priority Ascend Plan III)', 'Faysal Priority Ascend Plan III')
        .replaceAll('Faysal Khushal Mustaqbil Fund (Faysal Barak�ah Women Savers Plan)', 'Faysal Barakaah Women Savers Plan')
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
        .replaceAll('Meezan Financial Planning Fund of Funds (MAAP I)', 'Meezan FP Fund of Funds (Conservative)')
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
    // APPLIED: The Name Shortener
    final fundName = _cleanFundName(fund['fund_name'] ?? 'Unknown Fund');
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
                        _buildReturnRow('15 Years', 'return_15y', 5475, years: 15, isShariah: isShariah),
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