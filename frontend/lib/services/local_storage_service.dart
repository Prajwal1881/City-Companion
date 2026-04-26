import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class LocalStorageService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return await openDatabase(
        'city_companion.db',
        version: 1,
        onCreate: _onCreate,
      );
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'city_companion.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE local_messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        text TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        status_code INTEGER DEFAULT 0,
        is_synced_with_server INTEGER DEFAULT 0
      )
    ''');
  }

  // ─── Message Operations ───────────────────────────────────────────────────

  /// Saves a new message locally. Returns the generated message ID.
  static Future<String> savePendingMessage({
    required String conversationId,
    required String senderId,
    required String text,
    int? timestamp,
  }) async {
    final db = await database;
    final msgId = const Uuid().v4();
    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'local_messages',
      {
        'id': msgId,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'text': text,
        'timestamp': ts,
        'status_code': 0, // Pending
        'is_synced_with_server': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return msgId;
  }

  /// Saves or updates a message received from the server
  static Future<void> saveServerMessage({
    required String id,
    required String conversationId,
    required String senderId,
    required String text,
    required int timestamp,
    int statusCode = 1, // Default Sent
  }) async {
    final db = await database;
    await db.insert(
      'local_messages',
      {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'text': text,
        'timestamp': timestamp,
        'status_code': statusCode,
        'is_synced_with_server': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve messages for a conversation, sorted newest first
  static Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    final db = await database;
    return await db.query(
      'local_messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp DESC',
    );
  }

  /// Update the status of a local message
  static Future<void> updateMessageStatus({
    required String id,
    required int statusCode,
    bool isSynced = true,
  }) async {
    final db = await database;
    await db.update(
      'local_messages',
      {
        'status_code': statusCode,
        'is_synced_with_server': isSynced ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get all pending messages that need to be synced
  static Future<List<Map<String, dynamic>>> getPendingMessages() async {
    final db = await database;
    return await db.query(
      'local_messages',
      where: 'is_synced_with_server = ?',
      whereArgs: [0],
    );
  }

  /// Convert backend message structure to local structure
  static Map<String, dynamic> mapServerMessageToLocal(Map<String, dynamic> serverMsg) {
    return {
      'id': serverMsg['id']?.toString() ?? '',
      'conversation_id': serverMsg['conversation_id']?.toString() ?? '',
      'sender_id': serverMsg['sender_id']?.toString() ?? '',
      'text': serverMsg['content'] ?? '',
      'timestamp': serverMsg['sent_at'] ?? serverMsg['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
      'status_code': _mapServerStatusToCode(serverMsg['status']),
      'is_synced_with_server': 1,
    };
  }

  static int _mapServerStatusToCode(String? status) {
    if (status == 'read') return 3;
    if (status == 'delivered') return 2;
    return 1; // sent
  }

  /// Syncs an entire batch of messages from the server, replacing old ones
  static Future<void> syncMessages(String conversationId, List<dynamic> serverMessages) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var msg in serverMessages) {
        final serverMsg = Map<String, dynamic>.from(msg as Map);
        final localMsg = mapServerMessageToLocal(serverMsg);
        await txn.insert(
          'local_messages',
          localMsg,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
