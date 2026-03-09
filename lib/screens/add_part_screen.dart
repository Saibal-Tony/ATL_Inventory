import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'package:uuid/uuid.dart';
import 'inventory_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/sync_service.dart';

class AddPartScreen extends StatefulWidget {
  final bool readOnly;
  final Map<String, dynamic>? part;

  const AddPartScreen({super.key, this.readOnly = false, this.part});

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

  bool get isEditing => widget.part != null;

  @override
  void initState() {
    super.initState();

    if (isEditing) {
      final part = widget.part!;

      serialController.text = part['serial_no'] ?? "";
      nameController.text = part['part_name'] ?? "";
      categoryController.text = part['category'] ?? "";
      boxController.text = part['box_no']?.toString() ?? "";
      totalController.text = part['total_parts']?.toString() ?? "";
      availability = part['availability'] ?? 0;

      if (part['image_path'] != null && part['image_path'] != '') {
        imageFile = File(part['image_path']);
      }
    }
  }

  @override
  void dispose() {
    serialController.dispose();
    nameController.dispose();
    categoryController.dispose();
    boxController.dispose();
    totalController.dispose();
    super.dispose();
  }

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

    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Part name required")));
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final db = await DatabaseHelper.instance.database;

      final totalParts = int.tryParse(totalController.text) ?? 0;

      if (availability > totalParts && totalParts != 0) {
        availability = totalParts;
      }

      final data = {
        'serial_no': serialController.text,
        'part_name': nameController.text,
        'category': categoryController.text,
        'box_no': int.tryParse(boxController.text) ?? 0,
        'total_parts': totalParts,
        'current_count': availability,
        'availability': availability,
        'image_path': imageFile?.path ?? '',
        'last_updated': DateTime.now().toIso8601String(),
        'sync_status': 0,
      };

      if (isEditing) {
        await db.update(
          'parts',
          data,
          where: 'id=?',
          whereArgs: [widget.part!['id']],
        );
      } else {
        final id = const Uuid().v4();

        await db.insert('parts', {'id': id, ...data});
      }

      await SyncService().pushLocalParts();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEditing ? "Part Updated" : "Part Added")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() {
      isSaving = false;
    });
  }

  void increaseAvailability() {
    final total = int.tryParse(totalController.text) ?? 999;

    if (availability < total) {
      setState(() {
        availability++;
      });
    }
  }

  void decreaseAvailability() {
    if (availability > 0) {
      setState(() {
        availability--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? "Edit Part" : "Add Part")),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
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
                  onPressed: decreaseAvailability,
                ),

                Text(
                  availability.toString(),
                  style: const TextStyle(fontSize: 22),
                ),

                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: increaseAvailability,
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
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(imageFile!, height: 150, fit: BoxFit.cover),
                ),
              ),

            const SizedBox(height: 25),

            ElevatedButton(
              onPressed: isSaving ? null : savePart,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: isSaving
                  ? const CircularProgressIndicator()
                  : Text(isEditing ? "Update Part" : "Save Part"),
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
