class ApiEndpoints {
  const ApiEndpoints._();

  static const String login = '/api/v1/auth/login';
  static const String refresh = '/api/v1/auth/refresh';
  static const String logout = '/api/v1/auth/logout';
  static const String provisioning = '/api/v1/provisioning/device';
  static const String currentDevice = '/api/v1/devices/current';
  static const String calls = '/api/v1/calls';
  static const String clientEvents = '/api/v1/client-events';
}
