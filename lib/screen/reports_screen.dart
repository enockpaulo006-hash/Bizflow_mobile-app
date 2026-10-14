
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _db = FirebaseFirestore.instance;

  String _period = 'Last 30 Days';
  DateTime _specificDate = DateTime.now();

  DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _money(num amount) {
    return 'TSh ${amount.toStringAsFixed(2)}';
  }

  bool _isInPeriod(DateTime date) {
    final day = _day(date);
    final today = _day(DateTime.now());

    switch (_period) {
      case 'Today':
        return day == today;

      case 'Yesterday':
        return day == today.subtract(const Duration(days: 1));

      case 'Specific Date':
        return day == _day(_specificDate);

      case 'Last 7 Days':
        final start = today.subtract(const Duration(days: 6));
        return !day.isBefore(start) && !day.isAfter(today);

      case 'Last 30 Days':
        final start = today.subtract(const Duration(days: 29));
        return !day.isBefore(start) && !day.isAfter(today);

      case 'This Month':
        return day.year == today.year && day.month == today.month;

      case 'All Time':
      default:
        return true;
    }
  }

  Future<void> _chooseSpecificDate() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: _specificDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (chosen != null && mounted) {
      setState(() {
        _specificDate = chosen;
        _period = 'Specific Date';
      });
    }
  }

  Map<String, dynamic> _calculateReports({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> sales,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> expenses,
  }) {
    var revenue = 0.0;
    var grossProfit = 0.0;
    var totalExpenses = 0.0;
    var unitsSold = 0;
    var transactionCount = 0;

    final Map<String, Map<String, dynamic>> productResults = {};
    final Map<String, double> expenseResults = {};

    for (final doc in sales) {
      final data = doc.data();
      final date = _readDate(data['sale_date']);

      if (!_isInPeriod(date)) continue;

      final quantityValue = data['quantity'];
      final quantity =
          quantityValue is num ? quantityValue.toInt() : 0;

      final sellingPriceValue = data['selling_price'];
      final sellingPrice =
          sellingPriceValue is num ? sellingPriceValue.toDouble() : 0.0;

      final revenueValue = data['revenue'];
      final saleRevenue = revenueValue is num
          ? revenueValue.toDouble()
          : quantity * sellingPrice;

      final costValue = data['cost_price'];
      final cost = costValue is num ? costValue.toDouble() : 0.0;

      final profitValue = data['profit'];
      final profit = profitValue is num
          ? profitValue.toDouble()
          : saleRevenue - cost;

      revenue += saleRevenue;
      grossProfit += profit;
      unitsSold += quantity;
      transactionCount++;

      final productName =
          data['product_name']?.toString() ?? 'Unnamed product';
      final category = data['category']?.toString() ?? 'Other';
      final key = '$category|$productName';

      productResults.putIfAbsent(
        key,
        () => {
          'name': productName,
          'category': category,
          'quantity': 0,
          'revenue': 0.0,
          'profit': 0.0,
        },
      );

      productResults[key]!['quantity'] =
          (productResults[key]!['quantity'] as int) + quantity;

      productResults[key]!['revenue'] =
          (productResults[key]!['revenue'] as double) + saleRevenue;

      productResults[key]!['profit'] =
          (productResults[key]!['profit'] as double) + profit;
    }

    for (final doc in expenses) {
      final data = doc.data();

      if (!_isInPeriod(_readDate(data['expense_date']))) continue;

      final amountValue = data['amount'];
      final amount =
          amountValue is num ? amountValue.toDouble() : 0.0;

      totalExpenses += amount;

      final category =
          data['category']?.toString().trim().isNotEmpty == true
              ? data['category'].toString().trim()
              : 'Other';

      expenseResults[category] =
          (expenseResults[category] ?? 0) + amount;
    }

    final products = productResults.values.toList()
      ..sort(
        (a, b) => (b['profit'] as double).compareTo(
          a['profit'] as double,
        ),
      );

    final expenseBreakdown = expenseResults.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'revenue': revenue,
      'grossProfit': grossProfit,
      'expenses': totalExpenses,
      'netProfit': grossProfit - totalExpenses,
      'unitsSold': unitsSold,
      'transactionCount': transactionCount,
      'products': products,
      'expenseBreakdown': expenseBreakdown,
    };
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF147D55);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reports',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _db.collection('sales').snapshots(),
          builder: (context, salesSnapshot) {
            if (salesSnapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Could not load sales data. Check Firestore permissions.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (salesSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db.collection('expenses').snapshots(),
              builder: (context, expensesSnapshot) {
                if (expensesSnapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Could not load expense data. Check Firestore permissions.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (expensesSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final report = _calculateReports(
                  sales: salesSnapshot.data?.docs ?? [],
                  expenses: expensesSnapshot.data?.docs ?? [],
                );

                final revenue = report['revenue'] as double;
                final grossProfit = report['grossProfit'] as double;
                final expenses = report['expenses'] as double;
                final netProfit = report['netProfit'] as double;
                final unitsSold = report['unitsSold'] as int;
                final transactionCount =
                    report['transactionCount'] as int;

                final products =
                    report['products'] as List<Map<String, dynamic>>;

                final expenseBreakdown =
                    report['expenseBreakdown'] as List<
                        MapEntry<String, double>>;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Business reports',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Review sales, costs, and business performance.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 18),

                    // Report period selection.
                    DropdownButtonFormField<String>(
                      value: _period,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Report period',
                        prefixIcon: Icon(Icons.calendar_month),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        'Today',
                        'Yesterday',
                        'Specific Date',
                        'Last 7 Days',
                        'Last 30 Days',
                        'This Month',
                        'All Time',
                      ].map((period) {
                        return DropdownMenuItem<String>(
                          value: period,
                          child: Text(period),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          _period = value;
                        });

                        if (value == 'Specific Date') {
                          _chooseSpecificDate();
                        }
                      },
                    ),

                    if (_period == 'Specific Date') ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _chooseSpecificDate,
                        icon: const Icon(Icons.event),
                        label: Text(
                          'Date: ${_formatDate(_specificDate)}',
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Main financial summary.
                    _ReportMetricCard(
                      title: 'Sales revenue',
                      value: _money(revenue),
                      icon: Icons.point_of_sale,
                      color: green,
                    ),
                    const SizedBox(height: 10),
                    _ReportMetricCard(
                      title: 'Gross profit',
                      value: _money(grossProfit),
                      icon: Icons.trending_up,
                      color: const Color(0xFF2563EB),
                    ),
                    const SizedBox(height: 10),
                    _ReportMetricCard(
                      title: 'Expenses',
                      value: _money(expenses),
                      icon: Icons.receipt_long,
                      color: const Color(0xFFD97706),
                    ),
                    const SizedBox(height: 10),
                    _ReportMetricCard(
                      title: 'Net profit',
                      value: _money(netProfit),
                      icon: Icons.account_balance,
                      color: netProfit >= 0
                          ? green
                          : const Color(0xFFDC2626),
                    ),

                    const SizedBox(height: 20),

                    // Operating statistics.
                    Row(
                      children: [
                        Expanded(
                          child: _ReportMetricCard(
                            title: 'Units sold',
                            value: '$unitsSold',
                            icon: Icons.shopping_bag_outlined,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ReportMetricCard(
                            title: 'Sales transactions',
                            value: '$transactionCount',
                            icon: Icons.receipt_outlined,
                            color: const Color(0xFF0D9488),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    const Text(
                      'Product profitability',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (products.isEmpty)
                      const _EmptyReport(
                        message: 'No sales records for this period.',
                      )
                    else
                      ...products.map((product) {
                        final name = product['name'] as String;
                        final category = product['category'] as String;
                        final quantity = product['quantity'] as int;
                        final productRevenue =
                            product['revenue'] as double;
                        final profit = product['profit'] as double;

                        return Card(
                          color: Colors.white,
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(
                              color: Color(0xFFE5EAE7),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  category,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const Divider(height: 20),
                                _ReportDetailRow(
                                  label: 'Units sold',
                                  value: '$quantity',
                                ),
                                _ReportDetailRow(
                                  label: 'Revenue',
                                  value: _money(productRevenue),
                                ),
                                _ReportDetailRow(
                                  label: 'Gross profit',
                                  value: _money(profit),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 18),

                    const Text(
                      'Expense breakdown',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (expenseBreakdown.isEmpty)
                      const _EmptyReport(
                        message: 'No expense records for this period.',
                      )
                    else
                      ...expenseBreakdown.map((entry) {
                        return Card(
                          color: Colors.white,
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                              color: Color(0xFFE5EAE7),
                            ),
                          ),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFFFF0D9),
                              child: Icon(
                                Icons.receipt_long_outlined,
                                color: Color(0xFFD97706),
                              ),
                            ),
                            title: Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: Text(
                              _money(entry.value),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 24),
                    Text(
                      'Period: $_period'
                      '${_period == 'Specific Date' ? ' (${_formatDate(_specificDate)})' : ''}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ReportMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _ReportMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5EAE7),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReportDetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReport extends StatelessWidget {
  final String message;

  const _EmptyReport({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5EAE7),
        ),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade700),
      ),
    );
  }
}
