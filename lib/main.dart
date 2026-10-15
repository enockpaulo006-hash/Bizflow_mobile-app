
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

          const Row(
            children: [
              Expanded(
                child: SummaryCard(
                  title: 'Sales',
                  value: '—',
                  icon: Icons.point_of_sale,
                  color: green,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: SummaryCard(
                  title: 'Expenses',
                  value: '—',
                  icon: Icons.receipt_long,
                  color: Color(0xFFD97706),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          const Row(
            children: [
              Expanded(
                child: SummaryCard(
                  title: 'Products',
                  value: '—',
                  icon: Icons.inventory_2_outlined,
                  color: Color(0xFF2563EB),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: SummaryCard(
                  title: 'Low stock',
                  value: '—',
                  icon: Icons.warning_amber_rounded,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
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
                Icon(Icons.info_outline, color: green),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Dashboard figures are placeholders until '
                    'they are connected to real business data.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
