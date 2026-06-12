import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config.dart';

const _uuid = Uuid();

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? get _jwt => Supabase.instance.client.auth.currentSession?.accessToken;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_jwt != null) 'Authorization': 'Bearer $_jwt',
      };

  // Campaigns
  Future<Map<String, dynamic>> loadCampaign(String campaignId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/campaign/$campaignId/load'),
      headers: _headers,
    );
    return _parse(response);
  }

  Future<Map<String, dynamic>> createCampaign({
    String template = 'adventurer',
    String? rulesetOverride,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/campaign/create'),
      headers: _headers,
      body: jsonEncode({
        'template': template,
        if (rulesetOverride != null) 'ruleset_override': rulesetOverride,
      }),
    );
    return _parse(response);
  }

  Future<List<dynamic>> listCampaigns() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/campaign/list'),
      headers: _headers,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: _tryParseError(response.body),
    );
  }

  Future<Map<String, dynamic>> generateVision(String eventId) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/visualize/$eventId'),
      headers: _headers,
    ).timeout(const Duration(seconds: 60));
    return _parse(response);
  }

  Future<void> deleteCampaign(String campaignId) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/campaign/$campaignId'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _tryParseError(response.body),
      );
    }
  }

  Future<List<dynamic>> getCampaignHistory(String campaignId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/narrative/campaign/$campaignId/history'),
      headers: _headers,
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: _tryParseError(response.body),
    );
  }

  // Game actions
  Future<Map<String, dynamic>> sendAction({
    required String campaignId,
    required String action,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/action'),
      headers: _headers,
      body: jsonEncode({
        'campaign_id': campaignId,
        'action':      action,
        'intent':      action,
        'request_id':  _uuid.v4(),
      }),
    ).timeout(const Duration(seconds: 30));
    return _parse(response);
  }

  // Character
  Future<Map<String, dynamic>> getCharacter(String campaignId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/campaign/$campaignId/character'),
      headers: _headers,
    );
    return _parse(response);
  }

  Map<String, dynamic> _parse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: _tryParseError(response.body),
    );
  }

  String _tryParseError(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['detail'] ?? data['error'] ?? body;
    } catch (_) {
      return body;
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
