import '../../remastered.dart';

class RemasteredContainer {
  RemasteredContainer({
    List<ScopedReactable> overrides = const [],
    this.resetAll = false,
  }) {
    this.overrides = Map<String, Reactable>.fromIterable(
      overrides,
      key: (rx) => rx.key,
    );
  }

  static RemasteredContainer? directContainer;

  RemasteredContainer? parent;

  final bool resetAll;
  late final Map<String, Reactable> overrides;

  Reactable? find(Reactable origin) {
    if (resetAll) {
      return overrides[origin.key] ??= origin.clone();
    }

    final scoped = overrides[origin.key];

    if (scoped != null) {
      return scoped;
    }

    return parent?.find(origin);
  }
}

class ScopedReactable {
  const ScopedReactable(this.origin, this.scoped);

  final Reactable origin;
  final Reactable scoped;

  String get originKey => origin.key;
}
