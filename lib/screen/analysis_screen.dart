
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String _money(num value) => 'TSh ${value.toStringAsFixed(2)}';

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  bool _isInPeriod(DateTime date) {
    final selectedDay = _day(date);
    final today = _day(DateTime.now());

    switch (_period) {
      case 'Today':
        return selectedDay == today;
      case 'Yesterday':
        return selectedDay == today.subtract(const Duration(days: 1));
      case 'Specific Date':
        return selectedDay == _day(_specificDate);
      case 'Last 7 Days':
        return !selectedDay.isBefore(
              today.subtract(const Duration(days: 6)),
            ) &&
            !selectedDay.isAfter(today);
      case 'Last 30 Days':
        return !selectedDay.isBefore(
              today.subtract(const Duration(days: 29)),
            ) &&
            !selectedDay.isAfter(today);
      case 'This Month':
        return selectedDay.year == today.year &&
            selectedDay.month == today.month;
      case 'All Time':
      default:
        return true;
    }
  }

  Future<void> _chooseDate() async {
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

  Map<String, dynamic> _analyse({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> products,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> purchases,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> sales,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> expenses,
  }) {
    var revenue = 0.0;
    var grossProfit = 0.0;
    var expenseTotal = 0.0;
    var unitsSold = 0;

    final productPerformance = <String, Map<String, dynamic>>{};

    for (final doc in sales) {
      final data = doc.data();
      if (!_isInPeriod(_readDate(data['sale_date']))) continue;

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

      final name = data['product_name']?.toString() ?? 'Unnamed product';
      final category = data['category']?.toString() ?? 'Other';
      final key = '${data['product_id'] ?? name}';

      productPerformance.putIfAbsent(
        key,
        () => {
          'name': name,
          'category': category,
          'quantity': 0,
          'revenue': 0.0,
          'profit': 0.0,
        },
      );

      final item = productPerformance[key]!;
      item['quantity'] = (item['quantity'] as int) + quantity;
      item['revenue'] = (item['revenue'] as double) + saleRevenue;
      item['profit'] = (item['profit'] as double) + profit;
    }

    for (final doc in expenses) {
      final data = doc.data();
      if (!_isInPeriod(_readDate(data['expense_date']))) continue;

      final amount = data['amount'];
      if (amount is num) expenseTotal += amount.toDouble();
    }

    final productStock = <String, Map<String, dynamic>>{};

    for (final doc in products) {
      final data = doc.data();
      if (data['is_active'] == false) continue;

      productStock[doc.id] = {
        'name': data['name']?.toString() ?? 'Unnamed product',
        'category': data['category']?.toString() ?? 'Other',
        'reorder_percentage':
            (data['reorder_percentage'] as num?)?.toDouble() ?? 25.0,
        'purchased': 0,
        'sold': 0,
      };
    }

    for (final doc in purchases) {
      final data = doc.data();
      final id = data['product_id']?.toString();
      if (id == null || !productStock.containsKey(id)) continue;

      final quantity = data['quantity'];
      if (quantity is num) {
        final item = productStock[id]!;
        item['purchased'] =
            (item['purchased'] as int) + quantity.toInt();
      }
    }

    for (final doc in sales) {
      final data = doc.data();
      final id = data['product_id']?.toString();
      if (id == null || !productStock.containsKey(id)) continue;

      final quantity = data['quantity'];
      if (quantity is num) {
        final item = productStock[id]!;
        item['sold'] = (item['sold'] as int) + quantity.toInt();
      }
    }

    final stockItems = productStock.values.map((item) {
      final purchased = item['purchased'] as int;
      final sold = item['sold'] as int;
      final stock = (purchased - sold).clamp(0, 1 << 30) as int;
      final threshold = item['reorder_percentage'] as double;
      final stockPercentage =
          purchased > 0 ? stock / purchased * 100 : 0.0;

      String status;
      if (stock <= 0) {
        status = 'OUT OF STOCK';
      } else if (purchased > 0 && stockPercentage <= threshold) {
        status = 'LOW STOCK';
      } else {
        status = 'SUFFICIENT STOCK';
      }

      return {
        ...item,
        'stock': stock,
        'stock_percentage': stockPercentage,
        'status': status,
      };
    }).toList();

    stockItems.sort((a, b) {
      final rank = (item) {
        switch (item['status']) {
          case 'OUT OF STOCK':
            return 0;
          case 'LOW STOCK':
            return 1;
          default:
            return 2;
        }
      };

      final comparison = rank(a).compareTo(rank(b));
      if (comparison != 0) return comparison;

      return (a['name'] as String).compareTo(b['name'] as String);
    });

    final rankedProducts = productPerformance.values.toList()
      ..sort(
        (a, b) => (b['profit'] as double).compareTo(
          a['profit'] as double,
        ),
      );

    return {
      'revenue': revenue,
      'grossProfit': grossProfit,
      'expenses': expenseTotal,
      'netProfit': grossProfit - expenseTotal,
      'unitsSold': unitsSold,
      'products': rankedProducts,
      'stock': stockItems,
    };
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF147D55);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Business Analysis',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _db.collection('products').snapshots(),
          builder: (context, productsSnapshot) {
            if (productsSnapshot.hasError) {
              return const _AnalysisError();
            }
            if (productsSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db.collection('purchases').snapshots(),
              builder: (context, purchasesSnapshot) {
                if (purchasesSnapshot.hasError) {
                  return const _AnalysisError();
                }
                if (purchasesSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _db.collection('sales').snapshots(),
                  builder: (context, salesSnapshot) {
                    if (salesSnapshot.hasError) {
                      return const _AnalysisError();
                    }
                    if (salesSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    return StreamBuilder<
                        QuerySnapshot<Map<String, dynamic>>>(
                      stream: _db.collection('expenses').snapshots(),
                      builder: (context, expensesSnapshot) {
                        if (expensesSnapshot.hasError) {
                          return const _AnalysisError();
                        }
                        if (expensesSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final result = _analyse(
                          products: productsSnapshot.data?.docs ?? [],
                          purchases: purchasesSnapshot.data?.docs ?? [],
                          sales: salesSnapshot.data?.docs ?? [],
                          expenses: expensesSnapshot.data?.docs ?? [],
                        );

                        final revenue = result['revenue'] as double;
                        final grossProfit =
                            result['grossProfit'] as double;
                        final expenses = result['expenses'] as double;
                        final netProfit = result['netProfit'] as double;
                        final unitsSold = result['unitsSold'] as int;

                        final rankedProducts =
                            result['products'] as List<Map<String, dynamic>>;
                        final stockItems =
                            result['stock'] as List<Map<String, dynamic>>;

                        final urgentCount = stockItems
                            .where((item) =>
                                item['status'] == 'OUT OF STOCK' ||
                                item['status'] == 'LOW STOCK')
                            .length;

                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            const Text(
                              'Business performance',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Understand profits, product performance, and stock.',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 18),
                            DropdownButtonFormField<String>(
                              value: _period,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Analysis period',
                                prefixIcon: Icon(Icons.calendar_month),
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                'Today',
                                'Yesterday',
                                'Specific Date',
                                'Last 7 Days',
                                'Last 30 Days',
                                'All Time',
                              ].map((period) {
                                return DropdownMenuItem<String>(
                                  value: period,
                                  child: Text(period),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _period = value);
                                if (value == 'Specific Date') {
                                  _chooseDate();
                                }
                              },
                            ),
                            if (_period == 'Specific Date') ...[
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _chooseDate,
                                icon: const Icon(Icons.event),
                                label: Text(
                                  'Date: ${_formatDate(_specificDate)}',
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            _AnalysisMetric(
                              title: 'Sales revenue',
                              value: _money(revenue),
                              icon: Icons.point_of_sale,
                              color: green,
                            ),
                            const SizedBox(height: 10),
                            _AnalysisMetric(
                              title: 'Gross profit',
                              value: _money(grossProfit),
                              icon: Icons.trending_up,
                              color: const Color(0xFF2563EB),
                            ),
                            const SizedBox(height: 10),
                            _AnalysisMetric(
                              title: 'Expenses',
                              value: _money(expenses),
                              icon: Icons.receipt_long,
                              color: const Color(0xFFD97706),
                            ),
                            const SizedBox(height: 10),
                            _AnalysisMetric(
                              title: 'Net profit',
                              value: _money(netProfit),
                              icon: Icons.account_balance,
                              color: netProfit >= 0
                                  ? green
                                  : const Color(0xFFDC2626),
                            ),
                            const SizedBox(height: 10),
                            _AnalysisMetric(
                              title: 'Units sold',
                              value: '$unitsSold',
                              icon: Icons.shopping_bag_outlined,
                              color: const Color(0xFF7C3AED),
                            ),
                            const SizedBox(height: 10),
                            _AnalysisMetric(
                              title: 'Products needing attention',
                              value: '$urgentCount',
                              icon: Icons.warning_amber_rounded,
                              color: urgentCount > 0
                                  ? const Color(0xFFDC2626)
                                  : green,
                            ),
                            const SizedBox(height: 28),
                            const Text(
                              'Product performance',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (rankedProducts.isEmpty)
                              const _AnalysisEmpty(
                                message: 'No sales for this period.',
                              )
                            else
                              ...rankedProducts.map((item) {
                                return Card(
                                  color: Colors.white,
                                  elevation: 0,
                                  margin: const EdgeInsets.only(bottom: 8),
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
                                          item['name'] as String,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(item['category'] as String),
                                        const Divider(height: 20),
                                        _AnalysisDetail(
                                          label: 'Units sold',
                                          value: '${item['quantity']}',
                                        ),
                                        _AnalysisDetail(
                                          label: 'Revenue',
                                          value: _money(
                                            item['revenue'] as double,
                                          ),
                                        ),
                                        _AnalysisDetail(
                                          label: 'Profit',
                                          value: _money(
                                            item['profit'] as double,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            const SizedBox(height: 22),
                            const Text(
                              'Stock recommendations',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Based on current stock and each product’s '
                              'low-stock percentage.',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (stockItems.isEmpty)
                              const _AnalysisEmpty(
                                message: 'No active products available.',
                              )
                            else
                              ...stockItems.map((item) {
                                final status = item['status'] as String;

                                final Color statusColor;
                                final IconData statusIcon;

                                if (status == 'OUT OF STOCK') {
                                  statusColor = const Color(0xFFDC2626);
                                  statusIcon = Icons.error_outline;
                                } else if (status == 'LOW STOCK') {
                                  statusColor = const Color(0xFFD97706);
                                  statusIcon = Icons.warning_amber_rounded;
                                } else {
                                  statusColor = green;
                                  statusIcon = Icons.check_circle_outline;
                                }

                                return Card(
                                  color: Colors.white,
                                  elevation: 0,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: const BorderSide(
                                      color: Color(0xFFE5EAE7),
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          statusColor.withValues(alpha: 0.12),
                                      child: Icon(
                                        statusIcon,
                                        color: statusColor,
                                      ),
                                    ),
                                    title: Text(
                                      item['name'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        'Category: ${item['category']}\n'
                                        'Purchased: ${item['purchased']}\n'
                                        'Sold: ${item['sold']}\n'
                                        'Current stock: ${item['stock']}\n'
                                        'Stock status: $status',
                                      ),
                                    ),
                                    isThreeLine: true,
                                  ),
                                );
                              }),
                            const SizedBox(height: 20),
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
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AnalysisMetric extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _AnalysisMetric({
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
        border: Border.all(color: const Color(0xFFE5EAE7)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
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

class _AnalysisDetail extends StatelessWidget {
  final String label;
  final String value;

  const _AnalysisDetail({
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
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisEmpty extends StatelessWidget {
  final String message;

  const _AnalysisEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5EAE7)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade700),
      ),
    );
  }
}

class _AnalysisError extends StatelessWidget {
  const _AnalysisError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Could not load analysis data. Check your Firestore security rules.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
