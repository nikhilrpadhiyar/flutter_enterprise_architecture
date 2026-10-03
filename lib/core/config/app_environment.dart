/// Deployment environments the app can run in.
enum AppEnvironment {
  /// Local development against a development backend.
  development,

  /// Pre-production environment.
  staging,

  /// Live production environment.
  production;

  /// Resolves an environment from its [name], defaulting to [development].
  static AppEnvironment parse(String name) {
    return AppEnvironment.values.firstWhere(
      (environment) => environment.name == name.toLowerCase(),
      orElse: () => AppEnvironment.development,
    );
  }

  /// Whether this is the production environment.
  bool get isProduction => this == AppEnvironment.production;
}
