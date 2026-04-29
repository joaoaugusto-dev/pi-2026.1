import 'package:flutter/material.dart';



class ZoomableImageOverlay {
  const ZoomableImageOverlay._();

  static void show(
    BuildContext context, {
    required ImageProvider imageProvider,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Imagem',
      pageBuilder: (ctx, a1, a2) {
        return GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                Container(color: Colors.black.withValues(alpha: 0.45)),
                SafeArea(
                  child: Center(
                    child: GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: MediaQuery.of(ctx).size.width * 0.92,
                        height: MediaQuery.of(ctx).size.height * 0.78,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.86),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 8,
                          panEnabled: true,
                          scaleEnabled: true,
                          child: Center(
                            child: Image(
                              image: imageProvider,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text(
                                        'Não foi possível carregar a imagem.',
                                        style: TextStyle(color: Colors.white),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 48,
                  right: 18,
                  child: GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (ctx, a1, a2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: a1, curve: Curves.easeOut),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 200),
    );
  }
}
