import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Java 后端 API 根地址（包含 /api/v1）
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );

  /// Python AI 服务根地址（不带 /api/v1）
  static const String aiBaseUrl = String.fromEnvironment(
    'AI_BASE_URL',
    defaultValue: 'http://localhost:5001',
  );

  static void printCurrentConfig() {
    if (!kDebugMode) return;
    print('[ApiConfig] API_BASE_URL: $apiBaseUrl');
    print('[ApiConfig] AI_BASE_URL: $aiBaseUrl');
  }
}

