import 'package:flutter/material.dart';


const Color primaryColor = Color(0xFFB71C1C);
const Color paletteRed = Color(0xFF8E1717);
const Color darkTextColor = Color(0xFF1E1E1E);
const Color blackColor = Color(0xFF000000);
const Color whiteColor = Color(0xFFFFFFFF);
const Color backgroundLight = Color(0xFFF0F2F5);
const Color backgroundLighter = Color(0xFFF0F2F5);
const Color confirmGreen = Color(0xFF12A347);


const String logoAsset = 'assets/soufer.png';


const List<BoxShadow> subtleShadows = [
  BoxShadow(
    color: Color(0x1F000000), 
    blurRadius: 8,
    offset: Offset(0, 4),
  ),
  BoxShadow(
    color: Color(0x0A000000), 
    blurRadius: 2,
    offset: Offset(0, 1),
  ),
];

const List<Shadow> textShadows = [
  Shadow(
    color: Color(0x66000000), 
    offset: Offset(0, 1),
    blurRadius: 2,
  ),
];




ButtonStyle primaryButtonStyle({Color? backgroundColor}) {
  return ElevatedButton.styleFrom(
    backgroundColor: backgroundColor ?? primaryColor,
    foregroundColor: whiteColor,
    elevation: 6,
    shadowColor: blackColor.withValues(alpha: 0.25),
    minimumSize: const Size.fromHeight(56),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
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

  const AppLogo({
    super.key,
    this.height = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      logoAsset,
      height: height,
      color: color,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => const Icon(
        Icons.business,
        color: whiteColor,
      ),
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
  return AppBar(
    backgroundColor: primaryColor,
    elevation: 0,
    leading: showBack
        ? IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          )
        : (showLogo
            ? const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Center(child: AppLogo(height: 24)),
              )
            : null),
    automaticallyImplyLeading: false,
    title: showLogo && showBack
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(height: 22),
              const SizedBox(width: 20),
              Flexible(
                child: Text(
                  title.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1.5,
                    shadows: textShadows,
                  ),
                ),
              ),
            ],
          )
        : Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: 2.0,
              shadows: textShadows,
            ),
          ),
    centerTitle: true,
    toolbarHeight: toolbarHeight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
    ),
    actions: actions,
  );
}
