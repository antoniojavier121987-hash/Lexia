import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/contract.dart';
import '../models/chat_message.dart';
import 'auth_storage.dart';

/// Excepción con el mensaje de error legible que devuelve la API,
/// para poder mostrarlo directo en la interfaz.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  static Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthStorage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static String _extractError(http.Response resp) {
    try {
      final body = jsonDecode(resp.body);
      return body['detail']?.toString() ?? 'Error inesperado (${resp.statusCode})';
    } catch (_) {
      return 'Error inesperado (${resp.statusCode})';
    }
  }

  // ---------------------------------------------------------------------
  // Autenticación
  // ---------------------------------------------------------------------
  static Future<void> signup(String email, String password) async {
    final resp = await http.post(
      _uri('/api/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (resp.statusCode != 200) throw ApiException(_extractError(resp));
    final data = jsonDecode(resp.body);
    await AuthStorage.saveToken(data['access_token']);
  }

  static Future<void> login(String email, String password) async {
    final resp = await http.post(
      _uri('/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (resp.statusCode != 200) throw ApiException(_extractError(resp));
    final data = jsonDecode(resp.body);
    await AuthStorage.saveToken(data['access_token']);
  }

  static Future<void> logout() async {
    await AuthStorage.clearToken();
  }

  // ---------------------------------------------------------------------
  // Contratos
  // ---------------------------------------------------------------------
  static Future<List<Contract>> listContracts() async {
    final resp = await http.get(_uri('/api/contracts'), headers: await _authHeaders());
    if (resp.statusCode != 200) throw ApiException(_extractError(resp));
    final List data = jsonDecode(resp.body);
    return data.map((c) => Contract.fromJson(c)).toList();
  }

  static Future<Contract> getContract(int id) async {
    final resp = await http.get(_uri('/api/contracts/$id'), headers: await _authHeaders());
    if (resp.statusCode != 200) throw ApiException(_extractError(resp));
    return Contract.fromJson(jsonDecode(resp.body));
  }

  static Future<Contract> uploadContract(File file) async {
    final token = await AuthStorage.getToken();
    final request = http.MultipartRequest('POST', _uri('/api/contracts/upload'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResp = await request.send();
    final resp = await http.Response.fromStream(streamedResp);
    if (resp.statusCode != 200) throw ApiException(_extractError(resp));
    return Contract.fromJson(jsonDecode(resp.body));
  }

  static Future<Contract> analyzeContract(int id) async {
    final resp = await http.post(
      _uri('/api/contracts/$id/analyze'),
      headers: await _authHeaders(),
    );
    if (resp.statusCode != 200) throw ApiException(_extractError(resp));
    return Contract.fromJson(jsonDecode(resp.body));
  }

  // ---------------------------------------------------------------------
  // Chat
  // ---------------------------------------------------------------------
  static Future<List<ChatMessage>> getChatHistory(int contractId) async {
    final resp = await http.get(
      _uri('/api/contracts/$contractId/chat'),
      headers: await _authHeaders(),
    );
    if (resp.statusCode != 200) throw ApiException(_extractError(resp));
    final List data = jsonDecode(resp.body);
    return data.map((m) => ChatMessage.fromJson(m)).toList();
  }

  static Future<ChatMessage> sendChatMessage(int contractId, String question) async {
    final resp = await http.post(
      _uri('/api/contracts/$contractId/chat'),
      headers: await _authHeaders(),
      body: jsonEncode({'question': question}),
    );
    if (resp.statusCode != 200) throw ApiException(_extractError(resp));
    return ChatMessage.fromJson(jsonDecode(resp.body));
  }

  // ---------------------------------------------------------------------
  // Simulador de escenarios futuros
  // ---------------------------------------------------------------------
  static Future<String> simulateScenario(int contractId, String scenario) async {
    final resp = await http.post(
      _uri('/api/contracts/$contractId/simulate'),
      headers: await _authHeaders(),
      body: jsonEncode({'scenario': scenario}),
    );
    if (resp.statusCode != 200) throw ApiException(_extractError(resp));
    final data = jsonDecode(resp.body);
    return data['answer'] as String;
  }

  // ---------------------------------------------------------------------
  // Comparador de contratos
  // ---------------------------------------------------------------------
  static Future<Map<String, dynamic>> compareContracts(int idA, int idB) async {
    final resp = await http.post(
      _uri('/api/contracts/compare'),
      headers: await _authHeaders(),
      body: jsonEncode({'contract_id_a': idA, 'contract_id_b': idB}),
    );
    if (resp.statusCode != 200) throw ApiException(_extractError(resp));
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------
  // Reporte en PDF
  // ---------------------------------------------------------------------
  static Future<List<int>> downloadReport(int contractId) async {
    final resp = await http.get(
      _uri('/api/contracts/$contractId/report'),
      headers: await _authHeaders(),
    );
    if (resp.statusCode != 200) throw ApiException(_extractError(resp));
    return resp.bodyBytes;
  }
}
