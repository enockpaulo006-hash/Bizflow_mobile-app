
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final CollectionReference<Map<String, dynamic>> _expenses =
      FirebaseFirestore.instance.collection('expenses');

  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  String _money(num amount) {
    return 'TSh ${amount.toStringAsFixed(2)}';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showExpenseForm() async {
    final formKey = GlobalKey<FormState>();

    final categoryController = TextEditingController();
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();

    DateTime expenseDate = DateTime.now();

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: const Text('Record expense'),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: categoryController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Expense category *',
                              hintText:
                                  'e.g. Transport, Rent, Electricity',
                              prefixIcon: Icon(Icons.category_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter an expense category';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: descriptionController,
                            textCapitalization:
                                TextCapitalization.sentences,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              hintText: 'What was the money spent on?',
                              prefixIcon: Icon(Icons.notes),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: amountController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Amount (TSh) *',
                              prefixIcon: Icon(Icons.payments_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final amount =
                                  double.tryParse(value?.trim() ?? '');

                              if (amount == null ||
                                  !amount.isFinite ||
                                  amount <= 0) {
                                return 'Enter an amount greater than 0';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final chosenDate = await showDatePicker(
                                  context: dialogContext,
                                  initialDate: expenseDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 3650),
                                  ),
                                );

                                if (chosenDate != null) {
                                  setDialogState(() {
                                    expenseDate = chosenDate;
                                  });
                                }
                              },
                              icon: const Icon(Icons.calendar_today),
                              label: Text(
                                'Expense date: ${_formatDate(expenseDate)}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;

                      final amount =
                          double.parse(amountController.text.trim());

                      final user = FirebaseAuth.instance.currentUser;

                      try {
                        await _expenses.add({
                          'category': categoryController.text.trim(),
                          'description':
                              descriptionController.text.trim(),
                          'amount': amount,
                          'expense_date':
                              Timestamp.fromDate(expenseDate),
                          'user_id': user?.uid,
                          'entered_by': user?.email ?? 'Unknown user',
                          'created_at': FieldValue.serverTimestamp(),
                        });

                        if (!dialogContext.mounted) return;

                        Navigator.pop(dialogContext);

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Expense recorded successfully.',
                              ),
                            ),
                          );
                        }
                      } on FirebaseException catch (error) {
                        if (!dialogContext.mounted) return;

                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              error.message ?? 'Could not save the expense.',
                            ),
                          ),
                        );
                      } catch (_) {
                        if (!dialogContext.mounted) return;

                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not save expense. Please try again.',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Save expense'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      categoryController.dispose();
      descriptionController.dispose();
      amountController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF147D55);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Expenses',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showExpenseForm,
        backgroundColor: green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Record expense'),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _expenses.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Could not load expenses. Check your connection '
                    'and Firestore security rules.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final records = snapshot.data?.docs.toList() ?? [];

            records.sort((a, b) {
              final comparison = _readDate(b.data()['expense_date'])
                  .compareTo(_readDate(a.data()['expense_date']));

              return comparison != 0 ? comparison : b.id.compareTo(a.id);
            });

            final totalExpenses = records.fold<double>(0, (total, doc) {
              final amount = doc.data()['amount'];
              return total + (amount is num ? amount.toDouble() : 0);
            });

            final visibleRecords = records.where((doc) {
              final data = doc.data();

              final searchable = [
                data['category'],
                data['description'],
                data['entered_by'],
              ]
                  .map((value) => value?.toString() ?? '')
                  .join(' ')
                  .toLowerCase();

              return searchable.contains(_searchText);
            }).take(100).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE5EAE7),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0D9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.receipt_long_outlined,
                                color: Color(0xFFD97706),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total expenses',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _money(totalExpenses),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${records.length} expense records',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchText = value.trim().toLowerCase();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search expenses...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchText.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchText = '');
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: visibleRecords.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Text(
                              records.isEmpty
                                  ? 'No expenses recorded yet.\n'
                                      'Tap "Record expense" to begin.'
                                  : 'No matching expenses found.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            88,
                          ),
                          itemCount: visibleRecords.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final data = visibleRecords[index].data();

                            final category =
                                data['category']?.toString() ?? 'Other';
                            final description =
                                data['description']?.toString() ?? '';
                            final amount =
                                (data['amount'] as num?)?.toDouble() ?? 0;
                            final date = _formatDate(
                              _readDate(data['expense_date']),
                            );
                            final enteredBy =
                                data['entered_by']?.toString() ??
                                    'Unknown user';

                            return Card(
                              elevation: 0,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(
                                  color: Color(0xFFE5EAE7),
                                ),
                              ),
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFFFFF0D9),
                                  child: Icon(
                                    Icons.receipt_long_outlined,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                                title: Text(
                                  category,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    [
                                      if (description.isNotEmpty)
                                        description,
                                      'Date: $date',
                                      'Entered by: $enteredBy',
                                    ].join('\n'),
                                  ),
                                ),
                                isThreeLine: true,
                                trailing: Text(
                                  _money(amount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
