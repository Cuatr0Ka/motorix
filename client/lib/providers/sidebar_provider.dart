import 'package:flutter/foundation.dart';

import '../utils/tokens.dart';

/// Estado expandido/colapsado del sidebar. Se conserva al navegar.
/// Mientras la persona no lo cambie, arranca colapsado si la ventana es angosta (< ~1000 px).
class SidebarProvider extends ChangeNotifier {
  bool? _userChoice;

  bool isExpanded(double windowWidth) => _userChoice ?? windowWidth >= AppLayout.collapseBreakpoint;

  void toggle(double windowWidth) {
    _userChoice = !isExpanded(windowWidth);
    notifyListeners();
  }
}
