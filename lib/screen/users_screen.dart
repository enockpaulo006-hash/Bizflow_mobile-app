
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final CollectionReference users =
      FirebaseFirestore.instance.collection('users');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users Management'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: users.orderBy('created_at', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load users. Check Firebase permissions.'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final documents = snapshot.data?.docs ?? [];

          if (documents.isEmpty) {
            return const Center(
              child: Text(
                'No user profiles found yet.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final document = documents[index];
              final data = document.data() as Map<String, dynamic>;

              final name =
                  data['full_name'] ?? data['email'] ?? 'Unnamed user';
              final role = data['role'] ?? 'WORKER';
              final isActive = data['is_active'] ?? true;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      role == 'ADMIN'
                          ? Icons.admin_panel_settings
                          : Icons.person,
                    ),
                  ),
                  title: Text(name.toString()),
                  subtitle: Text(
                    'Role: $role\nStatus: ${isActive ? 'Active' : 'Inactive'}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.info_outline),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
