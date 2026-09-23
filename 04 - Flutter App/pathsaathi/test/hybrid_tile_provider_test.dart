// test/hybrid_tile_provider_test.dart
//
// Regression guard for the "Cannot modify unmodifiable map" crash: flutter_map
// injects the 'User-Agent' into a TileProvider's headers map at render time, so
// HybridTileProvider MUST expose a mutable headers map even when the caller
// passes a const map.

import 'package:flutter_test/flutter_test.dart';
import 'package:pathsaathi/widgets/hybrid_tile_provider.dart';

void main() {
  test('headers map is mutable even when constructed from a const map', () {
    final provider = HybridTileProvider(
      cacheRoot: '/tmp/tiles',
      headers: const {'User-Agent': 'test'},
    );
    // This is exactly what flutter_map's TileLayer does internally — it must
    // not throw.
    expect(() => provider.headers['User-Agent'] = 'injected', returnsNormally);
    expect(provider.headers['User-Agent'], 'injected');
  });

  test('headers is mutable when no headers are passed', () {
    final provider = HybridTileProvider(cacheRoot: null);
    expect(() => provider.headers['User-Agent'] = 'x', returnsNormally);
  });
}
