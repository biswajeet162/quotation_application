import 'package:flutter/material.dart';

class PageHeader extends StatelessWidget {
  final String title;
  final int? count;
  final Widget? actionButton;

  const PageHeader({
    super.key,
    required this.title,
    this.count,
    this.actionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                Text(
                  '($count)',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
          if (actionButton != null) actionButton!,
        ],
      ),
    );
  }
}

