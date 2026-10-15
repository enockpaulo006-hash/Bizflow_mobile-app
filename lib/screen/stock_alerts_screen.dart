
import 'package:flutter/material.dart';

class StockAlertsScreen extends StatelessWidget {
  const StockAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF147D55);

    // Sample data for designing the screen.
    // We will connect real Firebase data later.
    final alerts = [
      {
        'name': 'Sugar',
        'category': 'Food items',
        'stock': 3,
        'minimum': 10,
        'unit': 'kg',
        'status': 'Low stock',
      },
      {
        'name': 'Cooking Oil',
        'category': 'Food items',
        'stock': 0,
        'minimum': 8,
        'unit': 'litres',
        'status': 'Out of stock',
      },
      {
        'name': 'Rice',
        'category': 'Food items',
        'stock': 5,
        'minimum': 15,
        'unit': 'kg',
        'status': 'Low stock',
      },
    ];

    final outOfStock =
        alerts.where((item) => item['stock'] == 0).length;
    final lowStock =
        alerts.where((item) => item['stock'] != 0).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Alerts'),
        backgroundColor: green,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
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
              style: TextStyle(color: Colors.grey.shade700),
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

            ...alerts.map((item) {
              final isOut = item['stock'] == 0;
              final color = isOut ? Colors.red : Colors.orange;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.12),
                            child: Icon(
                              isOut
                                  ? Icons.remove_shopping_cart_outlined
                                  : Icons.warning_amber_rounded,
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
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  item['category'].toString(),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              item['status'].toString(),
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
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
                                  '${item['stock']} ${item['unit']}',
                            ),
                          ),
                          Expanded(
                            child: _StockValue(
                              label: 'Minimum stock',
                              value:
                                  '${item['minimum']} ${item['unit']}',
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
