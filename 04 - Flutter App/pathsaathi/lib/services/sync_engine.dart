// lib/services/sync_engine.dart
//
// Background mutation queue with exponential backoff retry.
// Queues offline writes and drains them automatically when connectivity returns.
//
// Usage:
//   // Queue a mutation (call from any agent when offline):
//   await SyncEngine.instance.queueMutation(
//     actionType: 'CREATE',
//     entityTable: 'accommodations',
//     entityId: '42',
//     payload: {'camp_name': 'New Camp', 'sector': '9'},
//   );

import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import 'connectivity_service.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _kTable = 'pending_sync_queue';
const _kMaxRetries = 5;

// ── Queue Entry Model ─────────────────────────────────────────────────────────

class SyncQueueEntry {
  final int? id;
  final String actionType;   // CREATE | UPDATE | DELETE
  final String entityTable;
  final String? entityId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final String status;       // pending | synced | failed
  final int retryCount;
  final String? lastError;

  const SyncQueueEntry({
    this.id,
    required this.actionType,
    required this.entityTable,
    this.entityId,
    required this.payload,
    required this.createdAt,
    required this.status,
    required this.retryCount,
    this.lastError,
  });

  factory SyncQueueEntry.fromMap(Map<String, dynamic> m) => SyncQueueEntry(
        id: m['id'] as int?,
        actionType: m['action_type'] as String,
        entityTable: m['entity_table'] as String,
        entityId: m['entity_id'] as String?,
        payload: jsonDecode(m['payload_json'] as String? ?? '{}')
            as Map<String, dynamic>,
        createdAt: DateTime.parse(m['created_at'] as String),
        status: m['status'] as String,
        retryCount: m['retry_count'] as int,
        lastError: m['last_error'] as String?,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'action_type': actionType,
        'entity_table': entityTable,
        'entity_id': entityId,
        'payload_json': jsonEncode(payload),
        'created_at': createdAt.toIso8601String(),
        'status': status,
        'retry_count': retryCount,
        'last_error': lastError,
      };
}

// ── Sync Engine ───────────────────────────────────────────────────────────────

class SyncEngine {
  SyncEngine._();
  static final SyncEngine instance = SyncEngine._();

  bool _initialized = false;
  bool _isSyncing  = false;
  StreamSubscription<ConnectivityStatus>? _connectivitySub;

  // ── Initialize ──────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _ensureTable();

