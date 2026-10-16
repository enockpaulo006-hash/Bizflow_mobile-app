
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screen/capital_monitor_screen.dart';

import 'firebase_options.dart';
import 'screen/login_screen.dart';
import 'screen/products_screen.dart';
import 'screen/purchases_screen.dart';
import 'screen/sales_screen.dart';
import 'screen/expenses_screen.dart';
import 'screen/reports_screen.dart';
import 'screen/analysis_screen.dart';
import 'screen/users_screen.dart';
import 'screen/stock_alerts_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const BizFlowApp());
}

class BizFlowApp extends StatelessWidget {
  const BizFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF147D55);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BizFlow',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: green,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F6),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F7F6),
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            return const BizFlowDashboard();
          }

          return const LoginScreen();
        },
      ),
    );
  }
}

class BizFlowDashboard extends StatefulWidget {
  const BizFlowDashboard({super.key});

  @override
  State<BizFlowDashboard> createState() => _BizFlowDashboardState();
}

class _BizFlowDashboardState extends State<BizFlowDashboard> {
  int _selectedIndex = 0;

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF147D55);

    final titles = [
      'BizFlow',
      'Stock Alerts',
      'Transactions',
      'Settings',
    ];

    return Scaffold(
      appBar: _selectedIndex == 0
          ? AppBar(
              title: const Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: green,
                    size: 30,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'BizFlow',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () {
                    setState(() {
                      _selectedIndex = 1;
                    });
                  },
                  icon: const Icon(Icons.notifications_none),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: CircleAvatar(
                    backgroundColor: Color(0xFFDCECE4),
                    child: Icon(Icons.person, color: green),
                  ),
                ),
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout),
                ),
              ],
            )
          : AppBar(
              title: Text(titles[_selectedIndex]),
              leading: IconButton(
                tooltip: 'Home',
                icon: const Icon(Icons.home_outlined),
                onPressed: () => _onDestinationSelected(0),
              ),
            ),

      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeContent(context),
          const StockAlertsScreen(),
          const TransactionsTab(),
          SettingsTab(onSignOut: _signOut),
        ],
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context) {
    const green = Color(0xFF147D55);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Business overview',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Manage your business from one place.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 22),

          _buildOverviewCards(),

          const SizedBox(height: 28),

          const Text(
            'Business modules',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.45,
            children: [
              ModuleCard(
                title: 'Products',
                subtitle: 'Manage inventory',
                icon: Icons.inventory_2_outlined,
                onTap: () => _openScreen(
                  context,
                  const ProductsScreen(),
                ),
              ),
              ModuleCard(
                title: 'Purchases',
                subtitle: 'Record purchases',
                icon: Icons.shopping_cart_outlined,
                onTap: () => _openScreen(
                  context,
                  const PurchasesScreen(),
                ),
              ),
              ModuleCard(
                title: 'Sales',
                subtitle: 'Record transactions',
                icon: Icons.point_of_sale,
                onTap: () => _openScreen(
                  context,
                  const SalesScreen(),
                ),
              ),
              ModuleCard(
                title: 'Expenses',
                subtitle: 'Record expenses',
                icon: Icons.receipt_long_outlined,
                onTap: () => _openScreen(
                  context,
                  const ExpensesScreen(),
                ),
              ),
              ModuleCard(
                title: 'Reports',
                subtitle: 'Review performance',
                icon: Icons.bar_chart,
                onTap: () => _openScreen(
                  context,
                  const ReportsScreen(),
                ),
              ),
              ModuleCard(
                title: 'Analysis',
                subtitle: 'Business performance',
                icon: Icons.analytics_outlined,
                onTap: () => _openScreen(
                  context,
                  const AnalysisScreen(),
                ),
              ),
              ModuleCard(
                title: 'Stock Alerts',
                subtitle: 'Monitor inventory',
                icon: Icons.notifications_active_outlined,
                onTap: () => _onDestinationSelected(1),
              ),
              ModuleCard(
                title: 'Capital Monitor',
                subtitle: 'Track capital flow',
                icon: Icons.account_balance_outlined,
                onTap: () => _openScreen(
                  context,
                  const CapitalMonitorScreen(),
                ),
              ),
              ModuleCard(
                title: 'Users',
                subtitle: 'Manage user accounts',
                icon: Icons.people_outline,
                onTap: () => _openScreen(
                  context,
                  const UsersScreen(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE5EAE7),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sync, color: green),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Overview figures update automatically from your '
                    'Firestore sales, expenses, and inventory records.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    final firestore = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore.collection('sales').snapshots(),
      builder: (context, salesSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: firestore.collection('expenses').snapshots(),
          builder: (context, expensesSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: firestore.collection('products').snapshots(),
              builder: (context, productsSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: firestore.collection('purchases').snapshots(),
                  builder: (context, purchasesSnapshot) {
                    final hasError = salesSnapshot.hasError ||
                        expensesSnapshot.hasError ||
                        productsSnapshot.hasError ||
                        purchasesSnapshot.hasError;

                    final isLoading =
                        salesSnapshot.connectionState == ConnectionState.waiting ||
                        expensesSnapshot.connectionState == ConnectionState.waiting ||
                        productsSnapshot.connectionState == ConnectionState.waiting ||
                        purchasesSnapshot.connectionState == ConnectionState.waiting;

                    String salesValue = 'Loading...';
                    String expensesValue = 'Loading...';
                    String productsValue = 'Loading...';
                    String lowStockValue = 'Loading...';

                    if (hasError) {
                      salesValue = 'Unavailable';
                      expensesValue = 'Unavailable';
                      productsValue = 'Unavailable';
                      lowStockValue = 'Unavailable';
                    } else if (!isLoading &&
                        salesSnapshot.data != null &&
                        expensesSnapshot.data != null &&
                        productsSnapshot.data != null &&
                        purchasesSnapshot.data != null) {
                      // Sales and expenses are daily totals. Historical records
                      // remain in Firestore for reports and analysis.
                      final today = DateTime.now();
                      double salesTotal = 0;
                      for (final doc in salesSnapshot.data!.docs) {
                        final data = doc.data();
                        if (!_overviewIsToday(data['sale_date'], today)) {
                          continue;
                        }

                        final revenue = data['revenue'];
                        if (revenue is num) {
                          salesTotal += revenue.toDouble();
                        } else {
                          final quantity = _overviewNumber(data['quantity']);
                          final price = _overviewNumber(data['selling_price']);
                          salesTotal += quantity * price;
                        }
                      }

                      double expensesTotal = 0;
                      for (final doc in expensesSnapshot.data!.docs) {
                        final data = doc.data();
                        if (!_overviewIsToday(data['expense_date'], today)) {
                          continue;
                        }
                        expensesTotal += _overviewNumber(data['amount']);
                      }

                      final activeProducts = productsSnapshot.data!.docs
                          .where((doc) => doc.data()['is_active'] != false)
                          .toList();

                      final purchased = <String, double>{};
                      final sold = <String, double>{};

                      for (final doc in purchasesSnapshot.data!.docs) {
                        final data = doc.data();
                        final productId = data['product_id']?.toString();
                        if (productId == null || productId.isEmpty) continue;
                        purchased[productId] =
                            (purchased[productId] ?? 0) +
                            _overviewNumber(data['quantity']);
                      }

                      for (final doc in salesSnapshot.data!.docs) {
                        final data = doc.data();
                        final productId = data['product_id']?.toString();
                        if (productId == null || productId.isEmpty) continue;
                        sold[productId] =
                            (sold[productId] ?? 0) +
                            _overviewNumber(data['quantity']);
                      }

                      var lowStockCount = 0;
                      for (final product in activeProducts) {
                        final data = product.data();
                        final totalPurchased = purchased[product.id] ?? 0;
                        final totalSold = sold[product.id] ?? 0;
                        final stock = totalPurchased - totalSold;
                        final percentage = _overviewNumber(
                          data['reorder_percentage'] ?? 25,
                        );
                        final minimum = totalPurchased * percentage / 100;

                        if (stock <= 0 || stock <= minimum) {
                          lowStockCount++;
                        }
                      }

                      salesValue = _formatOverviewMoney(salesTotal);
                      expensesValue = _formatOverviewMoney(expensesTotal);
                      productsValue = activeProducts.length.toString();
                      lowStockValue = lowStockCount.toString();
                    }

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: SummaryCard(
                                title: 'Sales',
                                value: salesValue,
                                icon: Icons.point_of_sale,
                                color: const Color(0xFF147D55),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SummaryCard(
                                title: 'Expenses',
                                value: expensesValue,
                                icon: Icons.receipt_long,
                                color: const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SummaryCard(
                                title: 'Products',
                                value: productsValue,
                                icon: Icons.inventory_2_outlined,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SummaryCard(
                                title: 'Low stock',
                                value: lowStockValue,
                                icon: Icons.warning_amber_rounded,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                        if (hasError)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              'Some overview data could not be loaded. Check your '
                              'internet connection and Firestore security rules.',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 12,
                              ),
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
    );
  }

  bool _overviewIsToday(dynamic value, DateTime today) {
    DateTime? date;
    if (value is Timestamp) {
      date = value.toDate().toLocal();
    } else if (value is DateTime) {
      date = value.toLocal();
    } else if (value is String) {
      date = DateTime.tryParse(value)?.toLocal();
    }

    if (date == null) return false;
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  double _overviewNumber(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatOverviewMoney(double amount) {
    return 'TSh ${amount.toStringAsFixed(2)}';
  }

  void _openScreen(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

class TransactionsTab extends StatelessWidget {
  const TransactionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Manage transactions',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose the type of transaction you want to manage.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 20),
        _TransactionOption(
          title: 'Purchases',
          description: 'Record and review stock purchases',
          icon: Icons.shopping_cart_outlined,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PurchasesScreen(),
            ),
          ),
        ),
        _TransactionOption(
          title: 'Sales',
          description: 'Record product sales',
          icon: Icons.point_of_sale,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SalesScreen(),
            ),
          ),
        ),
        _TransactionOption(
          title: 'Expenses',
          description: 'Record business expenses',
          icon: Icons.receipt_long_outlined,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ExpensesScreen(),
            ),
          ),
        ),
      ],
    );
  }
}

class _TransactionOption extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _TransactionOption({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          icon,
          color: const Color(0xFF147D55),
          size: 30,
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class SettingsTab extends StatelessWidget {
  final Future<void> Function() onSignOut;

  const SettingsTab({
    super.key,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Settings',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text('Account information and app options.'),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person_outline),
            ),
            title: const Text('Signed-in account'),
            subtitle: Text(user?.email ?? 'No email available'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign out'),
            subtitle: const Text('Sign out of your BizFlow account'),
            onTap: onSignOut,
          ),
        ),
      ],
    );
  }
}

class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5EAE7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class ModuleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const ModuleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF147D55);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE5EAE7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: green, size: 27),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
