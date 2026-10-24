import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StockAlertsScreen extends StatefulWidget {
  const StockAlertsScreen({super.key});

  @override
  State<StockAlertsScreen> createState() => _StockAlertsScreenState();
}

class _StockAlertsScreenState extends State<StockAlertsScreen> {
  static const Color green = Color(0xFF147D55);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Stock Inventory',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: green,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore.collection('products').snapshots(),
          builder: (context, productsSnapshot) {
            if (productsSnapshot.hasError) {
              return _message(
                'Could not load products. Check your connection '
                'and Firestore security rules.',
              );
            }

            if (productsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final products = productsSnapshot.data?.docs
                    .where((doc) => doc.data()['is_active'] != false)
                    .toList() ??
                [];

            if (products.isEmpty) return _emptyState();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore.collection('purchases').snapshots(),
              builder: (context, purchasesSnapshot) {
                if (purchasesSnapshot.hasError) {
                  return _message(
                    'Could not load purchases. Check your '
                    'Firestore security rules.',
                  );
                }

                if (purchasesSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _firestore.collection('sales').snapshots(),
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

                    // Current purchase records are aggregated per product.
                    final purchasedByProduct = <String, double>{};
                    final soldByProduct = <String, double>{};

                    for (final doc in purchasesSnapshot.data!.docs) {
                      final data = doc.data();
                      final productId = data['product_id']?.toString();

                      if (productId == null || productId.isEmpty) continue;

                      purchasedByProduct[productId] =
                          (purchasedByProduct[productId] ?? 0) +
                              _number(data['quantity']);
                    }

                    for (final doc in salesSnapshot.data!.docs) {
                      final data = doc.data();
                      final productId = data['product_id']?.toString();

                      if (productId == null || productId.isEmpty) continue;

                      soldByProduct[productId] =
                          (soldByProduct[productId] ?? 0) +
                              _number(data['quantity']);
                    }

                    final inventory = <Map<String, dynamic>>[];

                    for (final product in products) {
                      final data = product.data();

                      final purchased =
                          purchasedByProduct[product.id] ?? 0;
                      final sold = soldByProduct[product.id] ?? 0;

                      final rawAvailable = purchased - sold;
                      final available =
                          rawAvailable < 0 ? 0.0 : rawAvailable;

                      // Fixed quantity, not a percentage.
                      // Legacy products without this field default to 5
                      // until the user edits the product.
                      final minimumValue = data['minimum_stock'];
                      final minimum =
                          minimumValue is num && minimumValue >= 1
                              ? minimumValue.toDouble()
                              : 5.0;

                      String status;

                      if (rawAvailable <= 0) {
                        status = 'Out of Stock';
                      } else if (purchased > 0 && available <= minimum) {
                        status = 'Low Stock';
                      } else {
                        status = 'In Stock';
                      }

                      inventory.add({
                        'id': product.id,
                        'name':
                            data['name']?.toString() ?? 'Unnamed product',
                        'category': data['category']?.toString() ?? 'Other',
                        'unit': data['unit']?.toString() ?? 'piece',
                        'purchased': purchased,
                        'sold': sold,
                        'available': available,
                        'minimum': minimum,
                        'status': status,
                      });
                    }

                    // Show urgent stock issues first.
                    inventory.sort((a, b) {
                      int statusOrder(String status) {
                        switch (status) {
                          case 'Out of Stock':
                            return 0;
                          case 'Low Stock':
                            return 1;
                          default:
                            return 2;
                        }
                      }

                      final comparison = statusOrder(
                        a['status'] as String,
                      ).compareTo(statusOrder(b['status'] as String));

                      if (comparison != 0) return comparison;

                      return (a['name'] as String)
                          .toLowerCase()
                          .compareTo((b['name'] as String).toLowerCase());
                    });

                    final outOfStockCount = inventory
                        .where((item) => item['status'] == 'Out of Stock')
                        .length;

                    final lowStockCount = inventory
                        .where((item) => item['status'] == 'Low Stock')
                        .length;

                    final availableProductCount = inventory
                        .where((item) => _number(item['available']) > 0)
                        .length;

                    final filteredInventory = inventory.where((item) {
                      final searchable = [
                        item['name'],
                        item['category'],
                        item['status'],
                      ].join(' ').toLowerCase();

                      return searchable.contains(_searchText);
                    }).toList();

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text(
                          'Inventory overview',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Track purchases, sales, and the quantity '
                          'available for every product.',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cardWidth =
                                (constraints.maxWidth - 24) / 3;

                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: cardWidth,
                                  child: _StockSummaryCard(
                                    title: 'Available products',
                                    count: availableProductCount,
                                    icon: Icons.inventory_2_outlined,
                                    color: green,
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: _StockSummaryCard(
                                    title: 'Low stock',
                                    count: lowStockCount,
                                    icon: Icons.warning_amber_rounded,
                                    color: Colors.orange,
                                  ),
                                ),
                                SizedBox(
                                  width: cardWidth,
                                  child: _StockSummaryCard(
                                    title: 'Out of stock',
                                    count: outOfStockCount,
                                    icon:
                                        Icons.remove_shopping_cart_outlined,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'All products',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchText = value.trim().toLowerCase();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Search product name or category...',
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
                        const SizedBox(height: 12),
                        if (filteredInventory.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Text(
                              _searchText.isEmpty
                                  ? 'No products are available to display.'
                                  : 'No products match '
                                      '"${_searchController.text}".',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          )
                        else
                          ...filteredInventory.map((item) {
                            final status = item['status'] as String;
                            final statusColor = _statusColor(status);
                            final available = _number(item['available']);
                            final purchased = _number(item['purchased']);
                            final sold = _number(item['sold']);
                            final minimum = _number(item['minimum']);
                            final unit = item['unit'].toString();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(
                                  color: Color(0xFFE5EAE7),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: statusColor
                                              .withValues(alpha: 0.12),
                                          child: Icon(
                                            Icons.inventory_2_outlined,
                                            color: statusColor,
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
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                item['category'].toString(),
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 9,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              status,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _QuantityValue(
                                            label: 'Last quantity purchased',
                                            value: _formatQuantity(purchased),
                                            unit: unit,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _QuantityValue(
                                            label: 'Quantity sold',
                                            value: _formatQuantity(sold),
                                            unit: unit,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _QuantityValue(
                                            label: 'Quantity available',
                                            value: _formatQuantity(available),
                                            unit: unit,
                                            valueColor: available <= 0
                                                ? Colors.red
                                                : green,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF5F7F6),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 17,
                                            color: Colors.grey.shade700,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Minimum stock: '
                                              '${_formatQuantity(minimum)} '
                                              '${_unitLabel(unit, minimum)} '
                                              'of ${_formatQuantity(purchased)} '
                                              '${_unitLabel(unit, purchased)} '
                                              'purchased.',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        const SizedBox(height: 8),
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

  static Color _statusColor(String status) {
    switch (status) {
      case 'Out of Stock':
        return Colors.red;
      case 'Low Stock':
        return Colors.orange;
      default:
        return green;
    }
  }

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _formatQuantity(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  static String _unitLabel(String unit, double quantity) {
    if (quantity == 1) return unit;

    final normalized = unit.trim().toLowerCase();

    if (normalized == 'piece') return 'pieces';
    if (normalized.endsWith('s')) return unit;

    if (normalized.endsWith('x') ||
        normalized.endsWith('ch') ||
        normalized.endsWith('sh')) {
      return '${unit}es';
    }

    return '${unit}s';
  }

  static Widget _message(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
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

class _StockSummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const _StockSummaryCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityValue extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color? valueColor;

  const _QuantityValue({
    required this.label,
    required this.value,
    required this.unit,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.black87,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
