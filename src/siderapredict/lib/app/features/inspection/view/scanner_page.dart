import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:siderapredict/app/core/theme/app_theme.dart';
import 'package:siderapredict/app/features/inspection/view/camera_alignment_overlay.dart';
import 'package:siderapredict/app/features/inspection/viewmodel/scanner_view_model.dart';

class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ScannerViewModel>();
    final theme = Theme.of(context);
    final isHighContrast = theme.brightness == Brightness.light
        ? theme.primaryColor == Colors.black
        : theme.primaryColor == Colors.yellow;

    if (viewModel.cameras.isEmpty) {
      return Scaffold(
        appBar: buildAppBar(context: context, title: 'Câmera'),
        body: Center(
          child: Text(
            'Nenhuma câmera encontrada neste dispositivo.',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: buildAppBar(
        context: context,
        title: 'Inspeção Digital',
        showBack: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: viewModel.closeAction(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child:
                viewModel.controller != null &&
                    viewModel.initializeControllerFuture != null
                ? FutureBuilder<void>(
                    future: viewModel.initializeControllerFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done &&
                          viewModel.isInitialized) {
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
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 16),
                            Text(
                              'INICIALIZANDO ÓPTICA...',
                              style: TextStyle(
                                color: Colors.white,
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
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
          ),

          CameraAlignmentOverlay(
            rollDegrees: viewModel.rollDegrees,
            pitchDegrees: viewModel.pitchDegrees,
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: isHighContrast
                    ? null
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                color: isHighContrast ? Colors.black : null,
                border: isHighContrast
                    ? const Border(
                        top: BorderSide(color: Colors.white, width: 2),
                      )
                    : null,
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
                            viewModel.flashIcon,
                            color: isHighContrast
                                ? (theme.brightness == Brightness.dark
                                      ? Colors.yellow
                                      : Colors.white)
                                : Colors.white,
                            size: 32,
                          ),
                        ),
                        Text(
                          'FLASH',
                          style: TextStyle(
                            color: isHighContrast
                                ? (theme.brightness == Brightness.dark
                                      ? Colors.yellow
                                      : Colors.white)
                                : Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  GestureDetector(
                    onTap: viewModel.captureAction(context),
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isHighContrast
                              ? (theme.brightness == Brightness.dark
                                    ? Colors.yellow
                                    : Colors.white)
                              : Colors.white,
                          width: 4,
                        ),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: viewModel.isCapturing
                              ? paletteRed
                              : (isHighContrast
                                    ? (theme.brightness == Brightness.dark
                                          ? Colors.yellow
                                          : Colors.white)
                                    : Colors.white),
                        ),
                        child: viewModel.isCapturing
                            ? Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: isHighContrast
                                        ? Colors.black
                                        : Colors.white,
                                    strokeWidth: 3,
                                  ),
                                ),
                              )
                            : null,
                      ),
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
}
