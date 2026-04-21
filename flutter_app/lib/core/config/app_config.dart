class AppConfig {
  const AppConfig._();

  static const String _devApiBaseUrl = "https://monev.app";
  static const String _stagingApiBaseUrl = "https://monev.app";
  static const String _prodApiBaseUrl = "https://monev.app";

  static const String appEnv = String.fromEnvironment(
    "APP_ENV",
    defaultValue: "development",
  );

  static bool get isProduction => appEnv == "production";
  static bool get isStaging => appEnv == "staging";

  static String get defaultApiBaseUrl {
    if (isProduction) return _prodApiBaseUrl;
    if (isStaging) return _stagingApiBaseUrl;
    return _devApiBaseUrl;
  }

  static String get apiBaseUrl {
    const String fromDefine = String.fromEnvironment("API_BASE_URL");
    if (fromDefine.isNotEmpty) return fromDefine;
    return defaultApiBaseUrl;
  }
}
