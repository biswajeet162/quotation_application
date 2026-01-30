import 'package:flutter/material.dart';

class PageHeader extends StatelessWidget {
  final String title;
  final Widget? actionButton;

  const PageHeader({
    super.key,
    required this.title,
    this.actionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if (actionButton != null) actionButton!,
        ],
      ),
    );
  }
}

