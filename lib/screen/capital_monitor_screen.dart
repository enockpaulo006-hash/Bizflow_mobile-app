
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CapitalMonitorScreen extends StatefulWidget {
  const CapitalMonitorScreen({super.key});

  @override
  State<CapitalMonitorScreen> createState() =>
      _CapitalMonitorScreenState();
}

class _CapitalMonitorScreenState extends State<CapitalMonitorScreen> {
  static const green = Color(0xFF147D55);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _selectedPeriod = 'This month';
  late Future<_CapitalData> _dataFuture;
  Timer? _dayChangeTimer;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
    _scheduleNextDayRefresh();
  }

  void _scheduleNextDayRefresh() {
    _dayChangeTimer?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _dayChangeTimer = Timer(
      nextDay.difference(now) + const Duration(seconds: 1),
      () async {
        if (!mounted) return;
        await _refresh();
        if (mounted) _scheduleNextDayRefresh();
      },
    );
  }

  @override
  void dispose() {
    _dayChangeTimer?.cancel();
    super.dispose();
  }

  Future<_CapitalData> _loadData() async {
    final results = await Future.wait([
      _db.collection('sales').get(),
      _db.collection('purchases').get(),
      _db.collection('expenses').get(),
    ]);

    return _CapitalData(
      sales: results[0].docs,
      purchases: results[1].docs,
      expenses: results[2].docs,
    );
  }

  DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime(2000);
    }
    return DateTime(2000);
  }

  bool _isInPeriod(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final transactionDay = DateTime(date.year, date.month, date.day);

    switch (_selectedPeriod) {
      case 'This month':
        return date.year == now.year && date.month == now.month;
      case 'Last 3 months':
        final start = DateTime(now.year, now.month - 2, 1);
        return !date.isBefore(start) &&
            date.isBefore(DateTime(now.year, now.month + 1, 1));
      case 'This year':
        return date.year == now.year;
      case 'All time':
        return true;
      default:
        return !transactionDay.isBefore(today);
    }
  }

  double _number(dynamic value) {
    return value is num ? value.toDouble() : 0;
  }

  String _money(num value) {
    return 'TSh ${value.toStringAsFixed(2)}';
  }

  Future<void> _refresh() async {
    setState(() {
      _dataFuture = _loadData();
    });
    await _dataFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Capital Monitor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh records',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_CapitalData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Could not load financial records. '
                      'Check your connection and Firestore security rules.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;

          final sales = data.sales.where((doc) {
            return _isInPeriod(_readDate(doc.data()['sale_date']));
          }).toList();

          final purchases = data.purchases.where((doc) {
            return _isInPeriod(
              _readDate(doc.data()['purchase_date']),
            );
          }).toList();

          final expenses = data.expenses.where((doc) {
            return _isInPeriod(
              _readDate(doc.data()['expense_date']),
            );
          }).toList();

          final losses = sales.where((doc) {
            final record = doc.data();
            final profit = record['profit'];

            if (profit is num) return profit < 0;

            final revenue = _number(record['revenue']);
            final cost = _number(record['cost_price']);
            return revenue - cost < 0;
          }).toList();

          // Stock-capital figures are all-time figures, not daily totals.
          // The purchase screen stores one purchase record per product.
          final totalStockInvestment = data.purchases.fold<double>(
            0,
            (total, doc) {
              final record = doc.data();
              final savedCost = record['total_cost'];
              final cost = savedCost is num
                  ? savedCost.toDouble()
                  : _number(record['quantity']) *
                      _number(record['buying_price']);
              return total + cost;
            },
          );

          final soldQuantityByProduct = <String, double>{};
          for (final saleDoc in data.sales) {
            final record = saleDoc.data();
            final productId = record['product_id']?.toString();
            if (productId == null || productId.isEmpty) continue;
            soldQuantityByProduct[productId] =
                (soldQuantityByProduct[productId] ?? 0) +
                    _number(record['quantity']);
          }

          final currentStockCapital = data.purchases.fold<double>(
            0,
            (total, purchaseDoc) {
              final record = purchaseDoc.data();
              final productId = record['product_id']?.toString() ?? '';
              final purchasedQuantity = _number(record['quantity']);
              final soldQuantity = soldQuantityByProduct[productId] ?? 0;
              final remainingQuantity =
                  (purchasedQuantity - soldQuantity)
                      .clamp(0, double.infinity)
                      .toDouble();
              return total +
                  remainingQuantity * _number(record['buying_price']);
            },
          );

          // Sales records save cost_price as the cost of the quantity sold.
          final capitalCostOfGoodsSold = data.sales.fold<double>(
            0,
            (total, doc) => total + _number(doc.data()['cost_price']),
          );

          final salesRevenue = data.sales.fold<double>(
            0,
            (total, doc) => total + _number(doc.data()['revenue']),
          );

          final expenseTotal = expenses.fold<double>(0, (total, doc) {
            return total + _number(doc.data()['amount']);
          });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Investment Capital',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.lock_outline,
                          color: Colors.white,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Total stock investment recorded',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _money(totalStockInvestment),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Calculated automatically from purchase records. '
                      'This is stock purchase cost, not the full business '
                      'cash balance or net worth.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () {
                        _showInformation(
                          'Capital calculation',
                          'A reliable capital balance requires '
                              'verified opening balances, cash, '
                              'inventory, receivables, liabilities '
                              'and owner contributions or withdrawals. '
                              'Purchasing stock is not automatically '
                              'a loss. Missing information will not '
                              'be guessed.',
                        );
                      },
                      icon: const Icon(Icons.info_outline),
                      label: const Text('How is capital calculated?'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Stock capital overview',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  _CapitalMetric(
                    title: 'Total stock investment',
                    value: _money(totalStockInvestment),
                    icon: Icons.savings_outlined,
                    color: const Color(0xFF2563EB),
                  ),
                  _CapitalMetric(
                    title: 'Current stock capital',
                    value: _money(currentStockCapital),
                    icon: Icons.inventory_2_outlined,
                    color: green,
                  ),
                  _CapitalMetric(
                    title: 'Cost of stock sold',
                    value: _money(capitalCostOfGoodsSold),
                    icon: Icons.shopping_cart_checkout_outlined,
                    color: Colors.orange,
                  ),
                  _CapitalMetric(
                    title: 'Sales revenue recorded',
                    value: _money(salesRevenue),
                    icon: Icons.point_of_sale,
                    color: const Color(0xFF7C3AED),
                  ),
                ],
              ),

              const SizedBox(height: 26),

              const Text(
                'Capital history',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose a period for the records below.',
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPeriod,
                        decoration: const InputDecoration(
                          labelText: 'Period',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'This month',
                            child: Text('This month'),
                          ),
                          DropdownMenuItem(
                            value: 'Last 3 months',
                            child: Text('Last 3 months'),
                          ),
                          DropdownMenuItem(
                            value: 'This year',
                            child: Text('This year'),
                          ),
                          DropdownMenuItem(
                            value: 'All time',
                            child: Text('All time'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedPeriod = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'A reliable capital timeline is not available '
                        'yet. The transaction records below are '
                        'filtered by the selected period.',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      _CapitalMetric(
                        title: 'Purchase costs in period',
                        value: _money(purchases.fold<double>(
                          0,
                          (total, doc) {
                            final record = doc.data();
                            final saved = record['total_cost'];

                            if (saved is num) {
                              return total + saved.toDouble();
                            }

                            return total +
                                _number(record['quantity']) *
                                    _number(record['buying_price']);
                          },
                        )),
                        icon: Icons.shopping_cart_outlined,
                        color: green,
                      ),
                      const SizedBox(height: 8),
                      _CapitalMetric(
                        title: 'Expenses in period',
                        value: _money(expenseTotal),
                        icon: Icons.receipt_long_outlined,
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 26),

              const Text(
                'Loss investigation',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Recorded losses and expenses requiring review.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),

              if (losses.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.check_circle_outline,
                      color: green,
                    ),
                    title: Text('No recorded sales losses found'),
                    subtitle: Text(
                      'This does not prove that the business has '
                      'no other losses.',
                    ),
                  ),
                )
              else
                ...losses.map((doc) {
                  final record = doc.data();
                  final profit = record['profit'];
                  final lossAmount = profit is num
                      ? -profit.toDouble()
                      : _number(record['cost_price']) -
                          _number(record['revenue']);

                  final name = record['product_name']?.toString() ??
                      'Unnamed product';

                  final date = _readDate(record['sale_date']);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(
                          Icons.trending_down,
                          color: Colors.red,
                        ),
                      ),
                      title: Text(name),
                      subtitle: Text(
                        'Recorded sales loss\n'
                        'Date: ${date.year}-'
                        '${date.month.toString().padLeft(2, '0')}-'
                        '${date.day.toString().padLeft(2, '0')}\n'
                        'Quantity: ${record['quantity'] ?? 'Unknown'}',
                      ),
                      trailing: Text(
                        _money(lossAmount > 0 ? lossAmount : 0),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () {
                        _showInformation(
                          'Recorded sales loss',
                          'Product: $name\n'
                              'Selling revenue: '
                              '${_money(_number(record['revenue']))}\n'
                              'Recorded cost: '
                              '${_money(_number(record['cost_price']))}\n'
                              'Recorded loss: '
                              '${_money(lossAmount > 0 ? lossAmount : 0)}\n'
                              'Date: ${date.toLocal()}\n'
                              'Recorded by user ID: '
                              '${record['user_id'] ?? 'Unavailable'}',
                        );
                      },
                    ),
                  );
                }),

              const SizedBox(height: 12),

              const Text(
                'Expenses requiring review',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              if (expenses.isEmpty)
                const Card(
                  child: ListTile(
                    title: Text('No expenses in this period'),
                  ),
                )
              else
                ...expenses.map((doc) {
                  final record = doc.data();
                  final amount = _number(record['amount']);
                  final category =
                      record['category']?.toString() ?? 'Other';
                  final description =
                      record['description']?.toString() ?? '';
                  final date = _readDate(record['expense_date']);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(
                          Icons.receipt_long_outlined,
                          color: Colors.orange,
                        ),
                      ),
                      title: Text(category),
                      subtitle: Text(
                        '${description.isEmpty ? 'No description' : description}\n'
                        'Date: ${date.year}-'
                        '${date.month.toString().padLeft(2, '0')}-'
                        '${date.day.toString().padLeft(2, '0')}\n'
                        'Entered by: '
                        '${record['entered_by'] ?? record['user_id'] ?? 'Unknown'}',
                      ),
                      trailing: Text(
                        _money(amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () {
                        _showInformation(
                          'Expense review',
                          'Category: $category\n'
                              'Description: $description\n'
                              'Amount: ${_money(amount)}\n'
                              'Date: ${date.toLocal()}\n\n'
                              'This expense is shown for investigation. '
                              'It is not automatically classified as '
                              'a loss.',
                        );
                      },
                    ),
                  );
                }),

              const SizedBox(height: 12),

              const Card(
                child: ListTile(
                  leading: Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.orange,
                  ),
                  title: Text('Stock shortage investigation'),
                  subtitle: Text(
                    'A physical stock count is required before '
                    'a stock shortage or its financial value '
                    'can be confirmed.',
                  ),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Access note: hiding this screen is not sufficient '
                'to secure financial records. Boss-only access must '
                'also be enforced through authentication and '
                'Firestore security rules.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showInformation(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _CapitalData {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> sales;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> purchases;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> expenses;

  const _CapitalData({
    required this.sales,
    required this.purchases,
    required this.expenses,
  });
}

class _CapitalMetric extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _CapitalMetric({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
