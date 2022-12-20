import 'package:flutter/material.dart';
import 'package:remastered/remastered.dart';
import 'package:rxdart/rxdart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends RemasteredWidget {
  const MyApp({super.key});

  @override
  Widget emit(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(
        key: ValueKey('mypage'),
        title: 'Flutter Demo Home Page',
      ),
    );
  }
}

final counter = reactable(() => 0);

final delayedCounter = reactableStream(() {
  return counter.debounceTime(const Duration(seconds: 1));
});

class MyHomePage extends RemasteredWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  void beforeFirstBuild() {}

  @override
  void afterFirstBuild(BuildContext context) {
    print("after first build $counter");
  }

  @override
  void beforeRebuild(BuildContext context) {
    print("before rebuild $counter");
  }

  @override
  void afterRebuild(BuildContext context) {
    print("after rebuild $counter");
  }

  @override
  void afterChangeDependencies(BuildContext context) {
    print("after  change deps $counter");
  }

  @override
  void beforeDispose(BuildContext context) {
    print("before dispose $counter");
  }

  @override
  Widget emit(BuildContext context) {
    final localCounter = cached(() => reactable(() => 0));
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              'local $localCounter',
              style: Theme.of(context).textTheme.headline4,
            ),
            TextButton(
              onPressed: () {
                localCounter.value++;
              },
              child: const Text("Add local counter one"),
            ),
            Text(
              'simple $counter',
              style: Theme.of(context).textTheme.headline4,
            ),
            Text(
              'nested $nested',
              style: Theme.of(context).textTheme.headline4,
            ),
            const DebouncedCounter(),
            const AsyncCounter(),
            Expanded(
              child: RemasteredProvider(
                resetAll: true,
                child: RemasteredConsumer(
                  builder: (context) {
                    final scoped = counter.of(context);
                    return Column(
                      children: [
                        Text('overriden $scoped'),
                        TextButton(
                            onPressed: () {
                              scoped.value++;
                            },
                            child: const Text("Add one")),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          counter.value++;
        },
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class ScopedCounter extends RemasteredWidget {
  const ScopedCounter({super.key});

  @override
  Widget emit(BuildContext context) {
    return Column(
      children: [
        Text('overriden $counter'),
        TextButton(
            onPressed: () {
              final cc = counter.of(context);
              cc.value++;
            },
            child: const Text("Add one")),
      ],
    );
  }
}

final doubled = reactable(
  () => counter.value * 2,
);

final nested = reactable(() => counter.value + doubled.value);

class DebouncedCounter extends RemasteredWidget {
  const DebouncedCounter({super.key});

  @override
  Stream<Widget> emit(BuildContext context) async* {
    await for (final count in debounced) {
      yield Text('Debounced $count');
    }
  }

  @override
  Widget onLoading(BuildContext context) {
    return const Text("Loading...");
  }
}

class AsyncCounter extends RemasteredWidget {
  const AsyncCounter({super.key});

  @override
  Stream<Widget> emit(BuildContext context) async* {
    await for (final count in rebounced) {
      yield Text('Async $count');
    }
  }

  @override
  Widget onLoading(BuildContext context) {
    return const Text("Loading...");
  }
}

Future<int> asdf() async {
  return 0;
}

final debounced = reactableStream(
  () => counter.debounceTime(const Duration(seconds: 1)),
);

final rebounced = reactableStream(() => debounced.map((value) {
      return value * 3;
    }));

final pureStream = reactable(() async* {
  for (int i = 0; i < 1000; ++i) {
    await Future.delayed(const Duration(seconds: 1));
    yield i;
  }
});
