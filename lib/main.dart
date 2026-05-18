import 'package:flutter/material.dart';
import 'features/home.dart';
import 'features/draw.dart';
import 'constants/theme.dart';
import 'utils/utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // purge user meta
  await clearSharedPreferences();
  // purge user files
  List paths = [];
  paths = await StorageUtils.checkDownloadsDir();
  if (paths.isNotEmpty) {
    for (var path in paths) {
      final file = File(path);
      await file.delete();
    }
  }

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
    final ThemeData theme = Theme.of(context);
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
            label: 'Домашняя страница',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.draw),
            icon: Icon(Icons.draw_outlined),
            label: 'Страница с заданиями',
          ),
        ],
      ),
      body: <Widget>[HomePage(), DrawMenu()][curPageIndex],
    );
  }
}
