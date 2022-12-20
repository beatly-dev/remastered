import '../../remastered.dart';

class RemasteredContainer {
  RemasteredContainer({
    List<ScopedReactable> overrides = const [],
    this.resetAll = false,
  }) {
    this.overrides = {
      for (final rx in overrides) rx.originKey: rx.scoped..scoped = true,
    };
  }

  static RemasteredContainer? directContainer;

  RemasteredContainer? parent;

  final bool resetAll;
  late final Map<String, RxBase> overrides;

  RxBase? find(RxBase origin) {
    if (resetAll) {
      return overrides[origin.key] ??= origin.clone()..scoped = true;
    }

    final scoped = overrides[origin.key];

    return scoped ?? parent?.find(origin);
  }
}

class ScopedReactable {
  const ScopedReactable(this.origin, this.scoped);

  final RxBase origin;
  final RxBase scoped;

  String get originKey => origin.key;
}
