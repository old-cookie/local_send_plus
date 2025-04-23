import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

ColorScheme? colorSchemeLight;
ColorScheme? colorSchemeDark;
void resetSystemNavigation(
  BuildContext context,
  SharedPreferences prefs, {
  Color? color,
  Color? statusBarColor,
  Color? systemNavigationBarColor,
  Duration? delay,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (delay != null) {
      await Future.delayed(delay);
    }
    color ??= themeCurrent(context, prefs).colorScheme.surface;
    bool colorsEqual(Color a, Color b) {
      return a.r == b.r && a.g == b.g && a.b == b.b && a.a == b.a;
    }

    Color effectiveStatusColor = (statusBarColor != null) ? statusBarColor : color!;
    bool shouldBeTransparent = !kIsWeb && colorsEqual(effectiveStatusColor, themeCurrent(context, prefs).colorScheme.surface);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarIconBrightness: (effectiveStatusColor.computeLuminance() > 0.179) ? Brightness.dark : Brightness.light,
        statusBarColor: shouldBeTransparent ? Colors.transparent : effectiveStatusColor,
        systemNavigationBarColor: (systemNavigationBarColor != null) ? systemNavigationBarColor : color,
      ),
    );
  });
}

ThemeData themeModifier(ThemeData theme) {
  return theme.copyWith(
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{TargetPlatform.android: PredictiveBackPageTransitionsBuilder()},
    ),
  );
}

ThemeData themeCurrent(BuildContext context, SharedPreferences prefs) {
  final currentMode = themeMode(prefs);
  if (currentMode == ThemeMode.system) {
    if (MediaQuery.of(context).platformBrightness == Brightness.light) {
      return themeLight(prefs);
    } else {
      return themeDark(prefs);
    }
  } else {
    if (currentMode == ThemeMode.light) {
      return themeLight(prefs);
    } else {
      return themeDark(prefs);
    }
  }
}

ThemeData themeLight(SharedPreferences prefs) {
  if (!(prefs.getBool("useDeviceTheme") ?? false) || colorSchemeLight == null) {
    return themeModifier(
      ThemeData.from(
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Colors.black,
          onPrimary: Colors.white,
          secondary: Colors.white,
          onSecondary: Colors.black,
          error: Colors.red,
          onError: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
      ),
    );
  } else {
    return themeModifier(ThemeData.from(colorScheme: colorSchemeLight!));
  }
}

ThemeData themeDark(SharedPreferences prefs) {
  if (!(prefs.getBool("useDeviceTheme") ?? false) || colorSchemeDark == null) {
    return themeModifier(
      ThemeData.from(
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: Colors.white,
          onPrimary: Colors.black,
          secondary: Colors.black,
          onSecondary: Colors.white,
          error: Colors.red,
          onError: Colors.black,
          surface: Colors.black,
          onSurface: Colors.white,
        ),
      ),
    );
  } else {
    return themeModifier(ThemeData.from(colorScheme: colorSchemeDark!));
  }
}

ThemeMode themeMode(SharedPreferences prefs) {
  final brightness = prefs.getString("brightness") ?? "system";
  return (brightness == "system") ? ThemeMode.system : ((brightness == "dark") ? ThemeMode.dark : ThemeMode.light);
}
