
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StockAlertsScreen extends StatelessWidget {
  const StockAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF147D55);

    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Alerts'),
        backgroundColor: green,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: firestore.collection('products').snapshots(),
          builder: (context, productsSnapshot) {
            if (productsSnapshot.hasError) {
              return _message(
                'Could not load products. Check your connection '
                'and Firestore security rules.',
              );
            }

            if (productsSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final products = productsSnapshot.data?.docs
                    .where((doc) => doc.data()['is_active'] != false)
                    .toList() ??
                [];

            if (products.isEmpty) {
              return _emptyState();
            }

            return StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: firestore.collection('purchases').snapshots(),
              builder: (context, purchasesSnapshot) {
                if (purchasesSnapshot.hasError) {
                  return _message(
                    'Could not load purchases. Check your '
                    'Firestore security rules.',
                  );
                }

                if (purchasesSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                return StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: firestore.collection('sales').snapshots(),
                  builder: (context, salesSnapshot) {
                    if (salesSnapshot.hasError) {
                      return _message(
                        'Could not load sales. Check your '
                        'Firestore security rules.',
                      );
                    }

                    if (salesSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final purchased = <String, double>{};
                    final sold = <String, double>{};

                    for (final doc
                        in purchasesSnapshot.data!.docs) {
                      final data = doc.data();
                      final productId =
                          data['product_id']?.toString();

                      if (productId == null ||
                          productId.isEmpty) {
                        continue;
                      }

                      final quantity = _number(data['quantity']);

                      purchased[productId] =
                          (purchased[productId] ?? 0) + quantity;
                    }

                    for (final doc in salesSnapshot.data!.docs) {
                      final data = doc.data();
                      final productId =
                          data['product_id']?.toString();

                      if (productId == null ||
                          productId.isEmpty) {
                        continue;
                      }

                      final quantity = _number(data['quantity']);

                      sold[productId] =
                          (sold[productId] ?? 0) + quantity;
                    }

                    final alerts = <Map<String, dynamic>>[];

                    for (final product in products) {
                      final data = product.data();
                      final totalPurchased =
                          purchased[product.id] ?? 0;
                      final totalSold = sold[product.id] ?? 0;

                      final stock = totalPurchased - totalSold;
                      final percentage = _number(
                        data['reorder_percentage'] ?? 25,
                      );

                      final minimum =
                          totalPurchased * percentage / 100;

                      if (stock <= 0 || stock <= minimum) {
                        alerts.add({
                          'name': data['name']?.toString() ??
                              'Unnamed product',
                          'category':
                              data['category']?.toString() ?? 'Other',
                          'unit': data['unit']?.toString() ?? 'piece',
                          'stock': stock < 0 ? 0.0 : stock,
                          'minimum': minimum,
                          'status': stock <= 0
                              ? 'Out of stock'
                              : 'Low stock',
                        });
                      }
                    }

                    final outOfStock = alerts.where(
                      (item) => _number(item['stock']) <= 0,
                    ).length;

                    final lowStock =
                        alerts.length - outOfStock;

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text(
                          'Inventory status',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Identify products that need restocking.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _AlertSummaryCard(
                                title: 'Low stock',
                                count: lowStock,
                                icon: Icons.warning_amber_rounded,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _AlertSummaryCard(
                                title: 'Out of stock',
                                count: outOfStock,
                                icon: Icons.remove_shopping_cart_outlined,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Products requiring attention',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (alerts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 36,
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 52,
                                  color: green,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No stock alerts',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Products needing attention will '
                                  'appear here.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          ...alerts.map((item) {
                            final stock = _number(item['stock']);
                            final isOut = stock <= 0;
                            final color =
                                isOut ? Colors.red : Colors.orange;

                            return Card(
                              margin: const EdgeInsets.only(
                                bottom: 12,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor:
                                              color.withValues(
                                            alpha: 0.12,
                                          ),
                                          child: Icon(
                                            isOut
                                                ? Icons
                                                    .remove_shopping_cart_outlined
                                                : Icons
                                                    .warning_amber_rounded,
                                            color: color,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['name'].toString(),
                                                style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Text(
                                                item['category']
                                                    .toString(),
                                                style: TextStyle(
                                                  color: Colors
                                                      .grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Flexible(
                                          child: Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 9,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: color.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              item['status'].toString(),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: color,
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _StockValue(
                                            label: 'Current stock',
                                            value:
                                                '${_formatQuantity(stock)} '
                                                '${item['unit']}',
                                          ),
                                        ),
                                        Expanded(
                                          child: _StockValue(
                                            label: 'Minimum stock',
                                            value:
                                                '${_formatQuantity(_number(item['minimum']))} '
                                                '${item['unit']}',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
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

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  static Widget _message(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  static Widget _emptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 56,
              color: Colors.grey,
            ),
            SizedBox(height: 12),
            Text(
              'No products yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add your first product to start tracking stock.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertSummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const _AlertSummaryCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockValue extends StatelessWidget {
  final String label;
  final String value;

  const _StockValue({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
