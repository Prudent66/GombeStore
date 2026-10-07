import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminApprovalsScreen extends StatelessWidget {
  const AdminApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vendor Approvals')),
      body: StreamBuilder<QuerySnapshot>(
        // Fetch users where role == vendor and isVerified == false
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'vendor')
            .where('isVerified', isEqualTo: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final vendors = snapshot.data!.docs;

          if (vendors.isEmpty) {
            return const Center(child: Text('No pending vendor approvals. 🎉'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vendors.length,
            itemBuilder: (context, index) {
              final vendor = vendors[index].data() as Map<String, dynamic>;
              final vendorId = vendors[index].id;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vendor['storeName'] ?? 'Unknown Store',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text('Owner: ${vendor['fullName'] ?? 'N/A'}'),
                      Text('Phone: ${vendor['phone'] ?? 'N/A'}'),
                      Text('Email: ${vendor['email'] ?? 'N/A'}'),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Reject Button
                          OutlinedButton(
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('users').doc(vendorId).update({
                                'isVerified': false,
                                'status': 'rejected',
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Vendor Rejected'), backgroundColor: Colors.red),
                                );
                              }
                            },
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 10),
                          // Approve Button
                          ElevatedButton(
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('users').doc(vendorId).update({
                                'isVerified': true,
                                'status': 'approved',
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Vendor Approved!'), backgroundColor: Color(0xFF2E7D32)),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                            child: const Text('Approve'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}