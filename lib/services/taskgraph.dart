import 'dart:async';

class Task {
	final String name;
	final Future<void> Function() _func;
	final List<Task> dependencies;
	Task(this.name, this._func, [this.dependencies = const []]);
	Future<void> execute() async {
		final start = DateTime.now();
		try {
			await _func();
		}
		finally {
			print('[$name]: ${DateTime.now().difference(start)}');
		}
	}
	@override
	String toString() => 'Task(name: $name, dependencies: $dependencies)';
}

bool _kSlow = false;

/// Assume no exceptions
Future<void> executeTaskGraph(List<Task> tasks) async {
	final notStarted = <Task>{};
	// Discover all tasks by walking
	void descend(List<Task> tasks) {
		for (final task in tasks) {
			descend(task.dependencies);
			notStarted.add(task);
		}
	}
	descend(tasks);
	final started = <Task, Future<Task>>{};
	final finished = <Task>{};
	void startTasks() {
		if (notStarted.isEmpty) {
			return;
		}
		for (final task in _kSlow ? [notStarted.first] : notStarted.toList()) {
			if (task.dependencies.every(finished.contains)) {
				print('Starting $task because $finished');
				notStarted.remove(task);
				final future = task.execute().then((_) => task);
				started[task] = future;
			}
		}
	}
	startTasks();
	while (started.isNotEmpty) {
		// Wake up when next task is done
		final task = await Future.any(started.values);
		started.remove(task);
		finished.add(task);
		startTasks();
	}
	if (notStarted.isNotEmpty) {
		throw Exception('Task graph mistake, there were still $notStarted');
	}
}
