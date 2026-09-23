// lib/services/cache_manager.dart
//
// Cache-first read/write strategy for PathSaathi.
//
// Strategy:
//   READ  → Check SQLite → return cached data immediately
//           → if online: fetch fresh data in background → update SQLite → notify via Riverpod
//   WRITE → Write to SQLite immediately → queue network mutation via SyncEngine
//
// Data Freshness:
//   fresh    < 1 hour
//   stale    1–24 hours
//   expired  > 24 hours

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import 'connectivity_service.dart';
import 'sync_engine.dart';

// ── Data Freshness ────────────────────────────────────────────────────────────

enum DataFreshness { fresh, stale, expired }

extension DataFreshnessX on DataFreshness {
  String get label => switch (this) {
        DataFreshness.fresh   => 'Just updated',
        DataFreshness.stale   => 'Updated recently',
        DataFreshness.expired => 'May be outdated',
      };

  bool get needsRefresh => this != DataFreshness.fresh;
}

class CachedData<T> {
  final T data;
  final DateTime lastSyncedAt;
  final DataFreshness freshness;

  const CachedData({
    required this.data,
    required this.lastSyncedAt,
    required this.freshness,
  });

  /// Human-readable freshness string ("Updated 2h ago", "Last synced: Yesterday").
  String get freshnessLabel {
    final diff = DateTime.now().difference(lastSyncedAt);
    if (diff.inMinutes < 1) return 'Just updated';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Last synced: Yesterday';
    return 'Last synced: ${diff.inDays}d ago';
  }
}

// ── Cache Metadata Table ──────────────────────────────────────────────────────

const _kCacheMeta = 'cache_metadata';

// ── Cache Manager Singleton ───────────────────────────────────────────────────

class CacheManager {
  CacheManager._();
  static final CacheManager instance = CacheManager._();

  bool _initialized = false;

