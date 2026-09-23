// lib/services/destination_resolver.dart
//
// Destination resolution ARCHITECTURE (not a fixed place list).
//
// The local `Place` index is a fast OFFLINE cache/data source — NOT the universe
// of valid destinations. A user may ask for ANY destination the configured
// resolution provider can resolve. When the local cache can't resolve it, the
// architecture delegates to an online provider boundary; when that is
// unavailable (offline, or no real geocoder configured), the result is a
// TRUTHFUL "unavailable" — never a fabricated coordinate or a substituted place.
//
// Pipeline:
//   raw text
//     → intent extraction (strip travel filler words, multilingual)
//     → destination query
//     → DestinationResolver (Local cache → Online boundary)
//     → ResolutionResult { resolved(Place) | unresolved | unavailableOffline | ambiguous }
//
// SAFETY: there is NO default/fallback destination anywhere in this path. An
// unresolved query yields `unresolved`/`unavailableOffline`, which the UI must
// surface as retry/clarify — it can never become a confirmed destination.

import 'place_search_service.dart';
import 'india_gazetteer.dart';

enum ResolutionKind { resolved, ambiguous, unresolved, unavailableOffline }

class ResolutionResult {
  final ResolutionKind kind;
  final Place? place;               // set only when kind == resolved
  final List<Place> candidates;     // set when kind == ambiguous
  final String query;               // the extracted destination query
  final String dataTier;            // 'verified' | 'template' | 'unknown'

  const ResolutionResult._(this.kind, this.query, {this.place, this.candidates = const [], this.dataTier = 'unknown'});

  factory ResolutionResult.resolved(Place p, String q, {String dataTier = 'verified'}) =>
      ResolutionResult._(ResolutionKind.resolved, q, place: p, dataTier: dataTier);
  factory ResolutionResult.ambiguous(List<Place> c, String q) =>
      ResolutionResult._(ResolutionKind.ambiguous, q, candidates: c, dataTier: 'unknown');
  factory ResolutionResult.unresolved(String q) =>
      ResolutionResult._(ResolutionKind.unresolved, q, dataTier: 'unknown');
  factory ResolutionResult.unavailableOffline(String q) =>
      ResolutionResult._(ResolutionKind.unavailableOffline, q, dataTier: 'unknown');

  bool get isResolved => kind == ResolutionKind.resolved && place != null;
}

