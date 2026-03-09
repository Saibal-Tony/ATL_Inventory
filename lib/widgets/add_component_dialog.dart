import 'package:flutter/material.dart';
import '../screens/add_part_screen.dart';

class AddComponentDialog extends StatelessWidget {
  const AddComponentDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: SizedBox(height: 500, child: AddPartScreen()),
    );
  }
}
