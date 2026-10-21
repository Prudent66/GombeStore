import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminComplaintsScreen extends StatelessWidget {
  const AdminComplaintsScreen({super.key});

  Color _statusColor(bool resolved) => resolved ? const Color(0xFF2E7D32) : Colors.orange;

  void _resolveToggle(BuildContext context, QueryDocumentSnapshot doc) async {
    final c = doc.data() as Map<String, dynamic>;
    final wasResolved = c['isResolved'] ?? false;
    await doc.reference.update({'isResolved': !wasResolved});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!wasResolved ? 'Complaint marked as resolved' : 'Complaint reopened'),
          backgroundColor: !wasResolved ? const Color(0xFF2E7D32) : Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints & Refunds'),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('complaints').snapshots(),
            builder: (c, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final open = snapshot.data!.docs.where((d) {
                final c = d.data() as Map<String, dynamic>?;
                return !(c?['isResolved'] as bool? ?? true);
              }).length;
              if (open > 0) {
                return Container(
                  margin: const EdgeInsets.only(right: 8, top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                  child: Text('$open', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('complaints')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No complaints yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final c = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              final resolved = c['isResolved'] ?? false;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: _statusColor(resolved).withOpacity(0.15),
                    child: Icon(Icons.report_problem, color: _statusColor(resolved), size: 22),
                  ),
                  title: Text(c['subject'] ?? 'No subject',
                      style: TextStyle(fontWeight: FontWeight.bold, decoration: resolved ? TextDecoration.lineThrough : null)),
                  subtitle: Text('Reported by ${c['userName'] ?? 'Unknown'} • ${c['category'] ?? 'Other'}'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Description:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(c['message'] ?? ''),
                          if (c['orderId'] != null) ...[
                            const Divider(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.receipt_long, size: 16, color: Color(0xFF2E7D32)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Order ID: ${c['orderId']}',
                                    style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF2E7D32)),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await FirebaseFirestore.instance.collection('complaints').doc(snapshot.data!.docs[index].id).update({'orderId': null});
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order ID removed')));
                                    }
                                  },
                                  child: const Text('Detach', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          ],
                          const Divider(height: 16),
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: () => _resolveToggle(context, snapshot.data!.docs[index]),
                              icon: Icon(resolved ? Icons.reply : Icons.check_circle_outline),
                              label: Text(resolved ? 'Reopen' : 'Mark Resolved'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: resolved ? Colors.orange : const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
