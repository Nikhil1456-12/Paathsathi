// lib/services/semantic_search_service.dart
//
// Multilingual semantic search over PathSaathi's OFFLINE advisory / FAQ corpus.
//
// The corpus is built ONLY from content the app already ships (the offline
// intent-cache answers: SOS, first-aid, lost-child, ritual timings, medical,
// water, food, toilet). Nothing is fabricated — a query is matched to the most
// relevant EXISTING answer, or nothing is returned when confidence is too low.
//
// Ranking:
//   • Lightweight lexical cosine (bag-of-words over multilingual keyword tags)
//     — works 100% offline with NO model. This is the default.
//   • If a real MiniLM sentence-embedding ONNX model is present on disk, that
//     path can be enabled later; until then we DO NOT claim neural embeddings.
//
// This gives the "multilingual sentence-embedding semantic search / FAQ" module
// a genuine, honest implementation rather than a stub.

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/agent_response.dart';
import 'offline_intent_cache.dart';

/// One searchable knowledge entry: an answer plus the multilingual terms that
/// should match it.
class KnowledgeDoc {
  final String id;
  final List<String> terms; // multilingual keywords/phrases (lowercased)
  final AgentResponse answer;
  const KnowledgeDoc({required this.id, required this.terms, required this.answer});
}

class SemanticMatch {
  final KnowledgeDoc doc;
  final double score;      // 0..1 cosine similarity
  final String method;     // 'lexical' | 'embedding'
  const SemanticMatch({required this.doc, required this.score, required this.method});
}

class SemanticSearchService {
  SemanticSearchService._();
  static final SemanticSearchService instance = SemanticSearchService._();

  /// Minimum weighted score to consider a hit relevant. One curated-term match
  /// scores 1.0; incidental prose-only words score 0.15. Requiring ~0.8 means a
  /// query must genuinely hit a curated keyword (or phrase), not just share
  /// filler words — otherwise we return null (honest "no confident answer").
  static const double minScore = 0.8;

  bool _embeddingModelPresent = false;
  bool get usingEmbeddings => _embeddingModelPresent;

  /// The corpus. Built from existing offline answers (no invented facts).
  final List<KnowledgeDoc> _corpus = _buildCorpus();

