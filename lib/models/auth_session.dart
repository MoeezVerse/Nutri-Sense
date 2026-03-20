/// Local authentication session used for this prototype.
///
/// This app currently does not use a backend; authentication data is stored
/// locally on the device in `SharedPreferences`.
class AuthSession {
  final String email;
  final String name;

  const AuthSession({
    required this.email,
    required this.name,
  });
}

