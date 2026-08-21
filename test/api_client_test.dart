import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:apexbooks/core/network/api_client.dart';

void main() {
  test('ApiClient normalizes a trailing slash from base URL', () {
    final client = ApiClient(baseUrl: 'https://example.test/api/v1/');
    expect(client.baseUrl, 'https://example.test/api/v1');
  });

  test('ApiException includes support id when present', () {
    final error = ApiException('Request failed', supportId: 'abc-123');
    expect(error.toString(), contains('Support ID: abc-123'));
  });

  test('clear removes session-scoped credentials', () {
    final client = ApiClient(baseUrl: 'https://example.test/api/v1')
      ..configure(accessToken: 'a', refreshToken: 'r', tenantId: 't');
    client.clear();
    expect(client.accessToken, isNull);
    expect(client.refreshToken, isNull);
    expect(client.tenantId, isNull);
  });

  test(
    'binary download retries once after token refresh on HTTP 401',
    () async {
      var calls = 0;
      final mock = MockClient((request) async {
        calls += 1;
        if (request.url.path.endsWith('/auth/refresh')) {
          return http.Response(
            '{"access_token":"new-a","refresh_token":"new-r"}',
            200,
          );
        }
        if (request.headers['Authorization'] == 'Bearer new-a') {
          return http.Response.bytes([1, 2, 3, 4], 200);
        }
        return http.Response('{"detail":"expired"}', 401);
      });
      final client = ApiClient(
        baseUrl: 'https://example.test/api/v1',
        httpClient: mock,
      )..configure(accessToken: 'old-a', refreshToken: 'old-r', tenantId: 't');
      final bytes = await client.download('/invoices/1/print');
      expect(bytes, [1, 2, 3, 4]);
      expect(calls, 3);
      expect(client.accessToken, 'new-a');
    },
  );
}
