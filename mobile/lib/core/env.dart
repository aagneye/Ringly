/// Which backend the app talks to.
///
/// Never hardcoded inline at call sites — every repository reads
/// [Env.baseUrl] so switching between the emulator and a deployed backend is
/// a one-line change in the entrypoint (see main_dev.dart / main_prod.dart),
/// not a search-and-replace across the app.
class Env {
  const Env._();

  /// `10.0.2.2` is the special alias the Android emulator uses to reach the
  /// host machine it is running on — not a real IP, just how the emulator's
  /// virtual network resolves "the laptop outside the phone".
  static const String emulatorBaseUrl = 'http://10.0.2.2:3000';

  /// Set by main_prod.dart to the deployed Next.js API URL once available.
  /// Placeholder until Phase P (deployment) fills this in for real.
  static const String productionBaseUrl = 'https://ringly.example.com';
}
