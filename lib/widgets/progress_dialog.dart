import 'package:flutter/material.dart';

// =======================================================
// PROGRESS DIALOG
// =======================================================
//
// Shows a spinner over the screen while [task] runs (for
// example signing in), so buttons cannot be pressed twice.
// The spinner is always removed, even if [task] fails.
// =======================================================

Future<T> runWithProgress<T>(
  BuildContext context,
  Future<T> Function() task,
) async {
  final NavigatorState navigator = Navigator.of(context, rootNavigator: true);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (BuildContext dialogContext) {
      return const PopScope(
        canPop: false,
        child: Center(
          child: SizedBox(
            width: 54,
            height: 54,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: Color(0xFF4B2E83),
            ),
          ),
        ),
      );
    },
  );

  try {
    return await task();
  } finally {
    if (navigator.mounted) navigator.pop();
  }
}
