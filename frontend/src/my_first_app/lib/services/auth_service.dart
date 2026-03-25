import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:pointycastle/asn1/asn1_parser.dart';
import 'package:pointycastle/asn1/primitives/asn1_bit_string.dart';
import 'package:pointycastle/asn1/primitives/asn1_integer.dart';
import 'package:pointycastle/asn1/primitives/asn1_sequence.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/pkcs1.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/api.dart';

class AuthService {
  static const String baseUrl = 'http://localhost:8080/api/v1';

  static const _keyToken = 'auth_token';
  static const _keyUser = 'auth_user';

  final http.Client _client = http.Client();

  /// 获取保存的 Token（兼容旧代码）
  Future<String?> getSavedToken() async {
    return getToken();
  }

  /// 获取服务器 RSA 公钥并加密密码
  Future<String?> _encryptPassword(String password) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/public-key');
      final resp = await _client.get(uri);
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final pubKeyBase64 = (data['data']['public_key'] ?? data['data']['publicKey']) as String;
      final pubKeyBytes = base64Decode(pubKeyBase64);

      // 解析 SubjectPublicKeyInfo 格式的公钥
      final asn1Parser = ASN1Parser(pubKeyBytes);
      final topSeq = asn1Parser.nextObject() as ASN1Sequence;
      final bitString = topSeq.elements![1] as ASN1BitString;
      // valueBytes 的第一个字节是 unused bits 计数，跳过它
      final innerParser = ASN1Parser(
        Uint8List.fromList(bitString.valueBytes!.sublist(1)),
      );
      final innerSeq = innerParser.nextObject() as ASN1Sequence;
      final modulus = (innerSeq.elements![0] as ASN1Integer).integer!;
      final exponent = (innerSeq.elements![1] as ASN1Integer).integer!;

      final publicKey = RSAPublicKey(modulus, exponent);
      final cipher = PKCS1Encoding(RSAEngine())
        ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

      final input = Uint8List.fromList(utf8.encode(password));
      final encrypted = cipher.process(input);
      return base64Encode(encrypted);
    } catch (e) {
      if (kDebugMode) print('encryptPassword error: $e');
      return null;
    }
  }

  /// 真实登录：/api/v1/auth/login/password
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    try {
      final encryptedPassword = await _encryptPassword(password);
      if (encryptedPassword == null) {
        if (kDebugMode) print('login error: 获取公钥或加密失败');
        return false;
      }

      final uri = Uri.parse('$baseUrl/auth/login/password');
      final resp = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': encryptedPassword,
          'device_id': 'flutter-${DateTime.now().millisecondsSinceEpoch}',
        }),
      );

      if (kDebugMode) {
        print('login status: ${resp.statusCode}, body: ${resp.body}');
      }

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final token = data['data']['token'] as String;
        final userinfo = data['data']['user_info'] as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyToken, token);
        await prefs.setString(_keyUser, jsonEncode(userinfo));
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('login error: $e');
      return false;
    }
  }

  /// 发送短信验证码：/api/v1/auth/sms/send
  /// 返回值：mock 模式下返回验证码字符串，失败返回 null
  Future<String?> sendSmsCode({
    required String phone,
    required String type, // REGISTER 或 LOGIN
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/auth/sms/send');
      final resp = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'type': type}),
      );
      if (kDebugMode) {
        print('sendSmsCode status: ${resp.statusCode}, body: ${resp.body}');
      }
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        // mock 模式下后端把验证码放在 data.code 字段
        final code = data['data']?['code'] as String?;
        return code ?? ''; // 空字符串表示发送成功但无 mock code
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('sendSmsCode error: $e');
      return null;
    }
  }

  /// 真实注册：/api/v1/auth/register
  Future<bool> register({
    required String username,
    required String password,
    required String phone,
    required String smsCode,
    required String role,
    String? nickname,
    int? schoolId,
  }) async {
    try {
      final encryptedPassword = await _encryptPassword(password);
      if (encryptedPassword == null) {
        if (kDebugMode) print('register error: 获取公钥或加密失败');
        return false;
      }

      final uri = Uri.parse('$baseUrl/auth/register');
      final resp = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': encryptedPassword,
          'phone': phone,
          'sms_code': smsCode,
          'role': role,
          if (nickname != null) 'nickname': nickname,
          if (schoolId != null) 'school_id': schoolId,
        }),
      );

      if (kDebugMode) {
        print('register status: ${resp.statusCode}, body: ${resp.body}');
      }

      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (e) {
      if (kDebugMode) print('register error: $e');
      return false;
    }
  }

  /// 从本地获取当前用户缓存
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyUser);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) print('getCurrentUser error: $e');
      return null;
    }
  }

  /// 从本地获取 Token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  /// 是否已登录
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// 登出：POST /api/v1/auth/logout + 清本地
  Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        final uri = Uri.parse('$baseUrl/auth/logout');
        await _client.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
    } catch (e) {
      if (kDebugMode) print('logout error: $e');
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken);
      await prefs.remove(_keyUser);
    }
  }

  /// 假登录（本地测试用）
  Future<bool> fakeLogin({
    required String username,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (username.isEmpty || password.length < 4) return false;
    final token = 'fake-token-${DateTime.now().millisecondsSinceEpoch}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(
      _keyUser,
      jsonEncode({
        'id': 10086,
        'username': username,
        'role': 'TEACHER',
        'school_id': 50,
      }),
    );
    return true;
  }

  /// 假注册（本地测试用）
  Future<bool> fakeRegister({
    required String username,
    required String password,
    String phone = '13800000000',
    String smsCode = '000000',
    required String role,
    String? nickname,
    int? schoolId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (username.isEmpty || password.length < 4) return false;
    final prefs = await SharedPreferences.getInstance();
    final token = 'fake-token-${DateTime.now().millisecondsSinceEpoch}';
    await prefs.setString(_keyToken, token);
    await prefs.setString(
      _keyUser,
      jsonEncode({
        'id': 10086,
        'username': username,
        'role': role,
        'nickname': nickname ?? '',
        'school_id': schoolId ?? 50,
      }),
    );
    return true;
  }
}
