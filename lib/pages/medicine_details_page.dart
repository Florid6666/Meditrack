import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class MedicineDetailsPage extends StatefulWidget {
  final Map<String, dynamic> medication;
  final List<Map<String, dynamic>> adherenceLogs;

  const MedicineDetailsPage({
    super.key,
    required this.medication,
    required this.adherenceLogs,
  });

  @override
  State<MedicineDetailsPage> createState() => _MedicineDetailsPageState();
}

class _MedicineDetailsPageState extends State<MedicineDetailsPage> {
  late int _stockRemaining;
  late int _totalStock;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _stockRemaining = widget.medication['stock_count'] ?? 0;
    _totalStock = widget.medication['stock_count'] ?? 30;
    if (_totalStock < 30) {
      _totalStock = 30; // standard baseline scale for visual progress indicator
    }
  }

  @override
  Widget build(BuildContext context) {
    final fillRatio = _totalStock > 0 ? (_stockRemaining / _totalStock).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FD),
      body: Column(
        children: [
          // Blue Header Banner
          _buildHeaderBanner(context),
          // Scrollable details content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Cards Row
                  _buildInfoCardsRow(),
                  const SizedBox(height: 24),

                  // Stock Level card
                  _buildStockLevelCard(fillRatio),
                  const SizedBox(height: 20),

                  // Order Refill Button
                  _buildOrderRefillButton(),
                  const SizedBox(height: 32),

                  // Recent History
                  _buildRecentHistorySection(),
                  const SizedBox(height: 32),

                  // Delete Medication Option
                  _buildDeleteButton(),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context) {
    final name = widget.medication['name'] ?? 'Unknown Medication';
    final type = widget.medication['type'] ?? 'Tablet';
    final dosage = widget.medication['dosage']?.toString() ?? '0';
    final unit = widget.medication['unit'] ?? 'mg';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF2B72D0),
      ),
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                // Pill Icon in rounded square
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0x2EFFFFFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.medication_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // Text details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$type · $dosage$unit${widget.medication['meal_instruction'] != null ? ' · ${widget.medication['meal_instruction']}' : ''}',
                        style: const TextStyle(
                          color: Color(0xD9FFFFFF),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCardsRow() {
    final reminderTime = widget.medication['reminder_time'] ?? '8:00 AM';
    final dosage = widget.medication['dosage']?.toString() ?? '0';
    final unit = widget.medication['unit'] ?? 'mg';

    return Row(
      children: [
        // Dose Time Card
        Expanded(
          child: _buildInfoCard(
            title: reminderTime,
            subtitle: 'Dose Time',
            icon: Icons.access_time_rounded,
            iconColor: const Color(0xFF2B72D0),
            textColor: const Color(0xFF0F2B48),
          ),
        ),
        const SizedBox(width: 14),
        // Dosage Card
        Expanded(
          child: _buildInfoCard(
            title: '$dosage $unit',
            subtitle: 'Dosage',
            icon: Icons.layers_rounded,
            iconColor: const Color(0xFF3EC8A8),
            textColor: const Color(0xFF0F2B48),
          ),
        ),
        const SizedBox(width: 14),
        // Stock Card
        Expanded(
          child: _buildInfoCard(
            title: '$_stockRemaining Left',
            subtitle: 'Stock',
            icon: Icons.inventory_2_outlined,
            iconColor: const Color(0xFFFB9A40),
            textColor: const Color(0xFFFB9A40),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF8A9AAD),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockLevelCard(double fillRatio) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stock Level',
            style: TextStyle(
              color: Color(0xFF0F2B48),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Custom progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 12,
                  color: const Color(0xFFF1F5F9),
                ),
                FractionallySizedBox(
                  widthFactor: fillRatio,
                  child: Container(
                    height: 12,
                    color: const Color(0xFFFB9A40),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_stockRemaining of $_totalStock pills remaining',
                style: const TextStyle(
                  color: Color(0xFF8A9AAD),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_stockRemaining <= 10)
                const Text(
                  'Refill soon',
                  style: TextStyle(
                    color: Color(0xFFFB9A40),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderRefillButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () async {
          try {
            await SupabaseService.updateMedicationStock(widget.medication['id'], 30);
            setState(() {
              _stockRemaining = 30;
              _totalStock = 30;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Refill ordered successfully! Stock updated.')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update stock: $e')),
              );
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFB9A40),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'Order Refill',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentHistorySection() {
    final logs = widget.adherenceLogs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F2B48),
          ),
        ),
        const SizedBox(height: 16),
        if (logs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: const Column(
              children: [
                Icon(Icons.history_rounded, color: Color(0xFF8A9AAD), size: 36),
                SizedBox(height: 12),
                Text(
                  'No History Yet',
                  style: TextStyle(
                    color: Color(0xFF0F2B48),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Intake history logged from reminders will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF8A9AAD),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: logs.length > 5 ? 5 : logs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final log = logs[index];
              final dateStr = log['date'] ?? '';
              final taken = log['taken'] ?? false;
              
              String displayDate = dateStr;
              try {
                final date = DateTime.tryParse(dateStr);
                if (date != null) {
                  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                  displayDate = "${months[date.month - 1]} ${date.day}, ${date.year}";
                }
              } catch (_) {}

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x04000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: taken ? const Color(0xFFE6F9F5) : const Color(0xFFFFECEB),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        taken ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: taken ? const Color(0xFF3EC8A8) : const Color(0xFFE57373),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            taken ? 'Dose Taken' : 'Dose Missed',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F2B48),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayDate,
                            style: const TextStyle(
                              color: Color(0xFF8A9AAD),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildDeleteButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _isDeleting ? null : _confirmDelete,
        icon: _isDeleting 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE57373)),
              )
            : const Icon(Icons.delete_forever_rounded, color: Color(0xFFE57373), size: 24),
        label: Text(
          _isDeleting ? 'Deleting...' : 'Delete Medication',
          style: const TextStyle(
            color: Color(0xFFE57373),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE57373), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Medication?'),
          content: Text('Are you sure you want to permanently delete "${widget.medication['name']}"? This will also remove all its compliance logs.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() {
                  _isDeleting = true;
                });
                try {
                  await SupabaseService.deleteMedication(widget.medication['id']);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Medication deleted successfully')),
                    );
                    Navigator.of(context).pop(true);
                  }
                } catch (e) {
                  setState(() {
                    _isDeleting = false;
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete medication: $e')),
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }
}
