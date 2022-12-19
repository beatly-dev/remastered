// ignore_for_file: unused_field, unnecessary_getters_setters, no_leading_underscores_for_local_identifiers

library remastered_foundation;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';

mixin _RemasteredElementBase on Element {
  bool activated = false;

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
    super.deactivateChild(child);
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
  static var _currentLocalReactableIndex = 0;
  static var _currentDisposableIndex = 0;
  static var _currentCancelableIndex = 0;
  static RemasteredState? _currentState;

  final _globalReactables = <Reactable>[];
  final _localReactables = <Reactable>[];
  final _disposables = <OnDispose>[];
  final _cancelables = <OnDispose>[];
  var _isFirstBuild = true;

  @mustCallSuper
  @override
  void dispose() {
    for (final element in _disposables) {
      element._onDispose?.call();
      element.value._onCleanup();
    }
    _disposables.clear();

    for (final element in _cancelables) {
      element._onDispose?.call();
      element.value.cancel();
    }
    _cancelables.clear();

    for (final element in _globalReactables) {
      element._elements.remove(context as Element);
      element._dispose();
    }
    _globalReactables.clear();

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
    final previousReactableIndex = _currentLocalReactableIndex;
    final previousDisposableIndex = _currentDisposableIndex;
    final previousCancelableIndex = _currentCancelableIndex;
    final previousState = _currentState;

    _currentLocalReactableIndex = 0;
    _currentDisposableIndex = 0;
    _currentCancelableIndex = 0;
    _currentState = this;

    final result = callback();

    _currentLocalReactableIndex = previousReactableIndex;
    _currentDisposableIndex = previousDisposableIndex;
    _currentCancelableIndex = previousCancelableIndex;
    _currentState = previousState;

    _isFirstBuild = false;

    return result;
  }
}

class OnDispose<T> {
  OnDispose(this.value, {void Function()? onDispose}) : _onDispose = onDispose;

  T value;

  final void Function()? _onDispose;
}

typedef RV<T> = ReactableValue<T>;

abstract class Reactable<InnerType, WrappedType> extends Stream<InnerType> {
  Reactable(this._builder);

  final WrappedType Function() _builder;

  bool _initialized = false;
  bool _dirty = false;

  final _elements = HashSet<Element>();

  final _depended = HashSet<Reactable>();

  static Reactable? _currentReactable;

  WrappedType? _value;

  WrappedType get value {
    final previousReactable = _currentReactable;
    _currentReactable = this;
    _rebuildIfDirty();
    _currentReactable = previousReactable;
    _checkInitialized();

    final currentContext = RemasteredState._currentState?.context;

    if (currentContext != null && !_elements.contains(currentContext)) {
      RemasteredState._currentState!._globalReactables.add(this);
      _elements.add(currentContext as Element);
    }

    if (previousReactable != null && !_depended.contains(previousReactable)) {
      _depended.add(previousReactable);
    }

    return _value as WrappedType;
  }

  void _rebuildIfDirty() {
    if (!_initialized || _dirty) {
      final rebuilt = _builder();
      _value = _onRebuildValue(rebuilt);
      _dirty = false;
    }
  }

  void _checkInitialized() {
    if (!_initialized) {
      _onInit();
      _initialized = true;
    }
  }

  void _onInit();

  WrappedType _onRebuildValue(WrappedType newValue);

  set value(WrappedType newValue) {
    if (_value == newValue) return;
    _value = newValue;
    for (final element in _elements) {
      element.markNeedsBuild();
    }
    _markChildrenNeedRebuild();
    _onSetValue(newValue);
  }

  void _markChildrenNeedRebuild() {
    if (_dirty) return;
    for (final child in _depended) {
      child._dirty = true;
      child._markChildrenNeedRebuild();
    }
  }

  void _onSetValue(WrappedType newValue);

  void _dispose() {
    if (_elements.isEmpty) {
      _depended.clear();
      _onCleanup();
      _value = null;
      _initialized = false;
    }
  }

  void _onCleanup();

  @override
  String toString() => value.toString();
}

class ReactableValue<T> extends Reactable<T, T> {
  ReactableValue(
    T Function() _builder, {
    this.onFirstBuild,
    this.onDispose,
  }) : super(
          _builder,
        );

  final void Function(T firstValue)? onFirstBuild;
  final void Function(T lastValue)? onDispose;

  final _streamController = StreamController<T>.broadcast();

  Stream<T> get _stream => _streamController.stream;

  @override
  void _onInit() {
    onFirstBuild?.call(_value as T);
  }

  @override
  T _onRebuildValue(T newValue) {
    // Emit value on next cycle to prevent empty listener
    Future.delayed(Duration.zero, () async {
      _streamController.add(
        newValue,
      );
    });
    return newValue;
  }

  @override
  void _onSetValue(T newValue) {
    _streamController.add(newValue);
  }

