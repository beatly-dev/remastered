// ignore_for_file: unused_field, unnecessary_getters_setters, no_leading_underscores_for_local_identifiers

library remastered_foundation;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';

class RemasteredBuildOwner extends BuildOwner {
  RemasteredBuildOwner({super.onBuildScheduled, super.focusManager});

  final _inactiveElements = _RemasteredInactiveElements();

  final _dirtyElements = HashSet<_RemasteredElementBase>();

  @override
  void scheduleBuildFor(Element element) {
    print('scheduleBuildFor: ${element.widget.runtimeType}');
    super.scheduleBuildFor(element);
    if (element is _RemasteredElementBase) {
      _dirtyElements.add(element);
    }
  }

  @override
  void finalizeTree() {
    super.finalizeTree();
    print('Unmount all inactive elements');
    _inactiveElements._unmountAll();
  }

  @override
  void buildScope(Element context, [VoidCallback? callback]) {
    print('clear dirty element');
    super.buildScope(context, callback);
    _dirtyElements.clear();
  }
}

class _RemasteredInactiveElements {
  final _elements = HashSet<_RemasteredElementBase>();

  void _unmount(Element element) {
    element.visitChildren((Element child) {
      _unmount(child);
    });
    // TODO: dispose something
  }

  void _unmountAll() {
    final elements = _elements.toList()..sort(_RemasteredElementBase._sort);
    _elements.clear();
    try {
      elements.reversed.forEach(_unmount);
    } finally {
      assert(_elements.isEmpty);
    }
  }

  void add(covariant _RemasteredElementBase element) {
    _elements.add(element);
  }

  void remove(covariant _RemasteredElementBase element) {
    _elements.remove(element);
  }
}

mixin _RemasteredElementBase on Element {
  bool activated = false;

  static int _sort(Element a, Element b) {
    final int diff = a.depth - b.depth;
    // If depths are not equal, return the difference.
    if (diff != 0) {
      return diff;
    }
    // If the `dirty` values are not equal, sort with non-dirty elements being
    // less than dirty elements.
    final bool isBDirty = b.dirty;
    if (a.dirty != isBDirty) {
      return isBDirty ? -1 : 1;
    }
    // Otherwise, `depth`s and `dirty`s are equal.
    return 0;
  }

  RemasteredBuildOwner get remasteredOwner {
    if (owner is! RemasteredBuildOwner) {
      throw 'You should use [RemasteredWidgetsFlutterBinding]';
    }
    return owner as RemasteredBuildOwner;
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    activated = true;
  }

  @override
  void activate() {
    super.activate();
    activated = true;
  }

  @override
  void deactivate() {
    activated = false;
    super.deactivate();
  }

  @override
  void unmount() {
    activated = false;
    super.unmount();
  }

  @override
  void deactivateChild(Element child) {
    if (child is _RemasteredElementBase) {
      remasteredOwner._inactiveElements.add(child);
    }
    super.deactivateChild(child);
  }

  @override
  Element inflateWidget(Widget newWidget, Object? newSlot) {
    final Key? key = newWidget.key;
    final newChild = super.inflateWidget(newWidget, newSlot);
    if (key is GlobalKey &&
        key.currentContext == newChild &&
        newChild is _RemasteredElementBase) {
      remasteredOwner._inactiveElements.remove(newChild);
    }
    return newChild;
  }
}

class RemasteredElement extends StatefulElement with _RemasteredElementBase {
  RemasteredElement(super.widget);
}

abstract class RemasteredWidget extends StatefulWidget {
  const RemasteredWidget({super.key});

  @override
  StatefulElement createElement() => RemasteredElement(this);

  @override
  RemasteredState createState() => RemasteredState();

  FutureOr<Widget>? build(BuildContext context) => null;
  Stream<Widget>? emit(BuildContext context) => null;
  Widget onLoading(BuildContext context) => const SizedBox.shrink();
  Widget onError(BuildContext context, dynamic error) =>
      const SizedBox.shrink();
}

class RemasteredState extends State<RemasteredWidget> {
  static var _currentReactables = <Reactable>[];
  static var _currentLocalReactables = <Reactable>[];
  static var _currentDisposables = <OnDispose>[];
  static var _currentCancelables = <OnDispose>[];
  static var _currentLocalReactableIndex = 0;
  static var _currentDisposableIndex = 0;
  static var _currentCancelableIndex = 0;
  static var _currentIsFirstBuild = true;
  static BuildContext? _currentContext;

