import 'package:flutter/material.dart';

const Color primaryColor = Color(0xFFB71C1C);
const Color paletteRed = Color(0xFF8E1717);
const Color darkTextColor = Color(0xFF1E1E1E);
const Color blackColor = Color(0xFF000000);
const Color whiteColor = Color(0xFFFFFFFF);
const Color backgroundLight = Color(0xFFFFFFFF);
const Color backgroundLighter = Color(0xFFFFFFFF);
const Color confirmGreen = Color(0xFF12A347);

const String logoAsset = 'assets/soufer.png';

const List<BoxShadow> subtleShadows = [
  BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 4)),
  BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
];

const List<Shadow> textShadows = [
  Shadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 2),
];

ButtonStyle primaryButtonStyle({Color? backgroundColor}) {
  return ElevatedButton.styleFrom(
    backgroundColor: backgroundColor ?? primaryColor,
    foregroundColor: whiteColor,
    elevation: 6,
    shadowColor: blackColor.withValues(alpha: 0.25),
    minimumSize: const Size.fromHeight(56),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 16,
      shadows: textShadows,
    ),
  );
}

class AppLogo extends StatelessWidget {
  final double height;
  final Color? color;

  const AppLogo({super.key, this.height = 40, this.color});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      logoAsset,
      height: height,
      color: color,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.business, color: whiteColor),
    );
  }
}

AppBar buildAppBar({
  required BuildContext context,
  required String title,
  bool showBack = true,
  bool showLogo = true,
  List<Widget>? actions,
  double toolbarHeight = 80,
}) {
  final theme = Theme.of(context);
  final isHighContrast = theme.brightness == Brightness.light
      ? theme.primaryColor == Colors.black
      : theme.primaryColor == Colors.yellow;

  return AppBar(
    backgroundColor: theme.appBarTheme.backgroundColor,
    elevation: isHighContrast ? 2 : 0,
    leading: showBack
        ? IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: theme.appBarTheme.foregroundColor,
            ),
            onPressed: () => Navigator.of(context).pop(),
          )
        : (showLogo
              ? Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Center(
                    child: AppLogo(
                      height: 24,
                      color: theme.appBarTheme.foregroundColor,
                    ),
                  ),
                )
              : null),
    automaticallyImplyLeading: false,
    title: showLogo && showBack
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLogo(height: 22, color: theme.appBarTheme.foregroundColor),
              const SizedBox(width: 20),
              Flexible(
                child: Text(
                  title.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.appBarTheme.foregroundColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1.5,
                    shadows: isHighContrast ? null : textShadows,
                  ),
                ),
              ),
            ],
          )
        : Text(
            title.toUpperCase(),
            style: TextStyle(
              color: theme.appBarTheme.foregroundColor,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: 2.0,
              shadows: isHighContrast ? null : textShadows,
            ),
          ),
    centerTitle: true,
    toolbarHeight: toolbarHeight,
    shape: isHighContrast
        ? Border(
            bottom: BorderSide(
              color: theme.appBarTheme.foregroundColor!,
              width: 2,
            ),
          )
        : null,
    actions: actions,
  );
}

ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: whiteColor,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      onPrimary: whiteColor,
      secondary: primaryColor,
      onSecondary: whiteColor,
      secondaryContainer: Color(0xFFFFEBEE), // Light red/pink
      onSecondaryContainer: paletteRed,
      surface: whiteColor,
      onSurface: darkTextColor,
      surfaceContainerHighest: whiteColor,
      error: paletteRed,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: whiteColor,
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle()),
  );
}

const Color primaryColorDark = Color(
  0xFFFF5252,
); // More vibrant red for Dark Mode

ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColorDark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    colorScheme: const ColorScheme.dark(
      primary: primaryColorDark,
      onPrimary: whiteColor,
      secondary: primaryColorDark,
      onSecondary: whiteColor,
      secondaryContainer: Color(
        0xFF442B2B,
      ), // Slightly lighter/more visible dark red
      onSecondaryContainer: Color(
        0xFFFF8A80,
      ), // Vibrant light red for text on container
      surface: Color(0xFF1E1E1E),
      onSurface: whiteColor,
      surfaceContainerHighest: Color(0xFF2C2C2C),
      error: primaryColorDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: whiteColor,
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: primaryButtonStyle(backgroundColor: primaryColorDark),
    ),
  );
}

ThemeData buildHighContrastTheme(bool isDark) {
  if (isDark) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: Colors.yellow,
      scaffoldBackgroundColor: Colors.black,
      canvasColor: Colors.black,
      colorScheme: const ColorScheme.dark(
        primary: Colors.yellow,
        onPrimary: Colors.black,
        surface: Colors.black,
        onSurface: Colors.white,
        secondary: Colors.yellow,
        onSecondary: Colors.black,
        outline: Colors.yellow,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.yellow,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.yellow,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.yellow),
      ),
      dividerTheme: const DividerThemeData(color: Colors.yellow, thickness: 2),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.yellow,
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.grey.shade800,
          disabledForegroundColor: Colors.white,
          side: const BorderSide(color: Colors.yellow, width: 2),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.yellow,
          side: const BorderSide(color: Colors.yellow, width: 2),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.yellow, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 3),
        ),
        labelStyle: TextStyle(
          color: Colors.yellow,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  } else {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: Colors.black,
      scaffoldBackgroundColor: Colors.white,
      canvasColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: Colors.black,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: Colors.black,
        secondary: Colors.black,
        onSecondary: Colors.white,
        outline: Colors.black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      dividerTheme: const DividerThemeData(color: Colors.black, thickness: 2),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          side: const BorderSide(color: Colors.black, width: 2),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: const BorderSide(color: Colors.black, width: 2),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue, width: 3),
        ),
        labelStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      ),
    );
  }
}
