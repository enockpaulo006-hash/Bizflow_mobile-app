
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _db = FirebaseFirestore.instance;

  final _searchController = TextEditingController();
  String _searchText = '';

  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection('products');

  CollectionReference<Map<String, dynamic>> get _purchases =>
      _db.collection('purchases');

  CollectionReference<Map<String, dynamic>> get _sales =>
      _db.collection('sales');

  DateTime _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _money(num value) {
    return 'TSh ${value.toStringAsFixed(2)}';
  }

  int _stockAvailable(
    String productId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> purchases,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sales, {
    String? excludedSaleId,
  }) {
    var purchased = 0;
    var sold = 0;

    for (final doc in purchases) {
      if (doc.data()['product_id'] == productId) {
        final quantity = doc.data()['quantity'];
        if (quantity is num) purchased += quantity.toInt();
      }
    }

    for (final doc in sales) {
      if (doc.id == excludedSaleId) continue;

      if (doc.data()['product_id'] == productId) {
        final quantity = doc.data()['quantity'];
        if (quantity is num) sold += quantity.toInt();
      }
    }

    return purchased - sold;
  }

  // Calculate the cost of this sale using the oldest available
  // purchase batches first (FIFO: first in, first out).
  double _fifoCost({
    required String productId,
    required int quantity,
    required DateTime saleDate,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> purchases,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> sales,
    String? excludedSaleId,
  }) {
    final batches = purchases.where((doc) {
      return doc.data()['product_id'] == productId;
    }).toList();

    batches.sort((a, b) {
      final comparison = _date(a.data()['purchase_date'])
          .compareTo(_date(b.data()['purchase_date']));

      return comparison != 0 ? comparison : a.id.compareTo(b.id);
    });

    final remaining = <int>[];
    for (final batch in batches) {
      final amount = batch.data()['quantity'];
      remaining.add(amount is num ? amount.toInt() : 0);
    }

    final priorSales = sales.where((doc) {
      if (doc.id == excludedSaleId) return false;

      final data = doc.data();

      if (data['product_id'] != productId) return false;

      // Process earlier sales before this sale when rebuilding FIFO cost.
      return !_day(_date(data['sale_date'])).isAfter(_day(saleDate));
    }).toList();

    priorSales.sort((a, b) {
      final comparison = _date(a.data()['sale_date'])
          .compareTo(_date(b.data()['sale_date']));

      return comparison != 0 ? comparison : a.id.compareTo(b.id);
    });

    void consumeQuantity(int amount) {
      var left = amount;

      for (var i = 0; i < batches.length && left > 0; i++) {
        if (remaining[i] <= 0) continue;

        final used = remaining[i] < left ? remaining[i] : left;

        remaining[i] -= used;
        left -= used;
      }
    }

    // Existing sales consume stock from the oldest batches first.
    for (final sale in priorSales) {
      final amount = sale.data()['quantity'];
      if (amount is num) consumeQuantity(amount.toInt());
    }

    var unitsLeft = quantity;
    var totalCost = 0.0;

    for (var i = 0; i < batches.length && unitsLeft > 0; i++) {
      if (remaining[i] <= 0) continue;

      final used = remaining[i] < unitsLeft ? remaining[i] : unitsLeft;

      final data = batches[i].data();
      final price = data['buying_price'];

      totalCost += used * (price is num ? price.toDouble() : 0);

      remaining[i] -= used;
      unitsLeft -= used;
    }

    return totalCost;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showSaleForm({
    DocumentSnapshot<Map<String, dynamic>>? sale,
  }) async {
    List<QueryDocumentSnapshot<Map<String, dynamic>>> productDocs;
    List<QueryDocumentSnapshot<Map<String, dynamic>>> purchaseDocs;
    List<QueryDocumentSnapshot<Map<String, dynamic>>> saleDocs;

    try {
      final results = await Future.wait([
        _products.get(),
        _purchases.get(),
        _sales.get(),
      ]);

      productDocs = results[0].docs;
      purchaseDocs = results[1].docs;
      saleDocs = results[2].docs;
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Could not load sales data.'),
        ),
      );
      return;
    }

    if (!mounted) return;

    final oldData = sale?.data() ?? {};
    final oldProductId = oldData['product_id']?.toString();

    final activeProducts = productDocs.where((doc) {
      return doc.data()['is_active'] != false || doc.id == oldProductId;
    }).toList();

    if (activeProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a product before recording a sale.'),
        ),
      );
      return;
    }

    String? selectedProductId = oldProductId;

    if (!activeProducts.any((p) => p.id == selectedProductId)) {
      selectedProductId = activeProducts.first.id;
    }

    final formKey = GlobalKey<FormState>();

    final quantityController = TextEditingController(
      text: oldData['quantity']?.toString() ?? '',
    );

    final priceController = TextEditingController(
      text: oldData['selling_price']?.toString() ?? '',
    );

    DateTime selectedDate = _date(oldData['sale_date']);

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              final stock = selectedProductId == null
                  ? 0
                  : _stockAvailable(
                      selectedProductId!,
                      purchaseDocs,
                      saleDocs,
                      excludedSaleId: sale?.id,
                    );

              return AlertDialog(
                title: Text(
                  sale == null ? 'Record sale' : 'Update sale',
                ),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: selectedProductId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Product *',
                              border: OutlineInputBorder(),
                            ),
                            items: activeProducts.map((doc) {
                              final data = doc.data();

                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(
                                  data['name']?.toString() ?? 'Unnamed',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedProductId = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Select a product';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: stock > 0
                                  ? const Color(0xFFE5F4EC)
                                  : const Color(0xFFFDE8E7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Available stock: $stock units',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: stock > 0
                                    ? const Color(0xFF147D55)
                                    : const Color(0xFFB42318),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: quantityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Quantity sold *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final quantity =
                                  int.tryParse(value?.trim() ?? '');

                              if (quantity == null || quantity <= 0) {
                                return 'Enter a whole number above 0';
                              }

                              if (quantity > stock) {
                                return 'Only $stock units are available';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: priceController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Selling price per unit (TSh) *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final price =
                                  double.tryParse(value?.trim() ?? '');

                              if (price == null || price < 0) {
                                return 'Enter a valid price of 0 or more';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final result = await showDatePicker(
                                  context: dialogContext,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 3650),
                                  ),
                                );

                                if (result != null) {
                                  setDialogState(() {
                                    selectedDate = result;
                                  });
                                }
                              },
                              icon: const Icon(Icons.calendar_today),
                              label: Text(
                                'Date: ${_formatDate(selectedDate)}',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final quantity = int.tryParse(
                                    quantityController.text.trim(),
                                  ) ??
                                  0;
                              final price = double.tryParse(
                                    priceController.text.trim(),
                                  ) ??
                                  0;

                              return Text(
                                'Revenue: ${_money(quantity * price)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
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

                      final productId = selectedProductId;
                      if (productId == null) return;

                      final quantity =
                          int.parse(quantityController.text.trim());

                      final sellingPrice =
                          double.parse(priceController.text.trim());

                      try {
                        // Reload current data before saving to reduce
                        // the risk of using stale stock figures.
                        final freshResults = await Future.wait([
                          _products.get(),
                          _purchases.get(),
                          _sales.get(),
                        ]);

                        final freshProducts = freshResults[0].docs;
                        final freshPurchases = freshResults[1].docs;
                        final freshSales = freshResults[2].docs;

                        final freshProduct = freshProducts
                            .where((doc) => doc.id == productId)
                            .firstOrNull;

                        if (freshProduct == null ||
                            freshProduct.data()['is_active'] == false) {
                          if (!dialogContext.mounted) return;

                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'This product is no longer active.',
                              ),
                            ),
                          );
                          return;
                        }

                        final availableStock = _stockAvailable(
                          productId,
                          freshPurchases,
                          freshSales,
                          excludedSaleId: sale?.id,
                        );

                        if (quantity > availableStock) {
                          if (!dialogContext.mounted) return;

                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Only $availableStock units are available.',
                              ),
                            ),
                          );
                          return;
                        }

                        final cost = _fifoCost(
                          productId: productId,
                          quantity: quantity,
                          saleDate: selectedDate,
                          purchases: freshPurchases,
                          sales: freshSales,
                          excludedSaleId: sale?.id,
                        );

                        final revenue = quantity * sellingPrice;
                        final profit = revenue - cost;

                        final productData = freshProduct.data();

                        final record = <String, dynamic>{
                          'product_id': productId,
                          'product_name':
                              productData['name']?.toString() ?? 'Unnamed',
                          'category':
                              productData['category']?.toString() ?? 'Other',
                          'quantity': quantity,
                          'selling_price': sellingPrice,
                          'revenue': revenue,
                          'cost_price': cost,
                          'profit': profit,
                          'sale_date': Timestamp.fromDate(selectedDate),
                          'user_id': FirebaseAuth.instance.currentUser?.uid,
                          'updated_at': FieldValue.serverTimestamp(),
                        };

                        if (sale == null) {
                          record['created_at'] =
                              FieldValue.serverTimestamp();

                          await _sales.add(record);
                        } else {
                          await sale.reference.update(record);
                        }

                        if (!dialogContext.mounted) return;

                        Navigator.pop(dialogContext);

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                sale == null
                                    ? 'Sale recorded successfully.'
                                    : 'Sale updated successfully.',
                              ),
                            ),
                          );
                        }
                      } on FirebaseException catch (error) {
                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              error.message ?? 'Could not save this sale.',
                            ),
                          ),
                        );
                      } catch (error) {
                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not save sale: $error'),
                          ),
                        );
                      }
                    },
                    child: const Text('Save sale'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      // Let the dialog route finish its closing animation before disposing
      // controllers still referenced by its TextFormFields.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      quantityController.dispose();
      priceController.dispose();
    }
  }

  Future<void> _deleteSale(
    DocumentSnapshot<Map<String, dynamic>> sale,
  ) async {
    final data = sale.data() ?? {};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete sale?'),
        content: Text(
          'Delete the sale record for '
          '"${data['product_name'] ?? 'this product'}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await sale.reference.delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale deleted.')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Could not delete the sale.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF147D55);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sales',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSaleForm(),
        backgroundColor: green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.point_of_sale),
        label: const Text('Record sale'),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _sales.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Could not load sales. Check your connection '
                    'and Firestore security rules.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final records = snapshot.data?.docs.toList() ?? [];

            records.sort((a, b) {
              final comparison = _date(b.data()['sale_date'])
                  .compareTo(_date(a.data()['sale_date']));

              return comparison != 0 ? comparison : b.id.compareTo(a.id);
            });

            var totalUnits = 0;
            var totalRevenue = 0.0;
            var totalProfit = 0.0;

            for (final doc in records) {
              final data = doc.data();
              final quantity = data['quantity'];
              final revenue = data['revenue'];
              final profit = data['profit'];

              if (quantity is num) totalUnits += quantity.toInt();
              if (revenue is num) totalRevenue += revenue.toDouble();
              if (profit is num) totalProfit += profit.toDouble();
            }

            final visibleRecords = records.where((doc) {
              final data = doc.data();

              final searchable = [
                data['product_name'],
                data['category'],
              ]
                  .map((value) => value?.toString() ?? '')
                  .join(' ')
                  .toLowerCase();

              return searchable.contains(_searchText);
            }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _SalesSummary(
                              title: 'Revenue',
                              value: _money(totalRevenue),
                              icon: Icons.payments_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SalesSummary(
                              title: 'Gross profit',
                              value: _money(totalProfit),
                              icon: Icons.trending_up,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _SalesSummary(
                        title: 'Units sold',
                        value: '$totalUnits',
                        icon: Icons.shopping_bag_outlined,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchText = value.trim().toLowerCase();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search sales...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchText.isEmpty
                              ? null
                              : IconButton(
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
                                  ? 'No sales recorded yet.\nTap "Record sale" to begin.'
                                  : 'No matching sales found.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                          itemCount: visibleRecords.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final doc = visibleRecords[index];
                            final data = doc.data();

                            final quantity =
                                (data['quantity'] as num?)?.toInt() ?? 0;
                            final price =
                                (data['selling_price'] as num?)?.toDouble() ??
                                    0;
                            final revenue =
                                (data['revenue'] as num?)?.toDouble() ??
                                    quantity * price;
                            final cost =
                                (data['cost_price'] as num?)?.toDouble() ?? 0;
                            final profit =
                                (data['profit'] as num?)?.toDouble() ??
                                    revenue - cost;

                            final name =
                                data['product_name']?.toString() ??
                                    'Unnamed product';
                            final category =
                                data['category']?.toString() ?? 'Other';
                            final date = _formatDate(
                              _date(data['sale_date']),
                            );

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
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFFDCECE4),
                                  child: Icon(
                                    Icons.point_of_sale,
                                    color: green,
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Text(
                                    '$category\n'
                                    'Quantity: $quantity\n'
                                    'Price/unit: ${_money(price)}\n'
                                    'Revenue: ${_money(revenue)}\n'
                                    'Cost: ${_money(cost)}\n'
                                    'Profit: ${_money(profit)}\n'
                                    'Date: $date',
                                  ),
                                ),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  tooltip: 'Sale actions',
                                  onSelected: (action) {
                                    if (action == 'edit') {
                                      _showSaleForm(sale: doc);
                                    } else if (action == 'delete') {
                                      _deleteSale(doc);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Update sale'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete sale'),
                                    ),
                                  ],
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

class _SalesSummary extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SalesSummary({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5EAE7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF147D55)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