  final _reactables = <Reactable>[];
  final _localReactables = <Reactable>[];
  final _disposables = <OnDispose>[];
  final _cancelables = <OnDispose>[];
  var _isFirstBuild = true;

  @mustCallSuper
  @override
  void dispose() {
    for (final element in _disposables) {
      element._onDispose?.call();
      element.value.dispose();
    }
    _disposables.clear();

    for (final element in _cancelables) {
      element._onDispose?.call();
      element.value.cancel();
    }
    _cancelables.clear();

    for (final element in _reactables) {
      element._elements.remove(context as Element);
      element._dispose();
    }
    _reactables.clear();

    for (final element in _localReactables) {
      element._elements.remove(context as Element);
      element._dispose();
    }
    _localReactables.clear();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _lockState(() {
      final newWidgetFuture = widget.build(context);
      final newWidgetStream = widget.emit(context);

      assert(
        // ignore: unrelated_type_equality_checks
        newWidgetStream != newWidgetFuture,
        'You should override build or emit method',
      );

      if (newWidgetFuture is Widget) {
        return newWidgetFuture;
      }

      if (newWidgetFuture is Future) {
        return FutureBuilder(
          builder: (context, future) {
            if (future.hasData) {
              return future.data as Widget;
            }
            if (future.hasError) {
              return widget.onError(context, future.error);
            }
            return widget.onLoading(context);
          },
          future: newWidgetFuture,
        );
      }
      return StreamBuilder(
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return snapshot.data as Widget;
          }
          if (snapshot.hasError) {
            return widget.onError(context, snapshot.error);
          }
          return widget.onLoading(context);
        },
        stream: newWidgetStream as Stream<Widget>,
      );
    });
  }

  T _lockState<T>(T Function() callback) {
    final previousReactables = _currentReactables;
    final previousLocalReactables = _currentLocalReactables;
    final previousDisposables = _currentDisposables;
    final previousCancelables = _currentCancelables;
    final previousReactableIndex = _currentLocalReactableIndex;
    final previousDisposableIndex = _currentDisposableIndex;
    final previousCancelableIndex = _currentCancelableIndex;
    final previousIsFirstBuild = _currentIsFirstBuild;
    final previousContext = _currentContext;

    _currentReactables = _reactables;
    _currentLocalReactables = _localReactables;
    _currentDisposables = _disposables;
    _currentCancelables = _cancelables;
    _currentLocalReactableIndex = 0;
    _currentDisposableIndex = 0;
    _currentCancelableIndex = 0;
    _currentIsFirstBuild = _isFirstBuild;
    _currentContext = context;

    final result = callback();

    _currentReactables = previousReactables;
    _currentLocalReactables = previousLocalReactables;
    _currentDisposables = previousDisposables;
    _currentCancelables = previousCancelables;
    _currentLocalReactableIndex = previousReactableIndex;
    _currentDisposableIndex = previousDisposableIndex;
    _currentCancelableIndex = previousCancelableIndex;
    _currentIsFirstBuild = previousIsFirstBuild;
    _currentContext = previousContext;

    _isFirstBuild = false;

    return result;
  }
}

// Easily separate controller

typedef RV<T> = Reactable<T>;

class OnDispose<T> {
  OnDispose(this.value, {void Function()? onDispose}) : _onDispose = onDispose;

  T value;

  final void Function()? _onDispose;
}

class Reactable<T> extends Stream<T> {
  Reactable(
    this._builder, {
    void Function(T)? onFirstBuild,
    void Function(T)? onDispose,
  })  : _onDispose = onDispose,
        _onFirstBuild = onFirstBuild;

  final T Function() _builder;
  final void Function(T firstValue)? _onFirstBuild;
  final void Function(T lastValue)? _onDispose;
  final _streamController = StreamController<T>.broadcast();

  Stream<T> get _stream => _streamController.stream;

  bool _initialized = false;
  bool _dirty = false;

  final _elements = HashSet<Element>();

  final _depended = HashSet<Reactable>();

  static Reactable? _currentReactable;

  T? _value;

