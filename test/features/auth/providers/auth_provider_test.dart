import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendsheet/data/remote/google_auth_service.dart';
import 'package:spendsheet/features/auth/providers/auth_provider.dart';
import 'package:spendsheet/features/auth/services/account_session.dart';

class _Account extends Mock implements GoogleSignInAccount {
  _Account(this._id);
  final String _id;

  @override
  String get id => _id;
}

/// Stands in for Google sign-in. [remembered] is the account the plugin
/// would restore at the next app start.
class _Google extends GoogleAuthService {
  GoogleSignInAccount? remembered;
  GoogleSignInAccount? _current;
  GoogleSignInAccount? chooses;

  @override
  Future<void> init() async => _current = remembered;

  @override
  GoogleSignInAccount? get currentUser => _current;

  @override
  bool get isSignedIn => _current != null;

  @override
  Future<GoogleSignInAccount?> signIn() async {
    _current = chooses;
    remembered = chooses;
    return chooses;
  }

  @override
  Future<void> signOut() async {
    _current = null;
    remembered = null;
  }
}

/// Records ownership checks instead of touching data.
class _Session extends Fake implements AccountSession {
  final calls = <(String, bool)>[];
  Object? failWith;

  @override
  Future<bool> onSignedIn(String accountId, {required bool interactive}) async {
    calls.add((accountId, interactive));
    if (failWith != null) throw failWith!;
    return false;
  }
}

void main() {
  late _Google google;
  late _Session session;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    google = _Google();
    session = _Session();
  });

  test('a restored session is checked as a restore', () async {
    google.remembered = _Account('a');

    await AuthNotifier(google, session: session).init();

    expect(session.calls, [('a', false)]);
  });

  test('a failed ownership check signs Google out again', () async {
    google.chooses = _Account('b');
    session.failWith = Exception('disk full');
    final auth = AuthNotifier(google, session: session);

    expect(await auth.signIn(), isFalse);

    expect(auth.state, AuthState.error);
    expect(google.remembered, isNull,
        reason: 'the next start must not restore account b silently');
  });

  test('a sign-in cut off before its ownership check is checked as a new '
      'sign-in at the next start', () async {
    // The app dies during the ownership check, so neither the check nor
    // the sign-out after it ever finishes.
    google = _GoogleNoSignOut()..chooses = _Account('b');
    session.failWith = StateError('process killed');
    await AuthNotifier(google, session: session).signIn();
    expect(google.remembered?.id, 'b');

    session
      ..failWith = null
      ..calls.clear();
    await AuthNotifier(google, session: session).init();

    expect(session.calls, [('b', true)],
        reason: 'unowned data must be treated as someone else\'s');
  });

  test('the next start after a finished sign-in is a normal restore',
      () async {
    google.chooses = _Account('b');
    await AuthNotifier(google, session: session).signIn();

    session.calls.clear();
    await AuthNotifier(google, session: session).init();

    expect(session.calls, [('b', false)]);
  });

  test('a cancelled sign-in leaves no marker behind', () async {
    google.chooses = null;
    await AuthNotifier(google, session: session).signIn();

    google.remembered = _Account('a');
    await AuthNotifier(google, session: session).init();

    expect(session.calls, [('a', false)]);
  });
}

/// Google sign-in whose sign-out never happens, as when the process dies
/// right after the account was chosen.
class _GoogleNoSignOut extends _Google {
  @override
  Future<void> signOut() async {}
}