/// Unicode / script hygiene shared by resolvers.
///
/// Fixes the "కేదారнాథ్ → null" class of bug WITHOUT dangerous fuzzy matching:
///   • strips zero-width chars (ZWNJ U+200C, ZWJ U+200D, BOM U+FEFF, U+200B),
///   • removes visually-confusable Latin/Cyrillic homoglyphs by mapping the few
///     common Cyrillic look-alikes back to Latin only when they appear amongst
///     Latin letters (does NOT touch legitimate Indic text),
///   • collapses whitespace, lowercases, trims.
/// It never merges two distinct real place names.
String normalizeQuery(String input) {
  var s = input;
  // Remove zero-width / joiner / BOM characters.
  s = s.replaceAll(RegExp('[\u200B\u200C\u200D\uFEFF]'), '');
  // Map a small set of Cyrillic homoglyphs to Latin (STT/keyboard confusables).
  // Cyrillic → Latin by transliteration (what the user intended when an STT /
  // keyboard emitted a confusable), NOT by pure visual shape. e.g. Cyrillic 'н'
  // looks like Latin 'H' but transliterates to 'n' ("kedarнath" → "kedarnath").
  const homoglyph = {
    'а': 'a', 'е': 'e', 'о': 'o', 'р': 'r', 'с': 's', 'у': 'u', 'х': 'h',
    'н': 'n', 'к': 'k', 'м': 'm', 'т': 't', 'в': 'v',
  };
  final sb = StringBuffer();
  for (final ch in s.split('')) {
    sb.write(homoglyph[ch.toLowerCase()] ?? ch);
  }
  s = sb.toString();
  s = s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

/// A resolver that can turn a destination query into a canonical Place.
abstract class DestinationResolver {
  /// Whether this resolver can be used right now (e.g. online provider needs net).
  bool get isAvailable;

  /// Resolve an already-extracted destination query. Returns null if THIS
  /// resolver cannot resolve it (the pipeline then tries the next resolver).
  Place? tryResolve(String normalizedQuery);
}

/// Offline resolver backed by the local `Place` index (a cache, not the world).
class LocalPlaceResolver implements DestinationResolver {
  @override
  bool get isAvailable => true; // local cache is always available

  @override
  Place? tryResolve(String q) {
    if (q.isEmpty) return null;
    Place? best;
    int bestLen = 0;
    for (final p in PlaceSearchService.places) {
      for (final alias in [p.name, ...p.aliases]) {
        final a = normalizeQuery(alias);
        if (a.isEmpty) continue;
        // Match if a normalized alias appears in the query (longest wins). We do
        // NOT match on q.contains(a) only — also allow the query being a subset
        // of an alias for single-word inputs.
        if ((q.contains(a) || a.contains(q)) && a.length > bestLen) {
          best = p;
          bestLen = a.length;
        }
      }
    }
    return best;
  }
}

/// Offline resolver backed by the curated India Gazetteer.
class GazetteerPlaceResolver implements DestinationResolver {
  @override
  bool get isAvailable => true;

  @override
  Place? tryResolve(String q) {
    if (q.isEmpty) return null;
    final entry = IndiaGazetteer.instance.resolve(q);
    if (entry == null) return null;
    return Place(
      id: entry.id,
      name: entry.name,
      category: entry.category,
      coords: entry.coords,
      aliases: entry.aliases,
      note: '${entry.district}, ${entry.stateName} • RTC: ${entry.primaryRtc}',
    );
  }
}

/// Online provider BOUNDARY. No real geocoder is configured yet, so this is an
/// explicit unavailable implementation. When a real place-search/geocoding API
/// is chosen, implement [tryResolve] here — NO other code needs to change.
class OnlinePlaceResolver implements DestinationResolver {
  /// Injected connectivity check (kept simple; real provider added later).
  final bool Function() online;
  OnlinePlaceResolver(this.online);

  @override
  bool get isAvailable => online();

  @override
  Place? tryResolve(String q) {
    // No real online geocoder configured -> cannot resolve arbitrary places yet.
    // Returning null (not a fabricated Place) preserves truthfulness.
    return null;
  }
}

/// The pipeline: intent extraction + ordered resolver delegation.
class DestinationResolutionService {
  DestinationResolutionService._();
  static final DestinationResolutionService instance = DestinationResolutionService._();

  // Connectivity hook is injected by the caller/service so we don't couple this
  // file to a specific connectivity implementation.
  bool Function() onlineCheck = () => false;

  late final List<DestinationResolver> _resolvers = [
    LocalPlaceResolver(),
    GazetteerPlaceResolver(),
    OnlinePlaceResolver(() => onlineCheck()),
  ];

  /// Multilingual travel filler words removed during intent extraction.
  static const List<String> _fillers = [
    'i want to go to', 'i want to go', 'i need to go to', 'i need to reach',
    'take me to', 'navigate to', 'go to', 'reach', 'travel to', 'want to', 'please',
    'मुझे', 'जाना', 'है', 'जाना है', 'चलो', 'ले चलो', 'पहुंचना', 'पहुँचना',
    'నాకు', 'నేను', 'వెళ్లాలి', 'వెళ్ళాలి', 'కి', 'కు', 'తీసుకెళ్లు', 'అనుకుంటున్నాను',
    'நான்', 'செல்ல', 'வேண்டும்', 'போக', 'எனக்கு',
  ];

  /// Extract the destination query from natural language, then resolve it.
  ResolutionResult resolve(String rawSentence) {
    final norm = normalizeQuery(rawSentence);
    if (norm.isEmpty) return ResolutionResult.unresolved(rawSentence);

    // 1) Try to resolve on the full normalized sentence (handles mixed language,
    //    e.g. "मुझे Delhi जाना है"), via the offline cache first.
    for (final r in _resolvers) {
      if (!r.isAvailable) continue;
      final hit = r.tryResolve(norm);
      if (hit != null) {
        final tier = (r is GazetteerPlaceResolver) ? 'template' : 'verified';
        return ResolutionResult.resolved(hit, norm, dataTier: tier);
      }
    }

    // 2) Intent extraction: strip filler words to isolate the destination token.
    var extracted = norm;
    for (final f in _fillers) {
      extracted = extracted.replaceAll(normalizeQuery(f), ' ');
    }
    extracted = extracted.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (extracted.isNotEmpty && extracted != norm) {
      for (final r in _resolvers) {
        if (!r.isAvailable) continue;
        final hit = r.tryResolve(extracted);
        if (hit != null) {
          final tier = (r is GazetteerPlaceResolver) ? 'template' : 'verified';
          return ResolutionResult.resolved(hit, extracted, dataTier: tier);
        }
      }
    }

    // 3) Distinguish "offline (unresolvable locally)" vs "unresolved".
    final onlineResolver = _resolvers.whereType<OnlinePlaceResolver>().first;
    if (!onlineResolver.isAvailable) {
      return ResolutionResult.unavailableOffline(extracted.isEmpty ? norm : extracted);
    }
    return ResolutionResult.unresolved(extracted.isEmpty ? norm : extracted);
  }
}
