import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Creates a platform-adaptive route for better PopScope support.
/// iOS uses CupertinoPageRoute for proper swipe-back gesture handling.
Route<T> adaptiveRoute<T>(WidgetBuilder builder) {
  if (!kIsWeb && Platform.isIOS) {
    return CupertinoPageRoute<T>(builder: builder);
  }
  return MaterialPageRoute<T>(builder: builder);
}

/// Shows a confirmation dialog when user tries to discard game progress.
/// Returns true if user confirmed, false otherwise.
Future<bool> showDiscardConfirmationDialog(
  BuildContext context, {
  String title = 'Discard game?',
  String content =
      'Your current game progress will be lost. Are you sure you want to go back?',
}) async {
  final shouldPop = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
  return shouldPop == true;
}
