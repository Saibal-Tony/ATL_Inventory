import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../services/sync_service.dart';
import '../widgets/component_card.dart';
import '../widgets/search_bar.dart';
import '../widgets/add_component_dialog.dart';
import 'qr_scanner_screen.dart';

class InventoryScreen extends StatefulWidget {
  final bool readOnly;

  const InventoryScreen({super.key, required this.readOnly});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>> parts = [];
  List<Map<String, dynamic>> filtered = [];

  late bool readOnly;

  @override
  void initState() {
    super.initState();
    readOnly = widget.readOnly;
    initializeData();
  }

  Future<void> initializeData() async {
    await SyncService().pullCloudParts();
    await loadParts();
  }

  Future<void> loadParts() async {
    final db = await DatabaseHelper.instance.database;

    final data = await db.query('parts', orderBy: 'part_name ASC');

    setState(() {
      parts = data;
      filtered = data;
    });
  }

  void scanBox() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QRScannerScreen(
          onScan: (boxNumber) {
            searchParts(boxNumber);
          },
        ),
      ),
    );
  }

  void searchParts(String value) {
    final results = parts.where((p) {
      final name = p['part_name'].toString().toLowerCase();
      final box = p['box_no'].toString();

      return name.contains(value.toLowerCase()) || box.contains(value);
    }).toList();

    setState(() {
      filtered = results;
    });
  }

  void teacherLogin() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Teacher Login"),

          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(labelText: "Password"),
          ),

          actions: [
            TextButton(
              onPressed: () {
                if (controller.text == "aTal@2026") {
                  setState(() {
                    readOnly = false;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Teacher mode enabled")),
                  );
                }

                Navigator.pop(context);
              },
              child: const Text("Login"),
            ),
          ],
        );
      },
    );
  }

  Future<void> deletePart(String id) async {
    final db = await DatabaseHelper.instance.database;

    await db.delete('parts', where: 'id=?', whereArgs: [id]);

    await loadParts();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Part Deleted")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ATL Inventory"),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: scanBox,
          ),
          IconButton(icon: const Icon(Icons.lock), onPressed: teacherLogin),
        ],
      ),

      body: Column(
        children: [
          SearchBarWidget(onSearch: searchParts),

          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      "No components added",
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),

                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.8,
                        ),

                    itemCount: filtered.length,

                    itemBuilder: (context, index) {
                      final part = filtered[index];

                      return ComponentCard(
                        part: part,
                        readOnly: readOnly,
                        onDelete: () {
                          deletePart(part['id']);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),

      floatingActionButton: readOnly
          ? null
          : FloatingActionButton(
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (context) => const AddComponentDialog(),
                );

                await loadParts();
              },
              child: const Icon(Icons.add),
            ),
    );
  }
}
