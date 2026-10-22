import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Visual step tracker for an order: Pending -> Confirmed ->
/// Out for Delivery -> Delivered. Reads the timestamped trail written
/// by [OrderService] (the `statusHistory` array on the order document)
/// and falls back gracefully for older orders without one.
class OrderTimeline extends StatelessWidget {
  final Map<String, dynamic> order;

  const OrderTimeline({super.key, required this.order});

  static const List<String> _steps = [
    'Pending',
    'Confirmed',
    'Out for Delivery',
    'Delivered',
  ];

  static const List<IconData> _stepIcons = [
    Icons.hourglass_top,
    Icons.check_circle_outline,
    Icons.local_shipping,
    Icons.task_alt,
  ];

  String get _status => order['status'] ?? 'Pending';

  /// Index of the current step; -1 when cancelled (nothing in progress).
  int get _currentIndex => _steps.indexOf(_status);

  /// Returns the timestamp recorded when this status was reached, if any.
  Timestamp? _timeFor(String step) {
    final history = order['statusHistory'] as List<dynamic>? ?? [];
    for (final entry in history) {
      final map = entry as Map<dynamic, dynamic>;
      if (map['status'] == step && map['at'] is Timestamp) {
        return map['at'] as Timestamp;
      }
    }
    // Orders that never had a history trail still show their creation time.
    if (step == 'Pending') {
      final createdAt = order['createdAt'];
      if (createdAt is Timestamp) return createdAt;
    }
    return null;
  }

  String _timeText(String step) {
    final ts = _timeFor(step);
    if (ts == null) {
      return _steps.indexOf(step) <= _currentIndex ? '' : 'Not yet';
    }
    return DateFormat.yMMMd().add_jm().format(ts.toDate());
  }

  Color _stepColor(int index) {
    if (_status == 'Cancelled') {
      // While cancelled, only the Pending step was "reached".
      return index == 0 ? Colors.red : Colors.grey.shade300;
    }
    if (index < _currentIndex) {
      return const Color(0xFF2E7D32); // completed
    }
    if (index == _currentIndex) {
      return _stepPillColor(_status); // in progress
    }
    return Colors.grey.shade300; // upcoming
  }

  Color _stepPillColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Confirmed':
        return Colors.blue;
      case 'Out for Delivery':
        return Colors.purple;
      case 'Delivered':
        return const Color(0xFF2E7D32);
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStep(int index) {
    final isCurrent = index == _currentIndex;
    final color = _stepColor(index);
    final timeText = _timeText(_steps[index]);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vertical connector + step icon
          SizedBox(
            width: 36,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(_stepIcons[index], size: 14, color: color),
                ),
                if (index < _steps.length - 1)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: (index < _currentIndex) ? color : Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Label + timestamp
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _steps[index],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isCurrent || index < _currentIndex
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: color == Colors.grey.shade300 ? Colors.grey : color,
                        ),
                      ),
                      if (isCurrent && _status != 'Cancelled') ...[
                        const SizedBox(width: 6),
                        Text(
                          'Current',
                          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                  if (timeText.isNotEmpty)
                    Text(timeText, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._steps.map((s) => _buildStep(_steps.indexOf(s))),
        if (_status == 'Cancelled')
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Icon(Icons.cancel, size: 16, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Order cancelled on ${_timeTextForCancelled()}',
                  style: const TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _timeTextForCancelled() {
    final ts = _timeFor('Cancelled');
    if (ts == null) return 'unknown date';
    return DateFormat.yMMMd().add_jm().format(ts.toDate());
  }
}
