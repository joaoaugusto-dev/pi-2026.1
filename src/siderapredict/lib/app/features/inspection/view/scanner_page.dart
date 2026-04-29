import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:siderapredict/app/routes/app_pages.dart';
import 'package:siderapredict/app/routes/app_routes.dart';
import 'package:siderapredict/app/core/theme/theme.dart';
import 'package:siderapredict/app/features/inspection/view/camera_overlay.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/scanner_viewmodel.dart';

class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ScannerViewModel>();

    if (viewModel.cameras.isEmpty) {
      return Scaffold(
        appBar: buildAppBar(context: context, title: 'Câmera'),
        body: const Center(
          child: Text('Nenhuma câmera encontrada neste dispositivo.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: blackColor,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: ClipRRect(
          child: AppBar(
            backgroundColor: primaryColor,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'INSPEÇÃO DIGITAL',
              style: TextStyle(
                color: whiteColor,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 2,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.close, color: whiteColor, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: const [
              SizedBox(width: 48),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: viewModel.controller != null && viewModel.initializeControllerFuture != null
                ? FutureBuilder<void>(
                    future: viewModel.initializeControllerFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done && viewModel.isInitialized) {
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final size = constraints.biggest;
                            var scale =
                                size.aspectRatio *
                                viewModel.controller!.value.aspectRatio;
                            if (scale < 1) scale = 1 / scale;

                            return ClipRect(
                              child: Transform.scale(
                                scale: scale,
                                child: Center(
                                  child: CameraPreview(viewModel.controller!),
                                ),
                              ),
                            );
                          },
                        );
                      }
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(color: whiteColor),
                            const SizedBox(height: 16),
                            Text(
                              'INICIALIZANDO ÓPTICA...',
                              style: TextStyle(
                                color: whiteColor.withValues(alpha: 0.5),
                                fontSize: 10,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : const Center(
                    child: CircularProgressIndicator(color: whiteColor),
                  ),
          ),

          CameraOverlay(rollDegrees: viewModel.rollDegrees, pitchDegrees: viewModel.pitchDegrees),



          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    blackColor.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 48,
                    child: Column(
                      children: [
                        IconButton(
                          onPressed: viewModel.toggleFlash,
                          icon: Icon(
                            _getFlashIcon(viewModel.flashMode),
                            color: whiteColor,
                            size: 28,
                          ),
                        ),
                        const Text(
                          'FLASH',
                          style: TextStyle(
                            color: whiteColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  GestureDetector(
                    onTap: viewModel.isCapturing ? null : () => _onCapture(context, viewModel),
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: whiteColor, width: 4),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: viewModel.isCapturing ? paletteRed : whiteColor,
                        ),
                        child: viewModel.isCapturing
                            ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: whiteColor,
                                    strokeWidth: 3,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),

                  Positioned(
                    right: 48,
                    child: Column(
                      children: [
                        IconButton(
                          onPressed: () => _onPickFromGallery(context, viewModel),
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            color: whiteColor,
                            size: 28,
                          ),
                        ),
                        const Text(
                          'GALERIA',
                          style: TextStyle(
                            color: whiteColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFlashIcon(FlashMode flashMode) {
    switch (flashMode) {
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.torch:
        return Icons.highlight;
      case FlashMode.off:
        return Icons.flash_off;
    }
  }

  Future<void> _onCapture(BuildContext context, ScannerViewModel viewModel) async {
    try {
      final picture = await viewModel.capture();
      if (picture != null && context.mounted) {
        Navigator.of(context).pushNamed(
          AppRoutes.processing,
          arguments: ProcessingArgs(imagePath: picture.path),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao capturar: $e')),
        );
      }
    }
  }

  Future<void> _onPickFromGallery(BuildContext context, ScannerViewModel viewModel) async {
    final picked = await viewModel.pickFromGallery();
    if (picked != null && context.mounted) {
      Navigator.of(context).pushNamed(
        AppRoutes.processing,
        arguments: ProcessingArgs(imagePath: picked.path),
      );
    }
  }
}