  // ── Initialize ──────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _ensureMetaTable();
    await SyncEngine.instance.initialize();
  }

  Future<void> _ensureMetaTable() async {
    final db = await AppDatabase.instance.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_kCacheMeta (
        key          TEXT PRIMARY KEY,
        last_sync    TEXT NOT NULL,
        record_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // ── Data Freshness ──────────────────────────────────────────────────────────

  Future<DataFreshness> getFreshness(String cacheKey) async {
    final syncedAt = await _getLastSync(cacheKey);
    if (syncedAt == null) return DataFreshness.expired;
    final age = DateTime.now().difference(syncedAt);
    if (age.inHours < 1) return DataFreshness.fresh;
    if (age.inHours < 24) return DataFreshness.stale;
    return DataFreshness.expired;
  }

  Future<DateTime?> _getLastSync(String key) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(_kCacheMeta,
        where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['last_sync'] as String);
  }

  Future<void> _markSynced(String key, int count) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      _kCacheMeta,
      {'key': key, 'last_sync': DateTime.now().toIso8601String(), 'record_count': count},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Cache-First Read ────────────────────────────────────────────────────────

  /// Cache-first read pattern:
  /// 1. Returns local SQLite data immediately.
  /// 2. If online and stale/expired, triggers background refresh.
  /// 3. Returns a CachedData wrapper with freshness info.
  ///
  /// [cacheKey]    - Unique key for cache metadata (e.g., 'buses', 'accommodations')
  /// [localFetch]  - Fetches data from SQLite
  /// [remoteFetch] - Fetches data from network (may be null if no remote)
  /// [localSave]   - Saves fresh network data to SQLite
  Future<CachedData<T>> read<T>({
    required String cacheKey,
    required Future<T> Function(Database db) localFetch,
    Future<T> Function()? remoteFetch,
    Future<void> Function(Database db, T data)? localSave,
  }) async {
    final db = await AppDatabase.instance.database;
    final data = await localFetch(db);
    final freshness = await getFreshness(cacheKey);
    final syncedAt = await _getLastSync(cacheKey) ?? DateTime.now();

    // Background refresh if stale/expired and online
    if (freshness.needsRefresh &&
        ConnectivityService.instance.isOnline &&
        remoteFetch != null &&
        localSave != null) {
      _backgroundRefresh(
        cacheKey: cacheKey,
        remoteFetch: remoteFetch,
        localSave: localSave,
        db: db,
      );
    }

    return CachedData(
      data: data,
      lastSyncedAt: syncedAt,
      freshness: freshness,
    );
  }

  void _backgroundRefresh<T>({
    required String cacheKey,
    required Future<T> Function() remoteFetch,
    required Future<void> Function(Database db, T data) localSave,
    required Database db,
  }) async {
    try {
      _log('Background refresh: $cacheKey');
      final freshData = await remoteFetch();
      await localSave(db, freshData);

      final count = (freshData is List) ? (freshData as List).length : 1;
      await _markSynced(cacheKey, count);
      _log('Background refresh complete: $cacheKey');
    } catch (e) {
      _log('Background refresh failed for $cacheKey: $e');
    }
  }

  // ── Offline-Safe Write ──────────────────────────────────────────────────────

  /// Offline-safe write:
  /// 1. Writes to local SQLite immediately.
  /// 2. Queues network mutation via SyncEngine.
  /// 3. Returns immediately — no wait for network.
  Future<void> write({
    required String actionType,
    required String entityTable,
    required String? entityId,
    required Map<String, dynamic> payload,
    required Future<void> Function(Database db) localWrite,
  }) async {
    final db = await AppDatabase.instance.database;

    // Write locally first (optimistic update)
    await localWrite(db);
    _log('Local write: $actionType on $entityTable ($entityId)');

    // Queue for remote sync
    await SyncEngine.instance.queueMutation(
      actionType: actionType,
      entityTable: entityTable,
      entityId: entityId,
      payload: payload,
    );
  }

  // ── Convenience Methods ─────────────────────────────────────────────────────

  /// Quick wrapper for simple list reads from SQLite.
  Future<CachedData<List<Map<String, dynamic>>>> readList({
    required String cacheKey,
    required String tableName,
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    return read<List<Map<String, dynamic>>>(
      cacheKey: cacheKey,
      localFetch: (db) => db.query(
        tableName,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
      ),
    );
  }

  /// Invalidate cache for a specific key.
  Future<void> invalidate(String key) async {
    final db = await AppDatabase.instance.database;
    await db.delete(_kCacheMeta, where: 'key = ?', whereArgs: [key]);
    _log('Invalidated cache for key: $key');
  }

  /// Store or update tier metadata for a cache key.
  Future<void> setCacheTier(String key, String tier) async {
    final db = await AppDatabase.instance.database;
    await db.execute('ALTER TABLE $_kCacheMeta ADD COLUMN tier TEXT').catchError((_) {});
    await db.update(_kCacheMeta, {'tier': tier}, where: 'key = ?', whereArgs: [key]);
  }

  /// Invalidate cache if stored tier doesn't match current tier.
  Future<void> invalidateIfTierMismatch(String key, String currentTier) async {
    final db = await AppDatabase.instance.database;
    await db.execute('ALTER TABLE $_kCacheMeta ADD COLUMN tier TEXT').catchError((_) {});
    final rows = await db.query(_kCacheMeta, where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isNotEmpty) {
      final cachedTier = rows.first['tier'] as String?;
      if (cachedTier != null && cachedTier != currentTier) {
        await invalidate(key);
        _log('Invalidated $key cache due to tier change: $cachedTier -> $currentTier');
      }
    }
  }

  void _log(String msg) {
    // ignore: avoid_print
    print('[CacheManager] $msg');
  }
}

// ── Riverpod Providers ─────────────────────────────────────────────────────────

/// State class for data loaded through the cache manager.
class CacheState<T> {
  final T? data;
  final DataFreshness freshness;
  final String freshnessLabel;
  final bool isLoading;
  final String? error;

  const CacheState({
    this.data,
    this.freshness = DataFreshness.expired,
    this.freshnessLabel = '',
    this.isLoading = false,
    this.error,
  });

  CacheState<T> copyWith({
    T? data,
    DataFreshness? freshness,
    String? freshnessLabel,
    bool? isLoading,
    String? error,
  }) =>
      CacheState(
        data: data ?? this.data,
        freshness: freshness ?? this.freshness,
        freshnessLabel: freshnessLabel ?? this.freshnessLabel,
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
      );
}

// Example: cached bus list provider
class CachedBusListNotifier
    extends StateNotifier<CacheState<List<Map<String, dynamic>>>> {
  CachedBusListNotifier() : super(const CacheState(isLoading: true)) {
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await CacheManager.instance.readList(
        cacheKey: 'buses',
        tableName: 'buses',
        orderBy: 'departure_time ASC',
      );
      state = CacheState(
        data: result.data,
        freshness: result.freshness,
        freshnessLabel: result.freshnessLabel,
        isLoading: false,
      );
    } catch (e) {
      state = CacheState(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => _load();
}

/// Cached bus list that shows freshness info (e.g., "Updated 2h ago").
final cachedBusListProvider = StateNotifierProvider<CachedBusListNotifier,
    CacheState<List<Map<String, dynamic>>>>(
  (ref) => CachedBusListNotifier(),
);
