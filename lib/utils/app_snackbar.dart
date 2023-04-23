import 'package:flutter/material.dart';

abstract class AppSnackbar {
  static void show(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        clipBehavior: Clip.antiAlias,
        elevation: 0.0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 10, left: 90, right: 90),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        content: Center(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
