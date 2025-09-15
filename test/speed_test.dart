import 'package:chan/services/http_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> speedTest({
	required List<List<String>> tasks,
	required String name,
	required Dio client
}) async {
	final start = DateTime.now();
	for (final task in tasks) {
		await Future.wait(task.map((u) async {
			await client.get(u, options: Options(responseType: ResponseType.bytes));
		}));
		print('[$name] After task: ${DateTime.now().difference(start)}');
	}
}

void main() {
	final client1 = Dio()..httpClientAdapter = MyHttpClientAdapter1();
	final client2 = Dio()..httpClientAdapter = MyHttpClientAdapter2();

	final urls = [
		'https://i.4cdn.org/hr/1746431336713935.jpg',
		'https://i.4cdn.org/hr/1746469146695686.jpg',
		'https://i.4cdn.org/hr/1746472582038656.jpg',
		'https://i.4cdn.org/hr/1746594716942145.jpg',
		'https://i.4cdn.org/hr/1746760731503837.jpg',
		'https://i.4cdn.org/hr/1747048997542805.jpg',
		'https://i.4cdn.org/hr/1748600615928976.png',
		'https://i.4cdn.org/hr/1749230516497780.jpg',
		'https://i.4cdn.org/hr/1749582477240462.jpg',
		'https://i.4cdn.org/hr/1749582701030161.jpg'
	];

	test('Test', () async {
		await speedTest(
			client: client1,
			name: 'v1 serial',
			tasks: urls.map((url) => [url]).toList()
		);

		await speedTest(
			client: client2,
			name: 'v2 serial',
			tasks: urls.map((url) => [url]).toList()
		);

		await speedTest(
			client: client1,
			name: 'v1 parallel',
			tasks: [urls]
		);

		await speedTest(
			client: client2,
			name: 'v2 parallel',
			tasks: [urls]
		);
	});
}