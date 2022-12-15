library remastered_foundation;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class RemasteredWidgetsFlutterBinding extends WidgetsFlutterBinding
    with RemasteredWidgetsBinding {
  static WidgetsBinding? _instance;
  static WidgetsBinding ensureInitialized() {
    _instance ??= RemasteredWidgetsFlutterBinding();
    return WidgetsBinding.instance;
  }
}

mixin RemasteredWidgetsBinding on WidgetsBinding {
  BuildOwner? _buildOwner;
  @override
  BuildOwner? get buildOwner => _buildOwner ?? super.buildOwner;

  @override
  void attachRootWidget(Widget rootWidget) {
    super.attachRootWidget(rootWidget);
  }

  static RemasteredWidgetsBinding get instance =>
      BindingBase.checkInstance(_instance);
  static RemasteredWidgetsBinding? _instance;
}