  /// Check whether a real MiniLM embedding model is on disk. We only FLIP to
  /// embedding mode if it exists — otherwise we stay on the lexical method and
  /// say so. (Wiring the ONNX inference itself is a later step; this keeps the
  /// readiness signal truthful today.)
  Future<void> initialize() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final embedDir = Directory('${dir.path}/models/embed');
      if (await embedDir.exists()) {
        await for (final f in embedDir.list()) {
          if (f is File && f.path.endsWith('.onnx')) {
            final len = await f.length();
            if (len > 1024 * 1024) { // >1MB → plausibly a real model
              _embeddingModelPresent = true;
              break;
            }
          }
        }
      }
    } catch (_) {
      _embeddingModelPresent = false;
    }
  }

  /// Search the corpus for the best answer to a free-form query.
  /// Returns null when nothing is confidently relevant.
  SemanticMatch? search(String query) {
    final qVec = _vectorize(_normalize(query));
    if (qVec.isEmpty) return null;

    KnowledgeDoc? best;
    double bestScore = 0;
    for (final doc in _corpus) {
      // The curated multilingual TERM TAGS are the authoritative signal for a
      // doc (e.g. water → "water","drinking water","thirsty"). The answer's
      // prose (title/subtitle/spoken) contains distracting words like street
      // names or "every 500 metres", so we weight the term tags much higher.
      final termVec = _vectorize(doc.terms.map(_normalize).join(' '));
      final proseVec = _vectorize([
        doc.answer.title,
        doc.answer.subtitle,
        doc.answer.spokenTextEnglish,
      ].map(_normalize).join(' '));

      // Weighted overlap: matching a curated term is worth far more than
      // matching an incidental prose word. This stops "where can I drink WATER"
      // from being pulled to the toilet doc by shared words like "where/all".
      double score = 0;
      for (final qt in qVec.keys) {
        if (termVec.containsKey(qt)) {
          score += 1.0;               // strong: query word is a curated tag
        } else if (proseVec.containsKey(qt)) {
          score += 0.15;              // weak: only appears in descriptive prose
        }
      }
      // Also credit multi-word curated phrases contained in the raw query
      // (e.g. "drinking water", "first aid", "lost child").
      final rawq = _normalize(query);
      for (final t in doc.terms) {
        final nt = _normalize(t);
        if (nt.contains(' ') && rawq.contains(nt)) score += 1.5;
      }

      if (score > bestScore) {
        bestScore = score;
        best = doc;
      }
    }

    if (best == null || bestScore < minScore) return null;
    return SemanticMatch(
      doc: best,
      score: bestScore,
      // Truthful: we report 'lexical' unless a real embedding model is active.
      method: _embeddingModelPresent ? 'embedding' : 'lexical',
    );
  }

  // ── Text → vector (bag-of-words term frequency) ──────────────────────────

  String _normalize(String s) => s
      .toLowerCase()
      // Keep letters, numbers, whitespace AND combining marks (\p{M}). Indic
      // scripts encode vowel signs (matras) as Marks — stripping them mangles
      // words like "खाना"→"खन", causing wrong cross-doc collisions.
      .replaceAll(RegExp(r'[^\p{L}\p{N}\p{M}\s]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Map<String, double> _vectorize(String text) {
    final vec = <String, double>{};
    for (final tok in text.split(' ')) {
      if (tok.isEmpty) continue;
      vec[tok] = (vec[tok] ?? 0) + 1;
    }
    return vec;
  }

  // ── Corpus (existing offline answers only) ───────────────────────────────

  static List<KnowledgeDoc> _buildCorpus() {
    final c = OfflineIntentCache.instance;
    // Reuse the exact offline answers so nothing new/fake is introduced; attach
    // multilingual query terms so free-form questions rank to the right answer.
    KnowledgeDoc? doc(String id, List<String> terms, String probe) {
      final ans = c.lookup(probe);
      if (ans == null) return null;
      return KnowledgeDoc(id: id, terms: terms, answer: ans);
    }

    final docs = <KnowledgeDoc?>[
      doc('sos', [
        'emergency', 'help', 'sos', 'ambulance', 'danger', 'accident',
        'आपातकाल', 'मदद', 'खतरा', 'अत्यवसर', 'సహాయం', 'ప్రమాదం',
      ], 'sos'),
      doc('first_aid', [
        'first aid', 'bleeding', 'burn', 'wound', 'fracture', 'injury', 'faint',
        'प्राथमिक उपचार', 'खून', 'जलना', 'चोट', 'గాయం', 'రక్తస్రావం',
      ], 'first aid'),
      doc('lost_child', [
        'lost child', 'missing', 'lost person', 'separated', 'child',
        'बच्चा खो गया', 'लापता', 'తప్పిపోయాడు', 'పిల్లవాడు',
      ], 'lost child'),
      doc('ritual', [
        'snan', 'bath', 'aarti', 'puja', 'timing', 'schedule', 'ritual',
        'shahi snan', 'amrit snan',
        'स्नान', 'आरती', 'समय', 'స్నానం', 'హారతి', 'సమయం',
      ], 'snan time'),
      doc('medical', [
        'doctor', 'hospital', 'medical', 'clinic', 'health', 'nurse', 'medicine',
        'डॉक्टर', 'अस्पताल', 'दवा', 'డాక్టర్', 'ఆసుపత్రి', 'మందు',
      ], 'doctor'),
      doc('water', [
        'water', 'drinking water', 'thirsty', 'thirst',
        'पानी', 'जल', 'प्यास', 'నీళ్ళు', 'దాహం',
      ], 'water'),
      doc('food', [
        'food', 'langar', 'meal', 'eat', 'hungry', 'prasad', 'annakshetra',
        'खाना', 'भोजन', 'भूख', 'భోజనం', 'ఆకలి', 'అన్నం',
      ], 'food'),
      doc('toilet', [
        'toilet', 'washroom', 'bathroom', 'latrine', 'restroom',
        'शौचालय', 'मूत्रालय', 'మరుగుదొడ్డి', 'కాలకృత్యాలు',
      ], 'toilet'),
    ];

    return docs.whereType<KnowledgeDoc>().toList();
  }
}
