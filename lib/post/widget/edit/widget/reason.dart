import 'package:e1547/shared/shared.dart';
import 'package:e1547/ticket/ticket.dart';
import 'package:flutter/material.dart';

class EditReasonDisplay extends StatelessWidget {
  const EditReasonDisplay({super.key, required this.controller, this.enabled});

  final TextEditingController controller;
  final bool? enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: defaultFormPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit reason (optional)'.tr, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'Why are you editing this post?'.tr,
            ),
            enabled: enabled,
          ),
        ],
      ),
    );
  }
}
