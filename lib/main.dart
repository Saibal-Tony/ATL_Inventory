import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database/database_helper.dart';
import 'screens/inventory_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://gdnbjcoxtfcvmfnetkxp.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdkbmJqY294dGZjdm1mbmV0a3hwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA4NTgwNzcsImV4cCI6MjA4NjQzNDA3N30.QxsYV0qd_HleCwq1OAeufUt0M9NoCHIlPiTYoWGyE2w',
  );

  await DatabaseHelper.instance.database;

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "ATL Inventory",
      theme: ThemeData(useMaterial3: true),
      home: InventoryScreen(readOnly: true),
    );
  }
}
