import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code, this.supportId});
  final String message;
  final int? statusCode;
  final String? code;
  final String? supportId;

  @override
  String toString() =>
      supportId == null ? message : '$message (Support ID: $supportId)';
}

class ApiClient {
  ApiClient({String? baseUrl, http.Client? httpClient})
      : baseUrl = (baseUrl ??
                const String.fromEnvironment(
                  'API_BASE_URL',
                  defaultValue: 'http://127.0.0.1:8000/api/v1',
                ))
            .replaceAll(RegExp(r'/$'), ''),
        _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;
  String? accessToken;
  String? refreshToken;
  String? tenantId;
  Future<void> Function(String accessToken, String refreshToken)?
      onTokenRotation;

  void configure(
      {String? accessToken, String? refreshToken, String? tenantId}) {
    if (accessToken != null) this.accessToken = accessToken;
    if (refreshToken != null) this.refreshToken = refreshToken;
    this.tenantId = tenantId;
  }

  void clear() {
    accessToken = null;
    refreshToken = null;
    tenantId = null;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final base = Uri.parse('$baseUrl$normalized');
    if (query == null || query.isEmpty) return base;
    return base.replace(
      queryParameters:
          query.map((key, value) => MapEntry(key, value?.toString() ?? '')),
    );
  }

  Map<String, String> _headers({
    bool json = true,
    bool tenant = true,
    String? idempotencyKey,
  }) {
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      if (tenant && tenantId != null) 'X-Tenant-ID': tenantId!,
      if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
    };
  }

  String _newIdempotencyKey() {
    final random = Random.secure();
    final nonce = List.generate(
            16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    return 'flutter-${DateTime.now().microsecondsSinceEpoch}-$nonce';
  }

  bool _isMutation(String method) =>
      const {'POST', 'PUT', 'PATCH', 'DELETE'}.contains(method);

  Future<dynamic> get(String path,
          {Map<String, dynamic>? query, bool tenant = true}) =>
      _request('GET', path, query: query, tenant: tenant);

  Future<dynamic> post(String path,
          {Object? body, Map<String, dynamic>? query, bool tenant = true}) =>
      _request('POST', path, body: body, query: query, tenant: tenant);

  Future<dynamic> put(String path,
          {Object? body, Map<String, dynamic>? query, bool tenant = true}) =>
      _request('PUT', path, body: body, query: query, tenant: tenant);

  Future<dynamic> patch(String path,
          {Object? body, Map<String, dynamic>? query, bool tenant = true}) =>
      _request('PATCH', path, body: body, query: query, tenant: tenant);

  Future<dynamic> delete(String path,
          {Object? body, Map<String, dynamic>? query, bool tenant = true}) =>
      _request('DELETE', path, body: body, query: query, tenant: tenant);

  Future<dynamic> _request(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool tenant = true,
    bool allowRefresh = true,
    String? idempotencyKey,
  }) async {
    final mutationKey = idempotencyKey ??
        (_isMutation(method) && tenant && tenantId != null
            ? _newIdempotencyKey()
            : null);
    final request = http.Request(method, _uri(path, query))
      ..headers.addAll(_headers(tenant: tenant, idempotencyKey: mutationKey));
    if (body != null) request.body = jsonEncode(body);
    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401 &&
        allowRefresh &&
        refreshToken != null &&
        !path.contains('/auth/refresh')) {
      final refreshed = await _refresh();
      if (refreshed) {
        return _request(
          method,
          path,
          body: body,
          query: query,
          tenant: tenant,
          allowRefresh: false,
          idempotencyKey: mutationKey,
        );
      }
    }
    return _decode(response);
  }

  Future<bool> _refresh() async {
    final token = refreshToken;
    if (token == null) return false;
    final response = await _http.post(
      _uri('/auth/refresh'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({'refresh_token': token}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return false;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    accessToken = data['access_token']?.toString();
    refreshToken = data['refresh_token']?.toString();
    if (accessToken != null && refreshToken != null) {
      await onTokenRotation?.call(accessToken!, refreshToken!);
      return true;
    }
    return false;
  }

  dynamic _decode(http.Response response) {
    dynamic data;
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        data = response.body;
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    if (data is Map<String, dynamic>) {
      var detail = data['detail'];
      if (detail is List) {
        detail = detail
            .map((e) => e is Map ? e['msg'] ?? e.toString() : e.toString())
            .join('\n');
      }
      throw ApiException(
        detail?.toString() ?? 'Request failed (${response.statusCode})',
        statusCode: response.statusCode,
        code: data['code']?.toString(),
        supportId: data['support_id']?.toString(),
      );
    }
    throw ApiException(
        data?.toString() ?? 'Request failed (${response.statusCode})',
        statusCode: response.statusCode);
  }

  Future<dynamic> upload(
    String path,
    PlatformFile file, {
    Map<String, String>? fields,
    Map<String, dynamic>? query,
    String fieldName = 'file',
    bool allowRefresh = true,
    String? idempotencyKey,
  }) async {
    final mutationKey =
        idempotencyKey ?? (tenantId != null ? _newIdempotencyKey() : null);
    final request = http.MultipartRequest('POST', _uri(path, query));
    request.headers.addAll(_headers(json: false, idempotencyKey: mutationKey));
    request.fields.addAll(fields ?? const {});
    if (file.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(fieldName, file.bytes!,
          filename: file.name));
    } else if (file.path != null) {
      request.files.add(await http.MultipartFile.fromPath(fieldName, file.path!,
          filename: file.name));
    } else {
      throw ApiException('The selected file could not be read.');
    }
    final response = await http.Response.fromStream(await _http.send(request));
    if (response.statusCode == 401 &&
        allowRefresh &&
        refreshToken != null &&
        await _refresh()) {
      return upload(
        path,
        file,
        fields: fields,
        query: query,
        fieldName: fieldName,
        allowRefresh: false,
        idempotencyKey: mutationKey,
      );
    }
    return _decode(response);
  }

  Future<Uint8List> download(
    String path, {
    Map<String, dynamic>? query,
    bool allowRefresh = true,
  }) async {
    final response =
        await _http.get(_uri(path, query), headers: _headers(json: false));
    if (response.statusCode == 401 &&
        allowRefresh &&
        refreshToken != null &&
        !path.contains('/auth/refresh')) {
      final refreshed = await _refresh();
      if (refreshed) {
        return download(path, query: query, allowRefresh: false);
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    _decode(response);
    throw ApiException('Download failed.');
  }
}