    // Auto-drain queue when connectivity returns
    _connectivitySub = ConnectivityService.instance.onStatusChange.listen(
      (status) {
        if (status.isOnline) {
          _log('Connectivity restored — draining sync queue...');
          drainQueue();
        }
      },
    );
  }

  // ── Create the queue table if it doesn't exist ──────────────────────────────

  Future<void> _ensureTable() async {
    final db = await AppDatabase.instance.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_kTable (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type  TEXT    NOT NULL,
        entity_table TEXT    NOT NULL,
        entity_id    TEXT,
        payload_json TEXT,
        created_at   TEXT    NOT NULL,
        status       TEXT    NOT NULL DEFAULT 'pending',
        retry_count  INTEGER NOT NULL DEFAULT 0,
        last_error   TEXT
      )
    ''');
  }

  // ── Queue a mutation ────────────────────────────────────────────────────────

  /// Queue an offline mutation. Safe to call even when online.
  Future<int> queueMutation({
    required String actionType,
    required String entityTable,
    String? entityId,
    Map<String, dynamic> payload = const {},
  }) async {
    final db = await AppDatabase.instance.database;
    final entry = SyncQueueEntry(
      actionType: actionType,
      entityTable: entityTable,
      entityId: entityId,
      payload: payload,
      createdAt: DateTime.now(),
      status: 'pending',
      retryCount: 0,
    );
    final id = await db.insert(_kTable, entry.toMap());
    _log('Queued mutation #$id: $actionType on $entityTable');

    // If online, attempt immediate sync
    if (ConnectivityService.instance.isOnline) {
      drainQueue(); // fire and forget
    }
    return id;
  }

  /// Process all pending entries in FIFO order.
  /// Uses exponential backoff on failure.
  Future<void> syncAll() => drainQueue();

  Future<void> drainQueue() async {
    if (_isSyncing) return; // prevent parallel drains
    _isSyncing = true;
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query(
        _kTable,
        where: 'status = ? AND retry_count < ?',
        whereArgs: ['pending', _kMaxRetries],
        orderBy: 'created_at ASC',
      );

      for (final row in rows) {
        final entry = SyncQueueEntry.fromMap(row);
        await _processEntry(db, entry);
      }
    } finally {
      _isSyncing = false;
    }
  }

  // ── Process a single queue entry ────────────────────────────────────────────

  Future<void> _processEntry(Database db, SyncQueueEntry entry) async {
    try {
      // ── Simulate sync to remote API ──
      // In production, replace this with actual Dio/HTTP call:
      //   await dio.post('/api/sync', data: entry.payload);
      await _simulateNetworkSync(entry);

      // Mark as synced
      await db.update(
        _kTable,
        {'status': 'synced'},
        where: 'id = ?',
        whereArgs: [entry.id],
      );
      _log('Synced mutation #${entry.id}: ${entry.actionType} on ${entry.entityTable}');
    } catch (e) {
      final newRetryCount = entry.retryCount + 1;
      final backoffSecs = _backoffSeconds(newRetryCount);
      _log('Sync failed for #${entry.id} (attempt $newRetryCount/$_kMaxRetries): $e');
      _log('Next retry in ${backoffSecs}s...');

      await db.update(
        _kTable,
        {
          'retry_count': newRetryCount,
          'last_error': e.toString(),
          'status': newRetryCount >= _kMaxRetries ? 'failed' : 'pending',
        },
        where: 'id = ?',
        whereArgs: [entry.id],
      );

      // Exponential backoff delay
      await Future.delayed(Duration(seconds: backoffSecs));
    }
  }

  /// Exponential backoff: 1s, 2s, 4s, 8s, 16s (capped at 60s).
  int _backoffSeconds(int attempt) =>
      (1 << (attempt - 1)).clamp(1, 60);

  /// Simulates a network sync call. Replace with real API integration.
  Future<void> _simulateNetworkSync(SyncQueueEntry entry) async {
    await Future.delayed(const Duration(milliseconds: 100));
    // Uncomment to simulate occasional failures for testing:
    // if (entry.retryCount == 0) throw Exception('Simulated network error');
  }

  // ── Queue Stats ─────────────────────────────────────────────────────────────

  Future<Map<String, int>> getQueueStats() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT status, COUNT(*) as count
      FROM $_kTable
      GROUP BY status
    ''');
    return {for (final r in rows) r['status'] as String: r['count'] as int};
  }

  /// Clear all synced entries (housekeeping).
  Future<int> clearSynced() async {
    final db = await AppDatabase.instance.database;
    return db.delete(_kTable, where: 'status = ?', whereArgs: ['synced']);
  }

  void _log(String msg) {
    // ignore: avoid_print
    print('[SyncEngine] $msg');
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}

// ── Riverpod Providers ─────────────────────────────────────────────────────────

class SyncEngineNotifier extends StateNotifier<Map<String, int>> {
  SyncEngineNotifier() : super({}) {
    _init();
  }

  Future<void> _init() async {
    await SyncEngine.instance.initialize();
    await _refresh();
  }

  Future<void> _refresh() async {
    state = await SyncEngine.instance.getQueueStats();
  }

  Future<void> queueMutation({
    required String actionType,
    required String entityTable,
    String? entityId,
    Map<String, dynamic> payload = const {},
  }) async {
    await SyncEngine.instance.queueMutation(
      actionType: actionType,
      entityTable: entityTable,
      entityId: entityId,
      payload: payload,
    );
    await _refresh();
  }

  Future<void> drainQueue() async {
    await SyncEngine.instance.drainQueue();
    await _refresh();
  }
}

/// Provider for queue statistics and triggering sync operations.
final syncEngineProvider =
    StateNotifierProvider<SyncEngineNotifier, Map<String, int>>(
        (ref) => SyncEngineNotifier());
