import 'package:flutter/widgets.dart';

import 'container.dart';

class RemasteredProvider extends StatelessWidget {
  RemasteredProvider({
    required this.child,
    this.overrides = const [],
    this.resetAll = false,
    super.key,
  }) : container = RemasteredContainer(
          overrides: overrides,
          resetAll: resetAll,
        );

  final List<ScopedReactable> overrides;
  final bool resetAll;
  final Widget child;
  final RemasteredContainer container;

  static RemasteredContainer? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_RemasteredContainerProvider>()
        ?.provider
        .container;
  }

  @override
  Widget build(BuildContext context) {
    print('Rebuild $hashCode');
    return _RemasteredContainerProvider(
      overrides: overrides,
      resetAll: resetAll,
      provider: this,
      child: child,
    );
  }
}

class _RemasteredContainerProvider extends InheritedWidget {
  const _RemasteredContainerProvider({
    required super.child,
    required this.provider,
    List<ScopedReactable> overrides = const [],
    bool resetAll = false,
  });

  final RemasteredProvider provider;

  @override
  bool updateShouldNotify(_RemasteredContainerProvider oldWidget) {
    final shouldNotify = !identical(oldWidget.provider, provider);
    return shouldNotify;
  }
}
