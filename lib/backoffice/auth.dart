import 'dart:convert';

import 'net.dart';

/// The Firebase project's web API key (not a secret: it only names the
/// project; the database rules decide who may do what).
const firebaseApiKey = 'AIzaSyDMNpowcCSB8aHxSoTEjfGzyY29Fdbd6FM';

/// Sign-in addresses. Nobody types or receives mail at these: staff sign in
/// with a username and players with their player ID or username; the app
/// turns those into the Firebase account's email.
String staffEmail(String username) => '${username.trim().toLowerCase()}@staff.zoya7.app';

/// A player's sign-in. A password reset makes a new one ([generation] + 1),
/// because without a server staff can't change another account's password.
String playerEmail(String playerId, int generation) =>
    '${playerId.toLowerCase()}${generation == 0 ? '' : '.$generation'}@players.zoya7.app';

/// A signed-in Firebase account.
class AuthSession {
  AuthSession({required this.uid, required this.idToken, required this.refreshToken, required this.expires});
  final String uid;
  String idToken;
  String refreshToken;
  DateTime expires;

  Map<String, Object> toJson() => {'u': uid, 'r': refreshToken};

  /// A saved session: signed in again with the refresh token on first use.
  static AuthSession? fromJson(Object? j) {
    if (j is! Map || j['u'] is! String || j['r'] is! String) return null;
    return AuthSession(uid: j['u'] as String, idToken: '', refreshToken: j['r'] as String, expires: DateTime(2000));
  }
}

class AuthError implements Exception {
  AuthError(this.message, [this.code = '']);
  final String message;
  final String code;
  @override
  String toString() => message;
}

typedef Poster = Future<({int status, String body})> Function(String url, String body, String contentType);

/// Firebase Authentication over its REST API (email and password).
class FirebaseAuthApi {
  FirebaseAuthApi({this.apiKey = firebaseApiKey, this.post = httpPost, DateTime Function()? clock})
      : clock = clock ?? DateTime.now;

  final String apiKey;
  final Poster post;
  final DateTime Function() clock;

  static const _accounts = 'https://identitytoolkit.googleapis.com/v1/accounts';
  static const _token = 'https://securetoken.googleapis.com/v1/token';

  Future<AuthSession> signIn(String email, String password) =>
      _account('signInWithPassword', {'email': email, 'password': password, 'returnSecureToken': true});

  /// Make a new account. It doesn't change who is signed in on this device.
  Future<AuthSession> signUp(String email, String password) =>
      _account('signUp', {'email': email, 'password': password, 'returnSecureToken': true});

  /// A fresh token for [s] (they last an hour).
  Future<AuthSession> refresh(AuthSession s) async {
    final res = await _post('$_token?key=$apiKey',
        'grant_type=refresh_token&refresh_token=${Uri.encodeQueryComponent(s.refreshToken)}', 'application/x-www-form-urlencoded');
    return s
      ..idToken = res['id_token'] as String
      ..refreshToken = res['refresh_token'] as String
      ..expires = _expiry(res['expires_in']);
  }

  /// A token good for at least a few more minutes.
  Future<String> token(AuthSession s) async {
    if (s.idToken.isEmpty || clock().isAfter(s.expires.subtract(const Duration(minutes: 5)))) await refresh(s);
    return s.idToken;
  }

  Future<AuthSession> _account(String action, Map<String, Object> body) async {
    final res = await _post('$_accounts:$action?key=$apiKey', jsonEncode(body), 'application/json');
    return AuthSession(
      uid: res['localId'] as String,
      idToken: res['idToken'] as String,
      refreshToken: res['refreshToken'] as String,
      expires: _expiry(res['expiresIn']),
    );
  }

  DateTime _expiry(Object? seconds) => clock().add(Duration(seconds: int.tryParse('$seconds') ?? 3600));

  Future<Map<String, dynamic>> _post(String url, String body, String type) async {
    final ({int status, String body}) res;
    try {
      res = await post(url, body, type);
    } catch (_) {
      throw AuthError('Can’t reach the sign-in service — check the connection');
    }
    Map<String, dynamic>? j;
    try {
      j = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    if (res.status == 200 && j != null) return j;
    final raw = ((j?['error'] as Map?)?['message'] as String?) ?? 'HTTP ${res.status}';
    final code = raw.split(' ').first;
    throw AuthError(_message(code), code);
  }

  static String _message(String code) => switch (code) {
        'EMAIL_NOT_FOUND' || 'INVALID_PASSWORD' || 'INVALID_LOGIN_CREDENTIALS' || 'INVALID_EMAIL' => 'Wrong username or password',
        'EMAIL_EXISTS' => 'That username is taken',
        'WEAK_PASSWORD' => 'The password needs at least 6 characters',
        'USER_DISABLED' => 'This account is turned off',
        'TOO_MANY_ATTEMPTS_TRY_LATER' => 'Too many tries — wait a few minutes',
        'OPERATION_NOT_ALLOWED' || 'PASSWORD_LOGIN_DISABLED' =>
          'Turn on Email/Password sign-in in the Firebase console (Authentication → Sign-in method)',
        'TOKEN_EXPIRED' || 'INVALID_REFRESH_TOKEN' || 'USER_NOT_FOUND' => 'Signed out — sign in again',
        _ => 'Sign-in failed ($code)',
      };
}
