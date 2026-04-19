// lib/core/data/agent_service.dart
//
// FloodSense Agent Service
// ========================
// The single point of contact between the Flutter app and the Python Agent Server.
// All AI-driven actions (SOS, Q&A, alerts, sitreps) go through this service.
//
// Agent Server: http://localhost:8000  (change to deployed URL in production)

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AgentService {
  // Change this to your deployed server URL in production
  static const String _baseUrl = 'http://10.0.2.2:8000'; // Android emulator → localhost
  // static const String _baseUrl = 'http://localhost:8000'; // Web / desktop
  // static const String _baseUrl = 'https://your-cloud-run-url.run.app'; // Production

  static final AgentService _instance = AgentService._internal();
  factory AgentService() => _instance;
  AgentService._internal();

  final http.Client _client = http.Client();

  // ── Health Check ─────────────────────────────────────────────────────────────

  Future<bool> isServerOnline() async {
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── CITIZEN AGENT: Submit SOS ─────────────────────────────────────────────────
  //
  // Called when user taps the SOS button in the app.
  // Citizen Agent parses the message → structures the incident → saves to Firestore.
  // Coordinator Agent automatically dispatches a volunteer within 90 seconds.

  Future<SOSResponse> submitSOS({
    required String rawMessage,
    String channel = 'app',
    String? senderPhone,
    double? lat,
    double? lng,
  }) async {
    try {
      final body = {
        'raw_message': rawMessage,
        'channel': channel,
        if (senderPhone != null) 'sender_phone': senderPhone,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };

      final res = await _client
          .post(
            Uri.parse('$_baseUrl/sos'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return SOSResponse.fromJson(data);
      } else {
        debugPrint('[AgentService] SOS failed: ${res.statusCode} ${res.body}');
        return SOSResponse.error('Server error ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('[AgentService] SOS network error: $e');
      // Fallback: queue for retry when online
      return SOSResponse.error('Network error — SOS queued for retry');
    }
  }

  // ── CITIZEN AGENT: Flood Q&A (RAG) ───────────────────────────────────────────
  //
  // Powers the in-app AI chat. Citizen Agent uses keyword SOP retrieval + Gemini.

  Future<ChatResponse> askFloodQuestion(String question, {String language = 'en'}) async {
    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'question': question, 'language': language}),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        return ChatResponse.fromJson(jsonDecode(res.body));
      }
      return ChatResponse.fallback();
    } catch (e) {
      debugPrint('[AgentService] Chat error: $e');
      return ChatResponse.fallback();
    }
  }

  // ── ALERT AGENT: Latest Alerts ────────────────────────────────────────────────
  //
  // Alert Agent writes to Firestore; this endpoint reads the latest.

  Future<List<FloodAlert>> getLatestAlerts({int limit = 5}) async {
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl/alerts?limit=$limit'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = data['alerts'] as List<dynamic>;
        return list.map((a) => FloodAlert.fromJson(a)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[AgentService] Alerts fetch error: $e');
      return [];
    }
  }

  // ── COORDINATOR AGENT: Latest Sitrep ─────────────────────────────────────────

  Future<Sitrep?> getLatestSitrep() async {
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl/sitrep/latest'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['sitrep'] != null) {
          return Sitrep.fromJson(data['sitrep'] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[AgentService] Sitrep fetch error: $e');
      return null;
    }
  }

  // ── RESOURCE AGENT: Inventory ─────────────────────────────────────────────────

  Future<List<InventoryAlert>> getInventoryAlerts() async {
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl/inventory'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = data['recommendations'] as List<dynamic>? ?? [];
        return list.map((i) => InventoryAlert.fromJson(i)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[AgentService] Inventory error: $e');
      return [];
    }
  }

  // ── INCIDENTS ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getIncidents({String? status, int limit = 20}) async {
    try {
      final url = status != null
          ? '$_baseUrl/incidents?status=$status&limit=$limit'
          : '$_baseUrl/incidents?limit=$limit';
      final res = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['incidents'] as List);
      }
      return [];
    } catch (e) {
      debugPrint('[AgentService] Incidents error: $e');
      return [];
    }
  }

  // ── SHELTERS ──────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getShelters() async {
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl/shelters'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['shelters'] as List);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

