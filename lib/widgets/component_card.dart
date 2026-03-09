import 'dart:io';
import 'package:flutter/material.dart';

class ComponentCard extends StatelessWidget {
  final Map part;
  final bool readOnly;
  final Function()? onDelete;
  final Function()? onEdit;

  const ComponentCard({
    super.key,
    required this.part,
    required this.readOnly,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = part['image_path'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            color: Colors.black.withOpacity(0.15),
            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// IMAGE
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: SizedBox.expand(
                    child: (imagePath != null && imagePath != '')
                        ? Image.file(File(imagePath), fit: BoxFit.cover)
                        : Image.asset(
                            "assets/default_part.jpg",
                            fit: BoxFit.cover,
                          ),
                  ),
                ),

                /// STOCK COUNT
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
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

          /// DETAILS
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// NAME
                Text(
                  part['part_name'] ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 4),

                /// CATEGORY
                Text(
                  part['category'] ?? "",
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                ),

                const SizedBox(height: 4),

                /// BOX NUMBER
                Text(
                  "Box: ${part['box_no']}",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          /// EDIT CONTROLS
          if (!readOnly)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.orange),
                  onPressed: onEdit,
                ),

                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
