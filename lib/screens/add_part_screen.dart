import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'package:uuid/uuid.dart';
import 'inventory_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AddPartScreen extends StatefulWidget {
  final bool readOnly;
  const AddPartScreen({super.key, this.readOnly = false});

  @override
  State<AddPartScreen> createState() => _AddPartScreenState();
}

class _AddPartScreenState extends State<AddPartScreen> {
  final serialController = TextEditingController();
  final nameController = TextEditingController();
  final categoryController = TextEditingController();
  final boxController = TextEditingController();
  final totalController = TextEditingController();

  int availability = 0;

  Future<void> savePart() async {
    final db = await DatabaseHelper.instance.database;

    await db.insert('parts', {
      'id': const Uuid().v4(),
      'serial_no': serialController.text,
      'part_name': nameController.text,
      'category': categoryController.text,
      'box_no': int.tryParse(boxController.text) ?? 0,
      'total_parts': int.tryParse(totalController.text) ?? 0,
      'current_count': availability,
      'availability': availability,
      'image_path': '',
      'last_updated': DateTime.now().toIso8601String(),
      'sync_status': 0,
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Part Saved")));

    serialController.clear();
    nameController.clear();
    categoryController.clear();
    boxController.clear();
    totalController.clear();

    setState(() {
      availability = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Part")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: serialController,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(labelText: "Serial No"),
            ),
            TextField(
              controller: nameController,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(labelText: "Part Name"),
            ),
            TextField(
              controller: categoryController,
              enabled: !widget.readOnly,
              decoration: const InputDecoration(labelText: "Category"),
            ),
            TextField(
              controller: boxController,
              enabled: !widget.readOnly,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Box No"),
            ),
            TextField(
              controller: totalController,
              enabled: !widget.readOnly,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Total Parts"),
            ),

            const SizedBox(height: 20),
            const Text("Availability", style: TextStyle(fontSize: 16)),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: widget.readOnly
                      ? null
                      : () {
                          setState(() {
                            if (availability > 0) availability--;
                          });
                        },
                ),
                Text(
                  availability.toString(),
                  style: const TextStyle(fontSize: 22),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: widget.readOnly
                      ? null
                      : () {
                          setState(() {
                            availability++;
                          });
                        },
                ),
              ],
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: widget.readOnly ? null : savePart,
              child: const Text("Save Part"),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InventoryScreen(readOnly: widget.readOnly),
                  ),
                );
              },
              child: const Text("View Inventory"),
            ),
          ],
        ),
      ),
    );
  }
}