  @override
  void _onCleanup() {
    onDispose?.call(_value as T);
    _streamController.close();
  }

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class ReactableFuture<T, F extends Future<T>> extends Reactable<T, F> {
  ReactableFuture(
    F Function() _builder, {
    this.onFirstBuild,
    this.onDispose,
  }) : super(
          _builder,
        );

  final void Function(T)? onFirstBuild;
  final void Function(T)? onDispose;

  final _streamController = StreamController<T>.broadcast();
  Stream<T> get _stream => _streamController.stream;

  T? _lastValue;

  @override
  F _onRebuildValue(F newValue) {
    newValue.then((event) {
      _lastValue = event;
      _streamController.add(event);
    });
    return newValue;
  }

  @override
  void _onInit() {
    _value!.then((value) => onFirstBuild?.call(value));
  }

  @override
  void _onSetValue(F newValue) {
    newValue.then((event) {
      _streamController.add(event);
      _lastValue = event;
    });
  }

  @override
  void _onCleanup() {
    if (_lastValue != null) {
      onDispose?.call(_lastValue as T);
    }
  }

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class ReactableStream<T, S extends Stream<T>> extends Reactable<T, S> {
  ReactableStream(
    S Function() _builder, {
    this.onFirstBuild,
    this.onDispose,
  }) : super(
          _builder,
        );

  final void Function(T)? onFirstBuild;
  final void Function(T)? onDispose;

  T? _lastValue;
  S? _stream;

  @override
  S _onRebuildValue(S newValue) {
    _stream = (newValue.asBroadcastStream() as S);
    _stream?.listen((event) {
      _lastValue = event;
    });
    return _stream as S;
  }

  @override
  void _onInit() {
    _stream?.first.then((value) => onFirstBuild?.call(value));
  }

  @override
  void _onSetValue(S newValue) {
    _stream = (newValue.asBroadcastStream() as S);
    _stream?.listen((event) {
      _lastValue = event;
    });
    _value = _stream;
  }

  @override
  void _onCleanup() {
    if (_lastValue != null) {
      onDispose?.call(_lastValue as T);
    }
  }

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return value.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

ReactableValue<T> reactable<T>(
  T Function() valueBuilder, {
  void Function(T lastValue)? onDispose,
  void Function(T firstValue)? onFirstBuild,
}) {
  reactableBuilder() {
    return ReactableValue<T>(
      valueBuilder,
      onDispose: onDispose,
      onFirstBuild: onFirstBuild,
    );
  }

  return _createReactable(reactableBuilder) as ReactableValue<T>;
}

ReactableFuture<T, Future<T>> reactableFuture<T>(
  Future<T> Function() valueBuilder, {
  void Function(T lastValue)? onDispose,
  void Function(T firstValue)? onFirstBuild,
}) {
  reactableBuilder() {
    return ReactableFuture<T, Future<T>>(
      valueBuilder,
      onDispose: onDispose,
      onFirstBuild: onFirstBuild,
    );
  }

  return _createReactable(reactableBuilder) as ReactableFuture<T, Future<T>>;
}

ReactableStream<T, Stream<T>> reactableStream<T>(
  Stream<T> Function() valueBuilder, {
  void Function(T lastValue)? onDispose,
  void Function(T firstValue)? onFirstBuild,
}) {
  reactableBuilder() {
    return ReactableStream<T, Stream<T>>(
      valueBuilder,
      onDispose: onDispose,
      onFirstBuild: onFirstBuild,
    );
  }

  return _createReactable(reactableBuilder) as ReactableStream<T, Stream<T>>;
}

Reactable _createReactable(
  Reactable Function() builder,
) {
  if (RemasteredState._currentState != null) {
    return _localReactableValue(builder);
  }
  return builder();
}

Reactable _localReactableValue(
  Reactable Function() builder,
) {
  final currentReactables = RemasteredState._currentState!._localReactables;
  if (RemasteredState._currentState!._isFirstBuild ||
      RemasteredState._currentState!._localReactables.length <=
          RemasteredState._currentLocalReactableIndex) {
    final reactable = builder();
    currentReactables.add(reactable);
  }
  return currentReactables[RemasteredState._currentLocalReactableIndex++];
}

T disposable<T>(
  T Function() builder, {
  void Function(T firstValue)? onFirstBuild,
  void Function(T lastValue)? onDispose,
}) {
  final currentDisposables = RemasteredState._currentState!._disposables;
  if (!RemasteredState._currentState!._isFirstBuild &&
      RemasteredState._currentDisposableIndex < currentDisposables.length) {
    return currentDisposables[RemasteredState._currentDisposableIndex++].value;
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
  currentDisposables.add(value);
  onFirstBuild?.call(initialValue);
  return initialValue;
}

T cancelable<T>(
  T Function() builder, {
  void Function(T firstValue)? onFirstBuild,
  void Function(T lastValue)? onDispose,
}) {
  final currentCancelables = RemasteredState._currentState!._cancelables;
  if (!RemasteredState._currentState!._isFirstBuild &&
      RemasteredState._currentCancelableIndex < currentCancelables.length) {
    return currentCancelables[RemasteredState._currentCancelableIndex++].value;
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
  currentCancelables.add(value);
  onFirstBuild?.call(initialValue);
  return initialValue;
}
