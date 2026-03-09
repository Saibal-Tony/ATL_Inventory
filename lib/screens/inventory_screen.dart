import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../services/sync_service.dart';
import '../widgets/component_card.dart';
import '../widgets/search_bar.dart';
import '../widgets/add_component_dialog.dart';
import '../screens/add_part_screen.dart';
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

  bool isConnected = false;
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    readOnly = widget.readOnly;
    initializeData();
  }

  Future<void> initializeData() async {
    await SyncService().pullCloudParts();
    await loadParts();
    await checkConnection();
  }

  Future<void> loadParts() async {
    final db = await DatabaseHelper.instance.database;

    final data = await db.query('parts', orderBy: 'part_name ASC');

    setState(() {
      parts = data;
      filtered = data;
    });
  }

  Future<void> checkConnection() async {
    try {
      await SyncService().pushLocalParts();

      setState(() {
        isConnected = true;
      });
    } catch (e) {
      setState(() {
        isConnected = false;
      });
    }
  }

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  Future<void> scanBox() async {
    await Navigator.push(
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

  void toggleEditMode() {
    if (!readOnly) {
      setState(() {
        readOnly = true;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Edit Mode OFF")));

      return;
    }

    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter Teacher Password"),

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

                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("Edit Mode ON")));
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

  Future<void> editPart(Map<String, dynamic> part) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddPartScreen(
          readOnly: false,
          part: Map<String, dynamic>.from(part),
        ),
      ),
    );

    await loadParts();
  }

  Future<void> refreshInventory() async {
    await initializeData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = isDarkMode ? ThemeData.dark() : ThemeData.light();

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          elevation: 2,
          title: const Text("ATL Inventory"),

          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: refreshInventory,
            ),

            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: scanBox,
            ),

            IconButton(
              icon: Icon(readOnly ? Icons.lock : Icons.lock_open),
              onPressed: toggleEditMode,
            ),

            IconButton(
              icon: Icon(isDarkMode ? Icons.wb_sunny : Icons.nightlight_round),
              onPressed: toggleTheme,
            ),

            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                Icons.circle,
                color: isConnected ? Colors.green : Colors.red,
                size: 14,
              ),
            ),
          ],
        ),

        body: Column(
          children: [
            SearchBarWidget(onSearch: searchParts),

            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        "No components added yet",
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(14),

                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
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

                          onEdit: () {
                            editPart(part);
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
                elevation: 6,

                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (context) => const AddComponentDialog(),
                  );

                  await loadParts();
                  await checkConnection();
                },

                child: const Icon(Icons.add),
              ),
      ),
    );
  }
}