  T get value {
    final previousReactable = _currentReactable;
    if (!_initialized || _dirty) {
      _currentReactable = this;
      _value = _builder();

      if (_value is Stream) {
        _value = (_value as Stream).asBroadcastStream() as T;
      }

      // Emit value on next cycle to prevent empty listener
      Future.delayed(Duration.zero, () => _streamController.add(_value as T));
      _currentReactable = previousReactable;

      _dirty = false;
    }

    if (!_initialized) {
      _onFirstBuild?.call(_value as T);
      _initialized = true;
    }

    final currentContext = RemasteredState._currentContext;

    if (currentContext != null && !_elements.contains(currentContext)) {
      RemasteredState._currentReactables.add(this);
      _elements.add(currentContext as Element);
    }

    if (previousReactable != null && !_depended.contains(previousReactable)) {
      _depended.add(previousReactable);
    }
    return _value as T;
  }

  void _markChildrenNeedRebuild() {
    if (_dirty) return;
    for (final child in _depended) {
      child._dirty = true;
      child._markChildrenNeedRebuild();
    }
  }

  set value(T newValue) {
    _value = newValue;
    _streamController.add(newValue);
    for (final element in _elements) {
      element.markNeedsBuild();
    }
    _markChildrenNeedRebuild();
  }

  void _dispose() {
    if (_elements.isEmpty) {
      _depended.clear();
      _streamController.close();
      _onDispose?.call(value);
      _value = null;
      _initialized = false;
    }
  }

  @override
  String toString() => value.toString();

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    assert(
      _value is! Stream,
      'You should use [.value] field to listen to stream on stream reactable',
    );
    return _stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

Reactable<T> reactable<T>(
  T Function() builder, {
  void Function(T lastValue)? onDispose,
  void Function(T firstValue)? onFirstBuild,
}) {
  if (RemasteredState._currentContext != null) {
    return _localReactable(
      builder,
      onDispose: onDispose,
      onFirstBuild: onFirstBuild,
    );
  }
  return Reactable(
    builder,
    onDispose: onDispose,
    onFirstBuild: onFirstBuild,
  );
}

Reactable<T> _localReactable<T>(
  T Function() builder, {
  void Function(T lastValue)? onDispose,
  void Function(T firstValue)? onFirstBuild,
}) {
  if (RemasteredState._currentIsFirstBuild) {
    final reactable = Reactable(
      builder,
      onDispose: onDispose,
      onFirstBuild: onFirstBuild,
    );
    RemasteredState._currentLocalReactables.add(reactable);
  }
  return RemasteredState._currentLocalReactables[
      RemasteredState._currentLocalReactableIndex++] as Reactable<T>;
}

T disposable<T>(
  T Function() builder, {
  void Function(T firstValue)? onFirstBuild,
  void Function(T lastValue)? onDispose,
}) {
  if (!RemasteredState._currentIsFirstBuild &&
      RemasteredState._currentDisposableIndex <
          RemasteredState._currentDisposables.length) {
    return RemasteredState
        ._currentDisposables[RemasteredState._currentDisposableIndex++].value;
  }
  final initialValue = builder();
  try {
    (initialValue as dynamic).dispose;
  } catch (e) {
    throw Exception(
      'The value passed to disposable must have a dispose method',
    );
  }
  final value = OnDispose(
    initialValue,
    onDispose: () => onDispose?.call(initialValue),
  );
  RemasteredState._currentDisposables.add(value);
  onFirstBuild?.call(initialValue);
  return initialValue;
}

T cancelable<T>(
  T Function() builder, {
  void Function(T firstValue)? onFirstBuild,
  void Function(T lastValue)? onDispose,
}) {
  if (!RemasteredState._currentIsFirstBuild &&
      RemasteredState._currentCancelableIndex <
          RemasteredState._currentCancelables.length) {
    return RemasteredState
        ._currentCancelables[RemasteredState._currentCancelableIndex++].value;
  }
  final initialValue = builder();
  try {
    (initialValue as dynamic).cancel;
  } catch (e) {
    throw Exception(
      'The value passed to cancelable must have a cancel method',
    );
  }
  final value = OnDispose(
    initialValue,
    onDispose: () => onDispose?.call(initialValue),
  );
  RemasteredState._currentCancelables.add(value);
  onFirstBuild?.call(initialValue);
  return initialValue;
}
