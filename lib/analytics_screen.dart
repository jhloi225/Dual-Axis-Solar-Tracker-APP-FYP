import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 6));
  DateTime _endDate = DateTime.now();
  Map<String, double> _analyticsData = {};
  bool _isLoading = true;
  String _selectedUnit = 'Wh';
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _checkDeviceAndFetchData();
  }

  Future<void> _checkDeviceAndFetchData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final deviceId = await _getDeviceId(user.uid);
    if (mounted) {
      setState(() {
        _deviceId = deviceId;
      });
    }

    if (deviceId != null) {
      await _fetchAnalyticsData(deviceId);
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAnalyticsData(String deviceId) async {
    if (mounted) setState(() => _isLoading = true);
    final data = await _getHistoricalData(deviceId, _startDate, _endDate);
    if (mounted) {
      setState(() {
        _analyticsData = data;
        _isLoading = false;
      });
    }
  }

  Future<String?> _getDeviceId(String uid) async {
    final snapshot = await FirebaseDatabase.instance.ref('users/$uid/owned_devices').get();
    if (snapshot.exists && snapshot.value != null) {
      return (snapshot.value as Map).keys.first;
    }
    return null;
  }

  Future<Map<String, double>> _getHistoricalData(String deviceId, DateTime start, DateTime end) async {
    final ref = FirebaseDatabase.instance.ref('historical_data/$deviceId');
    final Map<String, double> data = {};

    for (int i = 0; i <= end.difference(start).inDays; i++) {
      final day = start.add(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(day);
      final snapshot = await ref.child(dateKey).get();
      if (snapshot.exists && snapshot.value != null) {
        data[dateKey] = double.tryParse(snapshot.value.toString()) ?? 0.0;
      } else {
        data[dateKey] = 0.0;
      }
    }
    return data;
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Energy Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, size: 28),
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, size: 28),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_deviceId == null) {
      return _buildNoDeviceUI();
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: <Widget>[
        _buildDateRangePicker(),
        const SizedBox(height: 20),
        _buildChart(),
        const SizedBox(height: 20),
        _buildSummaryMetrics(),
      ],
    );
  }

  Widget _buildNoDeviceUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link_off_rounded, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text('No Analytics Data', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'Pair a device to begin tracking your energy generation history.', 
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/pair_device'),
              icon: const Icon(Icons.add),
              label: const Text('Pair Now'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _DateButton(label: 'Start', date: _startDate, onTap: () => _selectDate(context, true)),
                const Icon(Icons.arrow_forward_rounded, color: Colors.grey),
                _DateButton(label: 'End', date: _endDate, onTap: () => _selectDate(context, false)),
                IconButton(
                  icon: const Icon(Icons.search), 
                  onPressed: () => _fetchAnalyticsData(_deviceId!), 
                  color: Theme.of(context).primaryColor, 
                  tooltip: 'Load Data'
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Wh', label: Text('Wh')),
                ButtonSegment(value: 'kWh', label: Text('kWh')),
              ],
              selected: {_selectedUnit},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _selectedUnit = newSelection.first;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final List<FlSpot> spots = [];
    final List<String> dateLabels = [];
    double maxVal = 50;
    final bool isWh = _selectedUnit == 'Wh';

    if (_analyticsData.isNotEmpty) {
      final sortedKeys = _analyticsData.keys.toList()..sort();
      for (int i = 0; i < sortedKeys.length; i++) {
        final key = sortedKeys[i];
        double value = _analyticsData[key]!;
        value = isWh ? value : value / 1000;
        spots.add(FlSpot(i.toDouble(), value));
        dateLabels.add(key);
        if (value > maxVal) maxVal = value;
      }
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          children: [
            Text('Production ($_selectedUnit)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: spots.isEmpty
                  ? const Center(child: Text("No data for this period."))
                  : ProductionLineChart(
                      data: spots,
                      dates: dateLabels,
                      unit: _selectedUnit,
                      maxX: (spots.length - 1).toDouble(),
                      maxY: maxVal,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetrics() {
    double totalWh = 0;
    if (_analyticsData.isNotEmpty) {
      totalWh = _analyticsData.values.reduce((a, b) => a + b);
    }
    final bool isWh = _selectedUnit == 'Wh';

    final double displayTotal = isWh ? totalWh : totalWh / 1000;
    final double peak = (_analyticsData.isEmpty ? 0 : _analyticsData.values.reduce((a, b) => a > b ? a : b));
    final double displayPeak = isWh ? peak : peak / 1000;
    final double avg = (_analyticsData.isEmpty ? 0 : totalWh / _analyticsData.length);
    final double displayAvg = isWh ? avg : avg / 1000;
    final double co2Saved = (totalWh / 1000) * 0.43;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        MetricCard(label: 'Total Generated', value: '${displayTotal.toStringAsFixed(2)} $_selectedUnit'),
        MetricCard(label: 'Peak Production', value: '${displayPeak.toStringAsFixed(2)} $_selectedUnit'),
        MetricCard(label: 'Daily Average', value: '${displayAvg.toStringAsFixed(2)} $_selectedUnit'),
        MetricCard(label: 'CO₂ Saved', value: '${co2Saved.toStringAsFixed(2)} kg', color: Colors.blueAccent),
      ],
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateButton({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 4),
          Text(DateFormat.yMMMd().format(date), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color)),
        ],
      ),
    );
  }
}

class ProductionLineChart extends StatelessWidget {
  final List<FlSpot> data;
  final List<String> dates;
  final String unit;
  final double maxX, maxY;

  const ProductionLineChart({super.key, required this.data, required this.dates, required this.unit, required this.maxX, required this.maxY});

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: maxX,
        minY: 0,
        maxY: maxY * 1.2,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Theme.of(context).primaryColor,
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                final date = dates[spot.x.toInt()];
                final value = spot.y.toStringAsFixed(2);
                return LineTooltipItem(
                  '$date\n$value $unit',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: data,
            isCurved: true,
            color: Theme.of(context).primaryColor,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: Theme.of(context).primaryColor.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const MetricCard({super.key, required this.label, required this.value, this.color = Colors.black87});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
