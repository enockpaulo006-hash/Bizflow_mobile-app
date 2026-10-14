
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final CollectionReference<Map<String, dynamic>> _products =
      FirebaseFirestore.instance.collection('products');

  final CollectionReference<Map<String, dynamic>> _purchases =
      FirebaseFirestore.instance.collection('purchases');

  final CollectionReference<Map<String, dynamic>> _sales =
      FirebaseFirestore.instance.collection('sales');

  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  DateTime _purchaseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _money(num amount) {
    return 'TSh ${amount.toStringAsFixed(2)}';
  }

  Future<int> _quantitySold(String productId) async {
    final result = await _sales
        .where('product_id', isEqualTo: productId)
        .get();

    return result.docs.fold<int>(0, (total, doc) {
      final quantity = doc.data()['quantity'];
      return total + (quantity is num ? quantity.toInt() : 0);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showPurchaseForm({
    DocumentSnapshot<Map<String, dynamic>>? purchase,
  }) async {
    final existingData = purchase?.data() ?? {};
    final oldProductId = existingData['product_id']?.toString();

    List<QueryDocumentSnapshot<Map<String, dynamic>>> availableProducts;

    try {
      final result = await _products.get();

      availableProducts = result.docs.where((doc) {
        return doc.data()['is_active'] != false ||
            doc.id == oldProductId;
      }).toList();
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Could not load products.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    if (availableProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a product before recording a purchase.'),
        ),
      );
      return;
    }

    String? selectedProductId = oldProductId;
    if (!availableProducts.any((p) => p.id == selectedProductId)) {
      selectedProductId = availableProducts.first.id;
    }

    final formKey = GlobalKey<FormState>();

    final quantityController = TextEditingController(
      text: existingData['quantity']?.toString() ?? '',
    );

    final priceController = TextEditingController(
      text: existingData['buying_price']?.toString() ?? '',
    );

    DateTime selectedDate = _purchaseDate(
      existingData['purchase_date'],
    );

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: Text(
                  purchase == null
                      ? 'Record purchase'
                      : 'Update purchase',
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
                            value: selectedProductId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Product *',
                              border: OutlineInputBorder(),
                            ),
                            items: availableProducts.map((doc) {
                              final data = doc.data();
                              final name =
                                  data['name']?.toString() ?? 'Unnamed';

                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(
                                  name,
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
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: quantityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Quantity purchased *',
                              hintText: 'e.g. 100',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final quantity =
                                  int.tryParse(value?.trim() ?? '');

                              if (quantity == null || quantity <= 0) {
                                return 'Enter a whole number greater than 0';
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
                              labelText: 'Buying price per unit (TSh) *',
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
                                final chosenDate = await showDatePicker(
                                  context: dialogContext,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 3650),
                                  ),
                                );

                                if (chosenDate != null) {
                                  setDialogState(() {
                                    selectedDate = chosenDate;
                                  });
                                }
                              },
                              icon: const Icon(Icons.calendar_today),
                              label: Text(
                                'Date: ${_formatDate(selectedDate)}',
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (quantityController.text.isNotEmpty &&
                              priceController.text.isNotEmpty)
                            Text(
                              'Total: ${_money(
                                (int.tryParse(quantityController.text) ?? 0) *
                                    (double.tryParse(
                                          priceController.text,
                                        ) ??
                                        0),
                              )}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
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

                      final productId = selectedProductId;
                      if (productId == null) return;

                      final quantity =
                          int.parse(quantityController.text.trim());
                      final buyingPrice =
                          double.parse(priceController.text.trim());

                      try {
                        final selectedProduct = availableProducts.firstWhere(
                          (doc) => doc.id == productId,
                        );

                        final productData = selectedProduct.data();
                        final productName =
                            productData['name']?.toString() ?? 'Unnamed';
                        final category =
                            productData['category']?.toString() ?? 'Other';

                        // A product has one purchase record, which can be
                        // updated rather than duplicated.
                        final allPurchases = await _purchases.get();

                        final duplicate = allPurchases.docs.any((doc) {
                          return doc.id != purchase?.id &&
                              doc.data()['product_id'] == productId;
                        });

                        if (duplicate) {
                          if (!dialogContext.mounted) return;

                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'A purchase record already exists for this '
                                'product. Open that record to update it.',
                              ),
                            ),
                          );
                          return;
                        }

                        // Do not change the product connected to an existing
                        // purchase if sales already depend on that product.
                        if (oldProductId != null &&
                            oldProductId != productId) {
                          final oldSold = await _quantitySold(oldProductId);

                          if (oldSold > 0) {
                            if (!dialogContext.mounted) return;

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'This purchase cannot be moved because '
                                  'the original product has sales records.',
                                ),
                              ),
                            );
                            return;
                          }
                        }

                        final alreadySold = await _quantitySold(productId);

                        if (quantity < alreadySold) {
                          if (!dialogContext.mounted) return;

                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Quantity cannot be less than the '
                                '$alreadySold units already sold.',
                              ),
                            ),
                          );
                          return;
                        }

                        final record = <String, dynamic>{
                          'product_id': productId,
                          'product_name': productName,
                          'category': category,
                          'quantity': quantity,
                          'buying_price': buyingPrice,
                          'total_cost': quantity * buyingPrice,
                          'purchase_date':
                              Timestamp.fromDate(selectedDate),
                          'user_id':
                              FirebaseAuth.instance.currentUser?.uid,
                          'updated_at': FieldValue.serverTimestamp(),
                        };

                        if (purchase == null) {
                          record['created_at'] =
                              FieldValue.serverTimestamp();
                          await _purchases.add(record);
                        } else {
                          await purchase.reference.update(record);
                        }

                        if (!dialogContext.mounted) return;

                        Navigator.pop(dialogContext);

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                purchase == null
                                    ? 'Purchase recorded successfully.'
                                    : 'Purchase updated successfully.',
                              ),
                            ),
                          );
                        }
                      } on FirebaseException catch (error) {
                        if (!dialogContext.mounted) return;

                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              error.message ?? 'Could not save the purchase.',
                            ),
                          ),
                        );
                      } catch (error) {
                        if (!dialogContext.mounted) return;

                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Could not save purchase: $error',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Save purchase'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      quantityController.dispose();
      priceController.dispose();
    }
  }

  Future<void> _deletePurchase(
    DocumentSnapshot<Map<String, dynamic>> purchase,
  ) async {
    final data = purchase.data() ?? {};
    final productId = data['product_id']?.toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete purchase?'),
        content: Text(
          'Delete the purchase record for '
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

    if (confirmed != true || productId == null) return;

    try {
      final sold = await _quantitySold(productId);

      if (sold > 0) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'This purchase cannot be deleted because $sold units '
              'have already been sold.',
            ),
          ),
        );
        return;
      }

      await purchase.reference.delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase deleted.')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Could not delete the purchase.'),
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
          'Purchases',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPurchaseForm(),
        backgroundColor: green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Record purchase'),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _purchases.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Could not load purchases. Check your connection '
                    'and Firestore security rules.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final records =
                snapshot.data?.docs.toList() ?? [];

            records.sort((a, b) {
              return _purchaseDate(b.data()['purchase_date']).compareTo(
                _purchaseDate(a.data()['purchase_date']),
              );
            });

            final totalUnits = records.fold<int>(0, (total, doc) {
              final quantity = doc.data()['quantity'];
              return total + (quantity is num ? quantity.toInt() : 0);
            });

            final totalCost = records.fold<double>(0, (total, doc) {
              final data = doc.data();
              final savedCost = data['total_cost'];

              if (savedCost is num) return total + savedCost.toDouble();

              final quantity = data['quantity'];
              final price = data['buying_price'];

              return total +
                  (quantity is num ? quantity.toDouble() : 0) *
                      (price is num ? price.toDouble() : 0);
            });

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
                            child: _SummaryTile(
                              title: 'Units purchased',
                              value: '$totalUnits',
                              icon: Icons.inventory_2_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SummaryTile(
                              title: 'Purchase cost',
                              value: _money(totalCost),
                              icon: Icons.payments_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _SummaryTile(
                        title: 'Purchase records',
                        value: '${records.length}',
                        icon: Icons.receipt_long_outlined,
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
                          hintText: 'Search purchase records...',
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
                                  ? 'No purchases recorded yet.\nTap "Record purchase" to start.'
                                  : 'No matching purchase records found.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                          itemCount: visibleRecords.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final doc = visibleRecords[index];
                            final data = doc.data();

                            final quantity =
                                (data['quantity'] as num?)?.toInt() ?? 0;
                            final price =
                                (data['buying_price'] as num?)?.toDouble() ??
                                    0;
                            final savedTotal =
                                (data['total_cost'] as num?)?.toDouble() ??
                                    quantity * price;

                            final name =
                                data['product_name']?.toString() ??
                                    'Unnamed product';
                            final category =
                                data['category']?.toString() ?? 'Other';
                            final date =
                                _formatDate(_purchaseDate(
                              data['purchase_date'],
                            ));

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
                                  vertical: 5,
                                ),
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFFDCECE4),
                                  child: Icon(
                                    Icons.shopping_cart_outlined,
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
                                    'Total: ${_money(savedTotal)}\n'
                                    'Date: $date',
                                  ),
                                ),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  tooltip: 'Purchase actions',
                                  onSelected: (action) {
                                    if (action == 'edit') {
                                      _showPurchaseForm(purchase: doc);
                                    } else if (action == 'delete') {
                                      _deletePurchase(doc);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Update purchase'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete purchase'),
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

class _SummaryTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryTile({
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
        border: Border.all(color: const Color(0xFFE5EAE7)),
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