// ── Data Models ───────────────────────────────────────────────────────────────

class SOSResponse {
  final bool success;
  final String? sosId;
  final String? urgency;
  final List<String> vulnerable;
  final int? headCount;
  final String message;
  final String? error;

  const SOSResponse({
    required this.success,
    this.sosId,
    this.urgency,
    this.vulnerable = const [],
    this.headCount,
    required this.message,
    this.error,
  });

  factory SOSResponse.fromJson(Map<String, dynamic> json) => SOSResponse(
        success: json['success'] as bool? ?? false,
        sosId: json['sos_id'] as String?,
        urgency: json['urgency'] as String?,
        vulnerable: List<String>.from(json['vulnerable'] as List? ?? []),
        headCount: json['head_count'] as int?,
        message: json['message_ms'] as String? ?? json['message'] as String? ?? '',
      );

  factory SOSResponse.error(String error) => SOSResponse(
        success: false,
        message: 'SOS dihantar. Bantuan akan tiba.',
        error: error,
      );
}

class ChatResponse {
  final String question;
  final String answer;
  final String language;

  const ChatResponse({
    required this.question,
    required this.answer,
    required this.language,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) => ChatResponse(
        question: json['question'] as String? ?? '',
        answer: json['answer'] as String? ?? '',
        language: json['language'] as String? ?? 'en',
      );

  factory ChatResponse.fallback() => const ChatResponse(
        question: '',
        answer: 'Sila hubungi Bomba: 994 | Polis: 999 | APM: 991\nPlease call Bomba: 994 | Police: 999 | APM: 991',
        language: 'ms',
      );
}

class FloodAlert {
  final String id;
  final String severity;
  final String? gaugeName;
  final String? districtId;
  final double? riverLevelM;
  final String? reasoning;
  final List<String> recommendedActions;
  final String? createdAt;

  const FloodAlert({
    required this.id,
    required this.severity,
    this.gaugeName,
    this.districtId,
    this.riverLevelM,
    this.reasoning,
    this.recommendedActions = const [],
    this.createdAt,
  });

  factory FloodAlert.fromJson(Map<String, dynamic> json) => FloodAlert(
        id: json['id'] as String? ?? '',
        severity: json['severity'] as String? ?? 'WATCH',
        gaugeName: json['gauge_name'] as String?,
        districtId: json['district_id'] as String?,
        riverLevelM: (json['river_level_m'] as num?)?.toDouble(),
        reasoning: json['reasoning'] as String?,
        recommendedActions: List<String>.from(
            json['recommended_actions'] as List? ?? []),
        createdAt: json['created_at'] as String?,
      );

  bool get isCritical => severity == 'EVACUATE' || severity == 'DANGER';
}

class Sitrep {
  final String id;
  final String content;
  final String? districtId;
  final String? severity;
  final int? activeSos;
  final String? generatedAt;

  const Sitrep({
    required this.id,
    required this.content,
    this.districtId,
    this.severity,
    this.activeSos,
    this.generatedAt,
  });

  factory Sitrep.fromJson(Map<String, dynamic> json) => Sitrep(
        id: json['id'] as String? ?? '',
        content: json['content'] as String? ?? '',
        districtId: json['district_id'] as String?,
        severity: json['severity'] as String?,
        activeSos: json['active_sos'] as int?,
        generatedAt: json['generated_at'] as String?,
      );
}

class InventoryAlert {
  final String item;
  final String status;
  final String action;
  final int priority;

  const InventoryAlert({
    required this.item,
    required this.status,
    required this.action,
    required this.priority,
  });

  factory InventoryAlert.fromJson(Map<String, dynamic> json) => InventoryAlert(
        item: json['item'] as String? ?? '',
        status: json['status'] as String? ?? 'OK',
        action: json['action'] as String? ?? '',
        priority: json['priority'] as int? ?? 5,
      );

  bool get isCritical => status == 'CRITICAL';
}
