import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class ReportsPage extends StatefulWidget {
  final VoidCallback? onGoHome;
  const ReportsPage({super.key, this.onGoHome});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int _selectedPeriodIndex = 0; // 0 = Week, 1 = Month, 2 = 3 Months
  List<Map<String, dynamic>> _adherenceLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      _adherenceLogs = await SupabaseService.getAdherenceLogs();
    } catch (e) {
      debugPrint('Error loading reports: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  DateTime _dateOnly(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  int _getDosesTaken(DateTime start, DateTime end) {
    final startOnly = _dateOnly(start);
    final endOnly = _dateOnly(end);
    return _adherenceLogs.where((l) {
      final date = DateTime.tryParse(l['date']);
      if (date == null) return false;
      final dateOnly = _dateOnly(date);
      return !dateOnly.isBefore(startOnly) && !dateOnly.isAfter(endOnly) && l['taken'] == true;
    }).length;
  }

  int _getMissed(DateTime start, DateTime end) {
    final startOnly = _dateOnly(start);
    final endOnly = _dateOnly(end);
    return _adherenceLogs.where((l) {
      final date = DateTime.tryParse(l['date']);
      if (date == null) return false;
      final dateOnly = _dateOnly(date);
      return !dateOnly.isBefore(startOnly) && !dateOnly.isAfter(endOnly) && l['taken'] == false;
    }).length;
  }

  int _getAdherenceRate(DateTime start, DateTime end) {
    final taken = _getDosesTaken(start, end);
    final missed = _getMissed(start, end);
    final total = taken + missed;
    if (total == 0) return 0;
    return ((taken / total) * 100).round();
  }

  int get _dayStreak {
    if (_adherenceLogs.isEmpty) return 0;
    
    final takenDates = _adherenceLogs
        .where((log) => log['taken'] == true)
        .map((log) => log['date'] as String)
        .toSet()
        .toList();
        
    if (takenDates.isEmpty) return 0;
    
    takenDates.sort((a, b) => b.compareTo(a));
    
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";
    
    if (!takenDates.contains(todayStr) && !takenDates.contains(yesterdayStr)) {
      return 0;
    }
    
    int streak = 0;
    DateTime checkDate = takenDates.contains(todayStr) ? now : yesterday;
    
    while (true) {
      final checkDateStr = "${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}";
      if (takenDates.contains(checkDateStr)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    
    return streak;
  }

  ReportData get _weeklyReport {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    final daysOfWeek = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final chartData = List.generate(7, (index) {
      final date = startOfWeek.add(Duration(days: index));
      final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final dayLogs = _adherenceLogs.where((l) => l['date'] == dateStr);
      if (dayLogs.isEmpty) {
        return ChartBarData(label: daysOfWeek[index], value: 0.0, color: const Color(0xFF2B72D0));
      }
      final taken = dayLogs.where((l) => l['taken'] == true).length;
      final rate = taken / dayLogs.length;
      return ChartBarData(
        label: daysOfWeek[index],
        value: rate,
        color: rate == 1.0 ? const Color(0xFF3EC8A8) : const Color(0xFF2B72D0),
      );
    });

    final score = _getAdherenceRate(startOfWeek, endOfWeek);

    return ReportData(
      periodName: 'Week',
      scoreText: 'Weekly Adherence',
      score: score,
      trendText: score == 0 
          ? 'Log your doses on Home tab to start tracking weekly compliance'
          : 'Weekly Adherence is currently at $score%',
      chartData: chartData,
      dosesTaken: _getDosesTaken(startOfWeek, endOfWeek),
      missed: _getMissed(startOfWeek, endOfWeek),
      streak: _dayStreak,
    );
  }

  ReportData get _monthlyReport {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    final List<ChartBarData> chartData = [];
    for (int i = 0; i < 4; i++) {
      final startDay = 1 + i * 7;
      final endDay = i == 3 ? endOfMonth.day : (i + 1) * 7;
      final start = DateTime(now.year, now.month, startDay);
      final end = DateTime(now.year, now.month, endDay);
      final score = _getAdherenceRate(start, end) / 100.0;
      chartData.add(ChartBarData(
        label: 'W${i + 1}',
        value: score,
        color: score == 1.0 ? const Color(0xFF3EC8A8) : const Color(0xFF2B72D0),
      ));
    }

    final score = _getAdherenceRate(startOfMonth, endOfMonth);

    return ReportData(
      periodName: 'Month',
      scoreText: 'Monthly Adherence',
      score: score,
      trendText: score == 0
          ? 'Log your doses on Home tab to start tracking monthly compliance'
          : 'Monthly Adherence is currently at $score%',
      chartData: chartData,
      dosesTaken: _getDosesTaken(startOfMonth, endOfMonth),
      missed: _getMissed(startOfMonth, endOfMonth),
      streak: _dayStreak,
    );
  }

  ReportData get _threeMonthReport {
    final now = DateTime.now();
    
    final List<ChartBarData> chartData = [];
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    for (int i = 2; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final start = DateTime(monthDate.year, monthDate.month, 1);
      final end = DateTime(monthDate.year, monthDate.month + 1, 0);
      final score = _getAdherenceRate(start, end) / 100.0;
      
      chartData.add(ChartBarData(
        label: monthNames[monthDate.month - 1],
        value: score,
        color: score == 1.0 ? const Color(0xFF3EC8A8) : const Color(0xFF2B72D0),
      ));
    }

    final start = DateTime(now.year, now.month - 2, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    final score = _getAdherenceRate(start, end);

    return ReportData(
      periodName: '3 Months',
      scoreText: 'Quarterly Adherence',
      score: score,
      trendText: score == 0
          ? 'Log your doses on Home tab to start tracking quarterly compliance'
          : 'Quarterly Adherence is currently at $score%',
      chartData: chartData,
      dosesTaken: _getDosesTaken(start, end),
      missed: _getMissed(start, end),
      streak: _dayStreak,
    );
  }

  List<ReportData> get _reports => [
    _weeklyReport,
    _monthlyReport,
    _threeMonthReport,
  ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F9FD),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2B72D0)),
          ),
        ),
      );
    }

    final activeData = _reports[_selectedPeriodIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FD),
      body: SafeArea(
        child: _adherenceLogs.isEmpty
            ? _buildEmptyState()
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    _buildSegmentedControl(),
                    _buildAdherenceCard(activeData),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: CustomBarChart(
                        barData: activeData.chartData,
                        title: activeData.scoreText,
                      ),
                    ),
                    _buildStatsRow(activeData),
                    const SizedBox(height: 100), // Safety spacing
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Reports',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F2B48),
              letterSpacing: -0.5,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.share_rounded,
              color: Color(0xFF2B72D0),
              size: 26,
            ),
            onPressed: () => _showExportBottomSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8F2FF), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildSegmentItem(0, 'Week'),
          _buildSegmentItem(1, 'Month'),
          _buildSegmentItem(2, '3 Months'),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(int index, String label) {
    final isSelected = _selectedPeriodIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriodIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2B72D0) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF8A9AAD),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdherenceCard(ReportData activeData) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF1E6FB3), // Royal Blue
            Color(0xFF2FD5AA), // Teal/Green
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x331E6FB3),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adherence Score',
                  style: TextStyle(
                    color: Colors.white.withAlpha(179),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${activeData.score}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  activeData.trendText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ProgressCircle(
            value: activeData.score / 100.0,
            score: activeData.score,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(ReportData activeData) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _buildStatCard(
            value: '${activeData.dosesTaken}',
            label: 'Doses Taken',
            color: const Color(0xFF3EC8A8), // Green
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            value: '${activeData.missed}',
            label: 'Missed',
            color: const Color(0xFFE57373), // Red
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            value: '${activeData.streak}',
            label: 'Day Streak',
            color: const Color(0xFFFB9A40), // Orange/Amber
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x04000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8A9AAD),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExportBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Export Health Report',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F2B48),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF8A9AAD)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildExportOption(
                  icon: Icons.picture_as_pdf_rounded,
                  title: 'Export as PDF',
                  subtitle: 'Ideal for printing or emailing to doctors',
                  color: Colors.redAccent,
                  onTap: () => _simulateExport('PDF'),
                ),
                const Divider(height: 24, thickness: 1, color: Color(0xFFE2E8F0)),
                _buildExportOption(
                  icon: Icons.table_chart_rounded,
                  title: 'Export as CSV (Excel)',
                  subtitle: 'Raw tabular data for personal tracking',
                  color: Colors.green,
                  onTap: () => _simulateExport('CSV'),
                ),
                const Divider(height: 24, thickness: 1, color: Color(0xFFE2E8F0)),
                _buildExportOption(
                  icon: Icons.send_rounded,
                  title: 'Share directly with Doctor',
                  subtitle: 'Send report via secure physician sync',
                  color: const Color(0xFF2B72D0),
                  onTap: () => _simulateExport('Physician Sync'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F2B48),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8A9AAD),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF8A9AAD)),
          ],
        ),
      ),
    );
  }

  void _simulateExport(String type) {
    Navigator.of(context).pop(); // Close bottom sheet
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 24),
              Text(
                'Generating report...',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );

    // Simulate delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text('Report successfully exported via $type!'),
              ],
            ),
            backgroundColor: const Color(0xFF3EC8A8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF2B72D0).withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B72D0).withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.insert_chart_outlined_rounded,
                  color: Color(0xFF2B72D0),
                  size: 64,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'No Compliance Data Yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F2B48),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your compliance reports, weekly/monthly graphs, and adherence scores will populate here once you start logging your doses or responding to daily reminders.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8A9AAD),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (widget.onGoHome != null) ...[
              const SizedBox(height: 36),
              SizedBox(
                width: 200,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: widget.onGoHome,
                  icon: const Icon(Icons.home_rounded, color: Colors.white),
                  label: const Text(
                    'Go to Home',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B72D0),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ProgressCircle extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final int score;

  const ProgressCircle({
    super.key,
    required this.value,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      height: 78,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background thin circle
          SizedBox(
            width: 70,
            height: 70,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withAlpha(38),
              ),
            ),
          ),
          // Foreground progress circle
          SizedBox(
            width: 70,
            height: 70,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 5,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              strokeCap: StrokeCap.round,
            ),
          ),
          // Centered text
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              Text(
                '/100',
                style: TextStyle(
                  color: Colors.white.withAlpha(153),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CustomBarChart extends StatelessWidget {
  final List<ChartBarData> barData;
  final String title;

  const CustomBarChart({
    super.key,
    required this.barData,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F2B48),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: barData.map((data) => _buildBar(data)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(ChartBarData data) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              width: 28,
              height: (data.value * 120).clamp(6.0, 120.0),
              decoration: BoxDecoration(
                color: data.color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          data.label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8A9AAD),
          ),
        ),
      ],
    );
  }
}

class ReportData {
  final String periodName;
  final String scoreText;
  final int score;
  final String trendText;
  final List<ChartBarData> chartData;
  final int dosesTaken;
  final int missed;
  final int streak;

  ReportData({
    required this.periodName,
    required this.scoreText,
    required this.score,
    required this.trendText,
    required this.chartData,
    required this.dosesTaken,
    required this.missed,
    required this.streak,
  });
}

class ChartBarData {
  final String label;
  final double value; // 0.0 to 1.0 representing percentage
  final Color color;

  ChartBarData({
    required this.label,
    required this.value,
    required this.color,
  });
}
