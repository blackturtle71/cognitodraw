import 'package:flutter/material.dart';
import 'features/home.dart';
import 'features/draw.dart';
import 'features/records.dart';
import 'constants/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cognitodraw',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: MaterialTheme.lightScheme()),
      home: NavBar(title: 'Cognitodraw'),
      initialRoute: '/',
      routes: {
        '/draw': (context) => const DrawMenu(),
        '/draw/Cube': (context) => const DrawCube(),
        '/draw/Clock': (context) => const DrawClock(),
      },
    );
  }
}

class NavBar extends StatefulWidget {
  const NavBar({super.key, required this.title});
  final String title;
  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> {
  int curPageIndex = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), centerTitle: true),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            curPageIndex = index;
          });
        },
        selectedIndex: curPageIndex,
        destinations: const <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: 'Профиль',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.draw),
            icon: Icon(Icons.draw_outlined),
            label: 'Задания',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.table_chart),
            icon: Icon(Icons.table_chart_outlined),
            label: 'Данные',
          ),
        ],
      ),
      body: <Widget>[HomePage(), DrawMenu(), RecordsPage()][curPageIndex],
    );
  }
}
