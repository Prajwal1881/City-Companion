import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../core/api_endpoints.dart';
import '../core/router.dart';

const _storage = FlutterSecureStorage();

class ApiClient {
  static final _dio = Dio(BaseOptions(
    baseUrl: apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static void init() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await logout();
          final context = rootNavigatorKey.currentContext;
          if (context != null) {
            GoRouter.of(context).go('/auth/phone');
          }
        }
        return handler.next(error);
      },
    ));
  }

  // ── Auth ──────────────────────────────────────────────────────────────

  static Future<String> sendOtp(String phone) async {
    final res = await _dio.post('/auth/send-otp', data: {'phone': phone});
    return res.data['dev_otp'] ?? '';
  }

  static Future<String> verifyOtp(String phone, String otp) async {
    final res =
        await _dio.post('/auth/verify-otp', data: {'phone': phone, 'otp': otp});
    final token = res.data['access_token'] as String;
    await _storage.write(key: 'access_token', value: token);
    return token;
  }

  static Future<void> logout() async {
    await _storage.delete(key: 'access_token');
  }

  static Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'access_token');
    return token != null;
  }

  // ── Users ─────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/users/me');
    return res.data;
  }

  static Future<Map<String, dynamic>> updateMe(
      Map<String, dynamic> data) async {
    final res = await _dio.put('/users/me', data: data);
    return res.data;
  }

  static Future<void> registerDeviceToken(String token) async {
    await _dio.post('/users/me/device-token', data: {'token': token});
  }

  static Future<void> unregisterDeviceToken(String token) async {
    await _dio.delete('/users/me/device-token', data: {'token': token});
  }

  static Future<Map<String, dynamic>> testPush() async {
    final res = await _dio.post('/users/me/test-push');
    return res.data;
  }

  static Future<void> sendHeartbeat() async {
    await _dio.post('/users/me/heartbeat');
  }

  static Future<List<dynamic>> getNearby(
      {required double lat, required double lng, double radiusKm = 10}) async {
    final res = await _dio.get('/users/nearby',
        queryParameters: {'lat': lat, 'lng': lng, 'radius_km': radiusKm});
    return res.data;
  }

  // ── Plans ─────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getPlans({String? category}) async {
    final res = await _dio.get('/plans/',
        queryParameters: category != null ? {'category': category} : null);
    return res.data;
  }

  static Future<Map<String, dynamic>> getPlan(String planId) async {
    final res = await _dio.get('/plans/$planId');
    return res.data;
  }

  static Future<Map<String, dynamic>> createPlan(
      Map<String, dynamic> data) async {
    final res = await _dio.post('/plans/', data: data);
    return res.data;
  }

  static Future<List<Map<String, dynamic>>> locationAutocomplete(
      String query) async {
    final res = await _dio
        .get('/plans/location/autocomplete', queryParameters: {'query': query});
    return (res.data as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<void> joinPlan(String planId) async {
    await _dio.post('/plans/$planId/join');
  }

  static Future<void> leavePlan(String planId) async {
    await _dio.delete('/plans/$planId/leave');
  }

  static Future<void> deletePlan(String planId) async {
    await _dio.delete('/plans/$planId');
  }

  // ── Notifications ─────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final res = await _dio.get('/notifications/');
    return (res.data as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<int> getUnseenNotificationCount() async {
    final res = await _dio.get('/notifications/unseen-count');
    return (res.data['count'] as num?)?.toInt() ?? 0;
  }

  static Future<void> markAllNotificationsRead() async {
    await _dio.post('/notifications/read-all');
  }

  static Future<void> deleteNotification(String notificationId) async {
    await _dio.delete('/notifications/$notificationId');
  }

  // ── Rooms ─────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getRooms({String? city, int? maxRent}) async {
    final res = await _dio.get('/rooms/', queryParameters: {
      if (city != null) 'city': city,
      if (maxRent != null) 'max_rent': maxRent,
    });
    return res.data;
  }

  static Future<Map<String, dynamic>> createRoom(
      Map<String, dynamic> data) async {
    final res = await _dio.post('/rooms/', data: data);
    return res.data;
  }

  // ── Communities ───────────────────────────────────────────────────────

  static Future<List<dynamic>> getCommunities({String? city}) async {
    final res = await _dio.get('/communities/',
        queryParameters: city != null ? {'city': city} : null);
    return res.data;
  }

  static Future<void> joinCommunity(String id) async {
    await _dio.post('/communities/$id/join');
  }

  static Future<void> leaveCommunity(String id) async {
    await _dio.delete('/communities/$id/leave');
  }

  // ── Chat ──────────────────────────────────────────────────────────────

  static Future<List<dynamic>> getConversations() async {
    final res = await _dio.get('/chat/conversations');
    return res.data;
  }

  static Future<List<dynamic>> getMessages(String convId) async {
    final res = await _dio.get('/chat/conversations/$convId/messages');
    return res.data;
  }

  static Future<void> deleteConversation(String convId) async {
    await _dio.delete('/chat/conversations/$convId');
  }

  static Future<Map<String, dynamic>> getOrCreateDM(String targetUserId) async {
    final res = await _dio.post('/chat/dm/$targetUserId');
    return res.data;
  }
}
