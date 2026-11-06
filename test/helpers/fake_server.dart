import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A pretend server: answers like the real one, counts what it was asked.
class FakeServer {
  int refreshCalls = 0;
  int meCalls = 0;
  String validAccess = 'access-1';
  String validRefresh = 'refresh-1';
  bool down = false;
  String email = 'kate@example.com';
  String? name;

  /// The code the pretend sign-up email contains.
  static const signupCode = '123456';
  int signupEmails = 0;

  /// How long /me takes to answer.
  Duration meDelay = Duration.zero;

  late final client = MockClient((request) async {
    if (down) throw http.ClientException('Connection refused');
    final body = request.body.isEmpty ? <String, dynamic>{} : jsonDecode(request.body) as Map<String, dynamic>;
    final signedIn = request.headers['authorization'] == 'Bearer $validAccess';
    final user = {'id': 'u1', 'email': email, 'name': name, 'hasPassword': true};

    switch ('${request.method} ${request.url.path}') {
      case 'POST /auth/login':
        if (body['password'] != 'right password') {
          return _json(401, {'error': 'invalid_credentials'});
        }
        return _json(200, {'user': user, 'accessToken': validAccess, 'refreshToken': validRefresh});
      case 'POST /auth/refresh':
        refreshCalls++;
        // Give the waiting requests time to pile up behind this one.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (body['refreshToken'] != validRefresh) return _json(401, {'error': 'invalid_refresh_token'});
        validAccess = 'access-${refreshCalls + 1}';
        validRefresh = 'refresh-${refreshCalls + 1}';
        return _json(200, {'accessToken': validAccess, 'refreshToken': validRefresh});
      case 'GET /me':
        meCalls++;
        await Future<void>.delayed(meDelay);
        return signedIn ? _json(200, user) : _json(401, {'error': 'unauthorized'});
      case 'POST /auth/register':
        signupEmails++;
        return _json(202, {'message': 'Code sent'});
      case 'POST /auth/register/confirm':
        if (body['code'] != signupCode) return _json(400, {'error': 'invalid_code'});
        return _json(201, {'user': user, 'accessToken': validAccess, 'refreshToken': validRefresh});
      case 'PATCH /me':
        if (!signedIn) return _json(401, {'error': 'unauthorized'});
        name = body['name'] as String?;
        return _json(200, {...user, 'name': name});
      case 'POST /auth/password-reset/request':
        return http.Response('', 429, headers: {'retry-after': '42'});
    }
    return _json(404, {'error': 'not_found'});
  });

  static http.Response _json(int status, Object body) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
}
