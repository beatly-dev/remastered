import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../remastered.dart';
import 'container.dart';

class RemasteredProvider extends StatefulWidget {
  const RemasteredProvider({
    required this.child,
    this.overrides = const [],
    this.resetAll = false,
    super.key,
  });

  final List<ScopedReactable> overrides;
  final bool resetAll;
  final Widget child;

  static RemasteredContainer? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_RemasteredContainerProvider>()
        ?.state
        .container;
  }

  @override
  State<RemasteredProvider> createState() => _RemasteredProviderState();
}

class RemasteredConsumer extends RemasteredWidget {
  const RemasteredConsumer({
    required this.builder,
    super.key,
  });

  final Widget Function(BuildContext context) builder;

  @override
  Widget emit(BuildContext context) {
    return builder(context);
  }
}

class _RemasteredProviderState extends State<RemasteredProvider> {
  late final RemasteredContainer container;

  @override
  void initState() {
    super.initState();
    container = RemasteredContainer(
      overrides: widget.overrides,
      resetAll: widget.resetAll,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty(
        'resetAll',
        container.resetAll,
      ),
    );
    properties.add(
      IterableProperty(
        'overrides',
        container.overrides.keys.map((e) => '$e = ${container.overrides[e]}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _RemasteredContainerProvider(
      overrides: widget.overrides,
      resetAll: widget.resetAll,
      state: this,
      child: widget.child,
    );
  }
}

class _RemasteredContainerProvider extends InheritedWidget {
  const _RemasteredContainerProvider({
    required super.child,
    required this.state,
    List<ScopedReactable> overrides = const [],
    bool resetAll = false,
  });

  final _RemasteredProviderState state;

  @override
  bool updateShouldNotify(_RemasteredContainerProvider oldWidget) {
    final shouldNotify = !identical(oldWidget.state, state);
    return shouldNotify;
  }
}
