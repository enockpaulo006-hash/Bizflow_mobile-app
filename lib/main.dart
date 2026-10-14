
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
              body: Center(
                child: CircularProgressIndicator(),
              ),
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

class BizFlowDashboard extends StatelessWidget {
  const BizFlowDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF147D55);

    return Scaffold(
      appBar: AppBar(
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
            onPressed: () {},
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
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
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

            // Summary cards are placeholders until connected to real data.
            const Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    title: 'Sales',
                    value: '—',
                    icon: Icons.point_of_sale,
                    color: Color(0xFF147D55),
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProductsScreen(),
                      ),
                    );
                  },
                ),
                ModuleCard(
                  title: 'Purchases',
                  subtitle: 'Record purchases',
                  icon: Icons.shopping_cart_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PurchasesScreen(),
                      ),
                    );
                  },
                ),
                ModuleCard(
                  title: 'Sales',
                  subtitle: 'Record transactions',
                  icon: Icons.point_of_sale,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SalesScreen(),
                      ),
                    );
                  },
                ),const ModuleCard(
                  title: 'Sales',
                  subtitle: 'Record transactions',
                  icon: Icons.point_of_sale,
                ),
                  ModuleCard(
                    title: 'Expenses',
                    subtitle: 'Track business costs',
                    icon: Icons.receipt_long,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ExpensesScreen(),
                        ),
                      );
                    },
                  ),
                    ModuleCard(
                      title: 'Reports',
                      subtitle: 'Review performance',
                      icon: Icons.bar_chart,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ReportsScreen(),
                          ),
                        );
                      },
                    ),
                const ModuleCard(
                  title: 'Users',
                  subtitle: 'Manage access',
                  icon: Icons.people_outline,
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
                  Icon(
                    Icons.info_outline,
                    color: green,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Setup in progress. Dashboard figures will appear '
                      'after business data is connected.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
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
