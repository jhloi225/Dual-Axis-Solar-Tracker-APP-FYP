import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart'; // Requires intl package

// --- FIREBASE REFERENCES ---
const String deviceId = "PROTOTYPE-1";
final DatabaseReference logsRef = FirebaseDatabase.instance.ref('devices/$deviceId/logs');

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder(
        // Order by timestamp (assuming logs are written with a 'timestamp' field)
        stream: logsRef.orderByChild('timestamp').onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No recent system alerts.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              )
            );
          }

          // --- Data Grouping Logic ---
          final Map? data = snapshot.data!.snapshot.value as Map?;
          if (data == null) return const Center(child: Text('No data found.'));

          final List<LogEntry> allLogs = data.entries
              .map((e) => LogEntry.fromMap(e.value as Map))
              .toList()
              .reversed.toList(); // Assuming Firebase returns oldest first, reverse to show newest first

          final Map<String, List<LogEntry>> groupedLogs = {};

          for (var log in allLogs) {
            final String groupKey = _getLogGroupKey(log.timestamp);
            if (!groupedLogs.containsKey(groupKey)) {
              groupedLogs[groupKey] = [];
            }
            groupedLogs[groupKey]!.add(log);
          }

          final List<String> sortedGroupKeys = groupedLogs.keys.toList();

          // --- UI List View ---
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: sortedGroupKeys.length,
            itemBuilder: (context, index) {
              final String groupKey = sortedGroupKeys[index];
              final List<LogEntry> logsInGroup = groupedLogs[groupKey]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                    child: Text(groupKey, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  ...logsInGroup.map((log) => NotificationCard(log: log)).toList(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// Determines the grouping key (Today, Yesterday, Date)
String _getLogGroupKey(DateTime timestamp) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(timestamp.year, timestamp.month, timestamp.day);

  if (date.isAtSameMomentAs(today)) {
    return 'Today';
  } else if (date.isAtSameMomentAs(today.subtract(const Duration(days: 1)))) {
    return 'Yesterday';
  } else {
    return DateFormat('EEEE, d MMM').format(timestamp);
  }
}

// --- Data Model for a Log Entry ---
class LogEntry {
  final DateTime timestamp;
  final String type;
  final String message;
  final String details;

  LogEntry({required this.timestamp, required this.type, required this.message, required this.details});

  factory LogEntry.fromMap(Map map) {
    return LogEntry(
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      type: map['type'] ?? 'info',
      message: map['message'] ?? 'System Alert',
      details: map['details'] ?? '',
    );
  }
}

// --- Custom Widget for a Notification Card ---
class NotificationCard extends StatelessWidget {
  final LogEntry log;

  const NotificationCard({super.key, required this.log});

  IconData _getIcon(String type) {
    switch (type) {
      case 'storm': return Icons.thunderstorm;
      case 'cleaning': return Icons.cleaning_services;
      case 'error': return Icons.warning_amber;
      default: return Icons.info_outline;
    }
  }

  Color _getIconColor(BuildContext context, String type) {
    switch (type) {
      case 'storm': return Colors.blue;
      case 'cleaning': return Colors.orange;
      case 'error': return Colors.red;
      default: return Theme.of(context).primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color iconColor = _getIconColor(context, log.type);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(_getIcon(log.type), color: iconColor),
        ),
        title: Text(log.message, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(log.details.isEmpty ? 'System Event' : log.details),
        trailing: Text(
          DateFormat('h:mm a').format(log.timestamp),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        onTap: () {
          // Optional: Show more details on tap
        },
      ),
    );
  }
}
