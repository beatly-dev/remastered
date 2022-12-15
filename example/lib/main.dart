import 'package:flutter/material.dart';
import 'package:remastered/remastered.dart';
import 'package:rxdart/rxdart.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends RemasteredWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends RemasteredWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
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
              '$counter',
              style: Theme.of(context).textTheme.headline4,
            ),
            Text(
              'doubled $doubled',
              style: Theme.of(context).textTheme.headline4,
            ),
            const DebouncedCounter(),
            const AsyncCounter(),
            const FutureCounter(),
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

final counter = reactable(
  () => 0,
);

final doubled = reactable(
  () => counter.value * 2,
);

class DebouncedCounter extends RemasteredWidget {
  const DebouncedCounter({super.key});

  @override
  Stream<Widget> emit(BuildContext context) async* {
    await for (final count in debounced.value) {
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
    final countStream = counter.debounceTime(
      const Duration(seconds: 3),
    );
    await for (final count in countStream) {
      yield Text('Async $count');
    }
  }

  @override
  Widget onLoading(BuildContext context) {
    return const Text("Loading...");
  }
}

final debounced = reactable(
  () => counter.debounceTime(const Duration(seconds: 1)),
);

final pureFuture = reactable(() async {
  final count = counter.value;
  return count * 3;
});

class FutureCounter extends RemasteredWidget {
  const FutureCounter({super.key});

  @override
  Future<Widget> build(BuildContext context) async {
    final count = await pureFuture.value;
    return Text('Future $count');
  }
}
