import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/services/azure_layout_client.dart';

import 'azure_nutrition_layout_test.dart' show layoutFixture;

class _Headers extends Fake implements HttpHeaders {
  @override
  ContentType? contentType;
}

class _Request extends Fake implements HttpClientRequest {
  final HttpClientResponse response;
  final uploaded = <int>[];
  _Request(this.response);
  @override
  final HttpHeaders headers = _Headers();
  @override
  bool followRedirects = true;
  @override
  int contentLength = -1;
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final bytes in stream) {
      uploaded.addAll(bytes);
    }
  }

  @override
  Future<HttpClientResponse> close() async => response;
}

class _Response extends StreamView<List<int>> implements HttpClientResponse {
  @override
  final int statusCode;
  _Response(this.statusCode, String body)
    : super(Stream.value(utf8.encode(body)));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client extends Fake implements HttpClient {
  final _Request request;
  Uri? url;
  bool closed = false;
  _Client(this.request);
  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    this.url = url;
    return request;
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }
}

void main() {
  late Directory directory;
  late File image;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('azure-client-test');
    image = await File('${directory.path}/photo.jpg').writeAsBytes([1, 2, 3]);
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'uploads photo to backend and maps Azure result, closing the connection',
    () async {
      final request = _Request(
        _Response(
          200,
          jsonEncode({
            'provider': 'azure-layout',
            'analyzeResult': layoutFixture(),
          }),
        ),
      );
      final client = _Client(request);
      final data = await AzureLayoutClient(
        baseUrl: 'https://nutripal.example/',
        clientFactory: () => client,
      ).analyze(image.path);
      expect(
        client.url.toString(),
        'https://nutripal.example/api/v1/nutrition/analyze',
      );
      expect(request.uploaded, [1, 2, 3]);
      expect(request.contentLength, 3);
      expect(request.followRedirects, isFalse);
      expect(request.headers.contentType!.mimeType, 'application/octet-stream');
      expect(data.perServing!.proteinG, 3);
      expect(client.closed, isTrue);
    },
  );

  test(
    'server failures are clear and do not leak upstream error bodies',
    () async {
      for (final status in [413, 415, 503, 504, 500]) {
        final client = _Client(
          _Request(_Response(status, 'private error detail')),
        );
        await expectLater(
          AzureLayoutClient(
            baseUrl: 'https://nutripal.example',
            clientFactory: () => client,
          ).analyze(image.path),
          throwsA(
            isA<NutritionScanException>().having(
              (e) => e.message,
              'safe message',
              isNot(contains('private error detail')),
            ),
          ),
        );
        expect(client.closed, isTrue);
      }
    },
  );

  test(
    'rejects a malformed successful result and closes the connection',
    () async {
      final client = _Client(_Request(_Response(200, '{}')));
      await expectLater(
        AzureLayoutClient(
          baseUrl: 'https://nutripal.example',
          clientFactory: () => client,
        ).analyze(image.path),
        throwsA(isA<NutritionScanException>()),
      );
      expect(client.closed, isTrue);
    },
  );
}
