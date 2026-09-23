// lib/widgets/hybrid_tile_provider.dart
//
// A flutter_map [TileProvider] that fetches each tile from the network first
// and, if that fails (offline, timeout, 4xx/5xx), falls back to the same tile
// on local disk (the cache TileCacheService writes to). This gives the map
// PER-TILE resilience on flaky connections at large events: tiles that can be
// fetched live are fresh; tiles that can't fall back to whatever was
// pre-downloaded, instead of showing broken/blank squares.
//
// Stretch goal (opportunistic caching): every tile successfully fetched from
// the network is written to the local cache, so repeated online viewing
// gradually fills the offline cache for free.
//
// Honesty: when BOTH network and cache miss, we return a fully transparent tile
// (flutter_map's transparentImage) rather than a fake/placeholder map image, so
// uncovered areas simply show the map background — never invented streets.

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

/// Tile provider that prefers live network tiles but transparently falls back
/// to on-disk cached tiles per tile. [cacheRoot] is the directory whose layout
/// is `<cacheRoot>/{z}/{x}/{y}.png` (matches TileCacheService).
class HybridTileProvider extends TileProvider {
  HybridTileProvider({
    required this.cacheRoot,
    this.writeThrough = true,
    Map<String, String>? headers,
    // Always hand the base class a MUTABLE copy — flutter_map's TileLayer
    // injects 'User-Agent' into headers, which throws on a const/unmodifiable
    // map. Copying defends against that regardless of what the caller passes.
  }) : super(headers: {...?headers});

  /// Absolute path to the local tile cache root (may be null if unknown).
  final String? cacheRoot;

  /// When true, tiles fetched from the network are also written to the local
  /// cache (opportunistic offline pre-fill).
  final bool writeThrough;

  final http.Client _client = http.Client();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    final localPath = cacheRoot == null
        ? null
        : '$cacheRoot/${coordinates.z}/${coordinates.x}/${coordinates.y}.png';
    return _NetworkOrFileImage(
      url: url,
      localPath: localPath,
      headers: headers,
      client: _client,
      writeThrough: writeThrough,
    );
  }

  @override
  Future<void> dispose() async {
    _client.close();
    super.dispose();
  }
}

/// ImageProvider: network-first, disk-fallback, transparent-on-total-miss.
@immutable
class _NetworkOrFileImage extends ImageProvider<_NetworkOrFileImage> {
  const _NetworkOrFileImage({
    required this.url,
    required this.localPath,
    required this.headers,
    required this.client,
    required this.writeThrough,
  });

  final String url;
  final String? localPath;
  final Map<String, String> headers;
  final http.Client client;
  final bool writeThrough;

  @override
  Future<_NetworkOrFileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_NetworkOrFileImage>(this);

  @override
  ImageStreamCompleter loadImage(
      _NetworkOrFileImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: 1.0,
      debugLabel: url,
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    // 1) Try the network (with a short timeout for the flaky middle ground).
    try {
      final resp = await client
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        // Opportunistically persist to the local cache for future offline use.
        if (writeThrough && localPath != null) {
          unawaited(_writeCache(localPath!, resp.bodyBytes));
        }
        final buffer = await ui.ImmutableBuffer.fromUint8List(resp.bodyBytes);
        return await decode(buffer);
      }
    } catch (_) {
      // fall through to disk
    }

    // 2) Network failed — try the on-disk cached tile.
    if (localPath != null) {
      try {
        final f = File(localPath!);
        if (await f.exists()) {
          final bytes = await f.readAsBytes();
          if (bytes.isNotEmpty) {
            final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
            return await decode(buffer);
          }
        }
      } catch (_) {
        // fall through to transparent
      }
    }

    // 3) Total miss — transparent tile (never a fabricated map image).
    return decode(
        await ui.ImmutableBuffer.fromUint8List(TileProvider.transparentImage));
  }

  Future<void> _writeCache(String path, Uint8List bytes) async {
    try {
      final f = File(path);
      final dir = f.parent;
      if (!await dir.exists()) await dir.create(recursive: true);
      await f.writeAsBytes(bytes, flush: false);
    } catch (_) {
      // Best-effort only; never let cache writes affect rendering.
    }
  }

  @override
  bool operator ==(Object other) =>
      other is _NetworkOrFileImage &&
      other.url == url &&
      other.localPath == localPath;

  @override
  int get hashCode => Object.hash(url, localPath);
}
