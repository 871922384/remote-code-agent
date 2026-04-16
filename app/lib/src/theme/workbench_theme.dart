import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'workbench_tokens.dart';

ThemeData buildWorkbenchMaterialTheme() {
  return ThemeData(
    scaffoldBackgroundColor: WorkbenchTokens.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: WorkbenchTokens.primaryBlue,
      surface: WorkbenchTokens.surface,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: WorkbenchTokens.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: WorkbenchTokens.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        color: WorkbenchTokens.textPrimary,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        color: WorkbenchTokens.textSecondary,
      ),
    ),
  );
}

class WorkbenchTheme extends StatelessWidget {
  const WorkbenchTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TDTheme(
      data: TDTheme.defaultData(),
      systemData: buildWorkbenchMaterialTheme(),
      child: child,
    );
  }
}
