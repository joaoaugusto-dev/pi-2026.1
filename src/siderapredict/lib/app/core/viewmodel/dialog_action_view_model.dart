import 'package:flutter/material.dart';

class DialogActionViewModel {
  const DialogActionViewModel();

  VoidCallback closeAction(BuildContext context) {
    return () => Navigator.of(context).pop();
  }

  VoidCallback confirmAction(BuildContext context, VoidCallback? onConfirm) {
    return () {
      Navigator.of(context).pop();
      onConfirm?.call();
    };
  }

  VoidCallback emptyAction() {
    return () {};
  }
}
