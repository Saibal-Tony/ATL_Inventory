import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class SyncService {
  final supabase = Supabase.instance.client;

  Future<void> pushLocalParts() async {
    final db = await DatabaseHelper.instance.database;

    final parts = await db.query(
      'parts',
      where: 'sync_status = ?',
      whereArgs: [0],
    );

    for (var part in parts) {
      try {
        String imageUrl = (part['image_url'] as String?) ?? '';

        final imagePath = part['image_path'] as String?;

        /// Upload image if exists
        if (imagePath != null && imagePath.isNotEmpty) {
          final file = File(imagePath);

          if (await file.exists()) {
            final path = "parts/${part['id']}.jpg";

            await supabase.storage
                .from('part-images')
                .upload(
                  path,
                  file,
                  fileOptions: const FileOptions(upsert: true),
                );

            imageUrl = supabase.storage.from('part-images').getPublicUrl(path);
          }
        }

        /// Push to Supabase
        await supabase.from('parts').upsert({
          'id': part['id'],
          'serial_no': part['serial_no'],
          'part_name': part['part_name'],
          'category': part['category'],
          'total_parts': part['total_parts'],
          'current_count': part['current_count'],
          'box_no': part['box_no'],
          'availability': part['availability'],
          'image_url': imageUrl,
          'last_updated': part['last_updated'],
        });

        /// Mark synced locally
        await db.update(
          'parts',
          {'sync_status': 1},
          where: 'id=?',
          whereArgs: [part['id']],
        );
      } catch (e) {
        print("Sync error: $e");
      }
    }
  }

  Future<void> pullCloudParts() async {
    final db = await DatabaseHelper.instance.database;

    try {
      final data = await supabase.from('parts').select();

      for (var part in data) {
        await db.insert('parts', {
          'id': part['id'],
          'serial_no': part['serial_no'],
          'part_name': part['part_name'],
          'category': part['category'],
          'total_parts': part['total_parts'],
          'current_count': part['current_count'],
          'box_no': part['box_no'],
          'availability': part['availability'],
          'image_path': '',
          'last_updated': part['last_updated'],
          'sync_status': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    } catch (e) {
      print("Cloud pull error: $e");
    }
  }
}
