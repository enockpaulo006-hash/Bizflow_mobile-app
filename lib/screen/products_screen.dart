
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final CollectionReference<Map<String, dynamic>> _products =
      FirebaseFirestore.instance.collection('products');

  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showProductForm({
    DocumentSnapshot<Map<String, dynamic>>? product,
  }) async {
    final data = product?.data() ?? {};
    final formKey = GlobalKey<FormState>();

    final nameController =
        TextEditingController(text: data['name']?.toString() ?? '');
    final categoryController =
        TextEditingController(text: data['category']?.toString() ?? 'Other');
    final unitController =
        TextEditingController(text: data['unit']?.toString() ?? 'piece');
    final reorderController = TextEditingController(
      text: (data['reorder_percentage'] ?? 25).toString(),
    );

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(product == null ? 'Add product' : 'Edit product'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Product name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter the product name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        hintText: 'e.g. Food, Drinks, Electronics',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: unitController,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        hintText: 'e.g. piece, packet, kg',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter the unit';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: reorderController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Low-stock threshold (%)',
                        helperText: 'Enter a number from 1 to 100',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final percentage =
                            double.tryParse(value?.trim() ?? '');

                        if (percentage == null ||
                            percentage < 1 ||
                            percentage > 100) {
                          return 'Enter a percentage from 1 to 100';
                        }
                        return null;
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

                try {
                  final name = nameController.text.trim();
                  final existingProducts = await _products.get();

                  final duplicate = existingProducts.docs.any((doc) {
                    if (doc.id == product?.id) return false;

                    final existingData = doc.data();
                    final existingName =
                        (existingData['name'] ?? '')
                            .toString()
                            .trim()
                            .toLowerCase();

                    return existingData['is_active'] != false &&
                        existingName == name.toLowerCase();
                  });

                  if (duplicate) {
                    if (!dialogContext.mounted) return;

                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'An active product with this name already exists.',
                        ),
                      ),
                    );
                    return;
                  }

                  final productData = <String, dynamic>{
                    'name': name,
                    'category': categoryController.text.trim().isEmpty
                        ? 'Other'
                        : categoryController.text.trim(),
                    'unit': unitController.text.trim(),
                    'reorder_percentage':
                        double.parse(reorderController.text.trim()),
                    'is_active': true,
                    'updated_at': FieldValue.serverTimestamp(),
                  };

                  if (product == null) {
                    productData['created_at'] =
                        FieldValue.serverTimestamp();
                    await _products.add(productData);
                  } else {
                    await product.reference.update(productData);
                  }

                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          product == null
                              ? 'Product added successfully.'
                              : 'Product updated successfully.',
                        ),
                      ),
                    );
                  }
                } on FirebaseException catch (error) {
                  if (!dialogContext.mounted) return;

                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        error.message ?? 'Could not save the product.',
                      ),
                    ),
                  );
                } catch (_) {
                  if (!dialogContext.mounted) return;

                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not save the product. Try again.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Save product'),
            ),
          ],
        ),
      );
    } finally {
      nameController.dispose();
      categoryController.dispose();
      unitController.dispose();
      reorderController.dispose();
    }
  }

  Future<void> _archiveProduct(
    DocumentSnapshot<Map<String, dynamic>> product,
  ) async {
    final name = product.data()?['name']?.toString() ?? 'this product';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive product?'),
        content: Text(
          'Archive "$name"? It will disappear from active products, '
          'but its historical records will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await product.reference.update({
        'is_active': false,
        'archived_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product archived.')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Could not archive product.'),
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
          'Products',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductForm(),
        backgroundColor: green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchText = value.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search products...',
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
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _products.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Could not load products. Check your connection '
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

                  final products = snapshot.data?.docs.where((doc) {
                        final data = doc.data();
                        final active = data['is_active'] != false;

                        final searchable = [
                          data['name'],
                          data['category'],
                        ]
                            .map((value) => value?.toString() ?? '')
                            .join(' ')
                            .toLowerCase();

                        return active && searchable.contains(_searchText);
                      }).toList() ??
                      [];

                  products.sort((a, b) {
                    final nameA = a.data()['name']?.toString() ?? '';
                    final nameB = b.data()['name']?.toString() ?? '';

                    return nameA.toLowerCase().compareTo(
                          nameB.toLowerCase(),
                        );
                  });

                  if (products.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 56,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchText.isEmpty
                                  ? 'No products yet'
                                  : 'No matching products found',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchText.isEmpty
                                  ? 'Tap "Add product" to register your first product.'
                                  : 'Try another product name or category.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                    itemCount: products.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final data = product.data();

                      final name =
                          data['name']?.toString() ?? 'Unnamed product';
                      final category =
                          data['category']?.toString() ?? 'Other';
                      final unit = data['unit']?.toString() ?? 'piece';
                      final percentage = data['reorder_percentage'] ?? 25;

                      return Card(
                        color: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(
                            color: Color(0xFFE5EAE7),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFDCECE4),
                            child: Icon(
                              Icons.inventory_2_outlined,
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
                              '$category • Unit: $unit • '
                              'Low-stock threshold: $percentage%',
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Product actions',
                            onSelected: (action) {
                              if (action == 'edit') {
                                _showProductForm(product: product);
                              } else if (action == 'archive') {
                                _archiveProduct(product);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit_outlined),
                                  title: Text('Edit'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              PopupMenuItem(
                                value: 'archive',
                                child: ListTile(
                                  leading: Icon(Icons.archive_outlined),
                                  title: Text('Archive'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
