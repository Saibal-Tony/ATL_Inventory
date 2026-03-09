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
        color: isDark ? const Color.fromARGB(255, 62, 62, 62) : Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            blurRadius: isDark ? 12 : 6,
            color: isDark
                ? Colors.white.withOpacity(0.12)
                : Colors.black.withOpacity(0.15),
            offset: const Offset(0, 4),
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
                    top: Radius.circular(26),
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

                /// AVAILABILITY BUBBLE
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.black, width: 1.2),
                    ),
                    child: Text(
                      part['availability'].toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// DETAILS BOX
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.grey.shade700 : Colors.black,
                  width: 1,
                ),
              ),
            ),
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

                const SizedBox(height: 3),

                /// CATEGORY
                Text(
                  part['category'] ?? "",
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 3),

                /// BOX NUMBER
                Text(
                  "Box: ${part['box_no']}",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          /// EDIT CONTROLS
          if (!readOnly)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      color: Colors.orange,
                      size: 20,
                    ),
                    onPressed: onEdit,
                  ),

                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
