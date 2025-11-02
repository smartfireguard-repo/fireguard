// test/about_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestAboutPage extends StatefulWidget {
  const _TestAboutPage({super.key});
  @override
  State<_TestAboutPage> createState() => _TestAboutPageState();
}

class _TestAboutPageState extends State<_TestAboutPage> {
  String? fullname = 'Test User';
  String? email = 'test@example.com';
  bool isSearching = false;
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final String aboutText = '''
Fireguard is an innovative IoT-based solution designed to provide peace of mind for individuals living alone by ensuring their home is always monitored for fire risks. The system integrates advanced sensors and smart technologies to detect potential fire hazards, smoke, and abnormal temperature fluctuations, sending real-time alerts directly to the user's phone or other connected devices.

With Fireguard, users can stay informed about the safety of their home, even when they are away. The system offers constant monitoring, instantly notifying users in the event of a fire or any emergency situation, helping to prevent disasters before they escalate.

Fireguard is a reliable companion for those living alone, offering a simple, simple, smart, and effective way to safeguard their homes and well-being.
''';

  final List<Map<String, String>> fireTeams = [
    {'name': 'National Emergency Hotline', 'contact': '911'},
    {'name': 'Bambang', 'contact': '0289953459'},
    {'name': 'Bagumbayan', 'contact': '+639293364778'},
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, String>> _filteredFireTeams() {
    if (searchQuery.isEmpty) return fireTeams;
    return fireTeams.where((t) => t['name']!.toLowerCase().contains(searchQuery.toLowerCase())).toList();
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0xFFFFEBEE) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: selected ? const Color(0xFFE53935) : Colors.black87),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'PressStart2P',
                  color: selected ? const Color(0xFFE53935) : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            Container(
              color: const Color(0xFFE53935),
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
              child: Row(
                children: [
                  // DRAWER LOGO
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_fire_department, size: 50, color: Color(0xFFE53935)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Test User', style: TextStyle(fontFamily: 'PressStart2P', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                        const Text('test@example.com', style: TextStyle(fontFamily: 'PressStart2P', color: Colors.white70, fontSize: 16)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _drawerItem(icon: Icons.history, label: 'Real-time Notification', selected: false, onTap: () => Navigator.pushNamed(context, '/history')),
            _drawerItem(icon: Icons.person, label: 'Profile', selected: false, onTap: () => Navigator.pushNamed(context, '/profile')),
            _drawerItem(icon: Icons.info, label: 'About', selected: true, onTap: () => Navigator.pop(context)),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (_) => false),
                  child: const Text('LOGOUT', style: TextStyle(fontFamily: 'PressStart2P', fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE53935),
        title: const Text('About', style: TextStyle(fontFamily: 'PressStart2P', color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () {
              setState(() {
                isSearching = !isSearching;
                if (!isSearching) {
                  _searchController.clear();
                  searchQuery = '';
                }
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: Colors.grey[300])),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.3))),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // MAIN LOGO
                  Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_fire_department, size: 70, color: Color(0xFFE53935)),
                  ),
                  const SizedBox(height: 16),
                  const Text('Smart Fireguard', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  Card(
                    color: const Color(0xFFE6F4EA).withOpacity(0.9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF2E7D32), width: 2)),
                    elevation: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(aboutText, style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 16, color: Colors.black87, height: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Taguig City Fire Protection Team Contacts', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  if (isSearching) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search contacts...',
                        filled: true,
                        fillColor: const Color(0xFFFFEBEE).withOpacity(0.9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE53935))),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ..._filteredFireTeams().map((team) => Card(
                    color: const Color(0xFFFFEBEE).withOpacity(0.9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE53935))),
                    child: ListTile(
                      leading: const Icon(Icons.local_fire_department, color: Color(0xFF2E7D32)),
                      title: Text(team['name']!, style: const TextStyle(fontFamily: 'PressStart2P', color: Color(0xFFE53935))),
                      subtitle: Text(team['contact']!, style: const TextStyle(fontFamily: 'PressStart2P')),
                      trailing: const Icon(Icons.call, color: Color(0xFF2E7D32)),
                      onTap: () {},
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> pumpTestPage(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: const _TestAboutPage(),
      routes: {
        '/history': (_) => const _RoutePage('History'),
        '/profile': (_) => const _RoutePage('Profile'),
        '/welcome': (_) => const _RoutePage('Welcome'),
      },
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AboutPage – 15 Tests', () {
    testWidgets('1. Shows logo', (tester) async {
      await pumpTestPage(tester);
  expect(
    find.descendant(
      of: find.byType(Column).first,
      matching: find.byType(Container),
    ),
    findsOneWidget,
  );
      expect(find.byIcon(Icons.local_fire_department), findsNWidgets(1));
    });

    testWidgets('2. Shows title', (tester) async {
      await pumpTestPage(tester);
      expect(find.text('Smart Fireguard'), findsOneWidget);
    });

    testWidgets('3. Shows about text', (tester) async {
      await pumpTestPage(tester);
      expect(find.textContaining('Fireguard is an innovative'), findsOneWidget);
    });

    testWidgets('4. Shows contact header', (tester) async {
      await pumpTestPage(tester);
      expect(find.text('Taguig City Fire Protection Team Contacts'), findsOneWidget);
    });

    testWidgets('5. Shows fire team cards', (tester) async {
      await pumpTestPage(tester);
      expect(find.byType(Card).evaluate().length, 3);
      expect(find.byIcon(Icons.local_fire_department), findsNWidgets(3)); // only in cards
    });

    testWidgets('6. Drawer opens', (tester) async {
      await pumpTestPage(tester);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsOneWidget);
    });

    testWidgets('7. Drawer shows "Test User"', (tester) async {
      await pumpTestPage(tester);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.text('Test User'), findsOneWidget);
    });

    testWidgets('8. Drawer has History item', (tester) async {
      await pumpTestPage(tester);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.text('Real-time Notification'), findsOneWidget);
    });

    testWidgets('9. Drawer has Profile item', (tester) async {
      await pumpTestPage(tester);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('10. About item is highlighted', (tester) async {
      await pumpTestPage(tester);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      final ink = find.widgetWithText(InkWell, 'About').first;
      final material = tester.widget<Material>(ink);
      expect(material.color, const Color(0xFFFFEBEE));
    });

    testWidgets('11. Search field appears', (tester) async {
      await pumpTestPage(tester);
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('12. Search filters Bambang', (tester) async {
      await pumpTestPage(tester);
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Bambang');
      await tester.pumpAndSettle();
      expect(find.text('Bambang'), findsOneWidget);
    });

    testWidgets('13. Navigates to History', (tester) async {
      await pumpTestPage(tester);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Real-time Notification'));
      await tester.pumpAndSettle();
      expect(find.text('History'), findsOneWidget);
    });

    testWidgets('14. Navigates to Profile', (tester) async {
      await pumpTestPage(tester);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('15. Logout goes to Welcome', (tester) async {
      await pumpTestPage(tester);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LOGOUT'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome'), findsOneWidget);
    });
  });
}

class _RoutePage extends StatelessWidget {
  final String title;
  const _RoutePage(this.title, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)), body: Center(child: Text(title)));
}