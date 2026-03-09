import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'package:uuid/uuid.dart';
import 'inventory_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/sync_service.dart';

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

  File? imageFile;

  bool isSaving = false;

  final picker = ImagePicker();

  Future<void> pickFromCamera() async {
    final picked = await picker.pickImage(source: ImageSource.camera);

    if (picked != null) {
      setState(() {
        imageFile = File(picked.path);
      });
    }
  }

  Future<void> pickFromGallery() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        imageFile = File(picked.path);
      });
    }
  }

  Future<void> savePart() async {
    if (isSaving) return;

    if (nameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Part name required")));
      return;
    }

    setState(() {
      isSaving = true;
    });

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
      'image_path': imageFile?.path ?? '',
      'last_updated': DateTime.now().toIso8601String(),
      'sync_status': 0,
    });

    await SyncService().pushLocalParts();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Part Added")));

    serialController.clear();
    nameController.clear();
    categoryController.clear();
    boxController.clear();
    totalController.clear();

    setState(() {
      availability = 0;
      imageFile = null;
      isSaving = false;
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
              decoration: const InputDecoration(labelText: "Serial No"),
            ),

            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Part Name"),
            ),

            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: "Category"),
            ),

            TextField(
              controller: boxController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Box No"),
            ),

            TextField(
              controller: totalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Total Parts"),
            ),

            const SizedBox(height: 20),

            const Text("Availability"),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
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
                  onPressed: () {
                    setState(() {
                      availability++;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Camera"),
                    onPressed: pickFromCamera,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.photo),
                    label: const Text("Gallery"),
                    onPressed: pickFromGallery,
                  ),
                ),
              ],
            ),

            if (imageFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Image.file(imageFile!, height: 150),
              ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: isSaving ? null : savePart,
              child: isSaving
                  ? const CircularProgressIndicator()
                  : const Text("Save Part"),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InventoryScreen(readOnly: false),
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
