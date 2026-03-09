import 'dart:io';
import 'package:flutter/material.dart';

class ComponentCard extends StatelessWidget {
  final Map part;
  final bool readOnly;
  final Function()? onDelete;

  const ComponentCard({
    super.key,
    required this.part,
    required this.readOnly,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = part['image_path'];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: (imagePath != null && imagePath != '')
                      ? Image.file(File(imagePath), fit: BoxFit.cover)
                      : Image.asset(
                          "assets/default_part.jpg",
                          fit: BoxFit.cover,
                        ),
                ),

                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(blurRadius: 3, color: Colors.black26),
                      ],
                    ),
                    child: Text(
                      part['availability'].toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  part['part_name'] ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  "Box: ${part['box_no']}",
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          if (!readOnly)
            Align(
              alignment: Alignment.bottomRight,
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete,
              ),
            ),
        ],
      ),
    );
  }
}
