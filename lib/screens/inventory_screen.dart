import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'add_part_screen.dart';

class InventoryScreen extends StatefulWidget {
  final bool readOnly;
  const InventoryScreen({super.key, required this.readOnly});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>> parts = [];

  Future<void> loadParts() async {
    final db = await DatabaseHelper.instance.database;
    final data = await db.query('parts', orderBy: 'part_name');
    setState(() {
      parts = data;
    });
  }

  Future<void> deletePart(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('parts', where: 'id=?', whereArgs: [id]);
    loadParts();
  }

  @override
  void initState() {
    super.initState();
    loadParts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inventory")),
      body: parts.isEmpty
          ? const Center(child: Text("No items added"))
          : ListView.builder(
              itemCount: parts.length,
              itemBuilder: (context, index) {
                final part = parts[index];
                return Card(
                  child: ListTile(
                    title: Text(part['part_name'] ?? ''),
                    subtitle: Text(
                      "Serial: ${part['serial_no']} | Box: ${part['box_no']} | Avail: ${part['availability']}",
                    ),
                    trailing: widget.readOnly
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => deletePart(part['id']),
                          ),
                  ),
                );
              },
            ),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddPartScreen()),
                );
                loadParts();
              },
              child: const Icon(Icons.add),
            ),
    );
  }
}
