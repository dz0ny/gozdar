// Feature matching for drone photo alignment.
//
// The matching steps follow OpenSfM (BSD 2-Clause, see third_party/NOTICE).
// The steps are a ratio test, a symmetric check and a robust RANSAC fit.
// The corner detector and the descriptor are small Dart versions of FAST and
// BRIEF. They need no native code.

import 'dart:math' as math;
import 'dart:typed_data';

/// A corner with a binary descriptor of 8 words of 32 bits.
class Keypoint {
  final double x;
  final double y;
  final double score;
  final Uint32List descriptor;
  const Keypoint(this.x, this.y, this.score, this.descriptor);
}

/// A similarity transform: q = a * p + b, with complex numbers.
class Similarity {
  final double ar;
  final double ai;
  final double br;
  final double bi;
  const Similarity(this.ar, this.ai, this.br, this.bi);

  (double, double) apply(double x, double y) =>
      (ar * x - ai * y + br, ai * x + ar * y + bi);
}

class FeatureMatch {
  /// Number of inlier matches.
  final int inliers;

  /// Share of inliers among all matches.
  final double inlierRatio;

  /// Shift of content at the centre of the inliers, in cells.
  final double shiftX;
  final double shiftY;

  /// Rotation from B to A, radians, positive counter-clockwise.
  final double angle;

  /// Scale from B to A. Below 1 means B content is too large.
  final double scale;

  /// Centre of the inliers in B, in cells. The shift is measured here.
  final double centreX;
  final double centreY;

  const FeatureMatch(
    this.inliers,
    this.inlierRatio,
    this.shiftX,
    this.shiftY,
    this.angle,
    this.scale,
    this.centreX,
    this.centreY,
  );
}

const _circle = <(int, int)>[
  (0, -3), (1, -3), (2, -2), (3, -1), (3, 0), (3, 1), (2, 2), (1, 3),
  (0, 3), (-1, 3), (-2, 2), (-3, 1), (-3, 0), (-3, -1), (-2, -2), (-1, -3),
];

const _briefRadius = 15;

/// 256 point pairs inside a 31 x 31 window. The seed is fixed.
final List<(int, int, int, int)> _briefPairs = () {
  final rnd = math.Random(20240611);
  int r() {
    // Sum of two values gives a bell-shaped spread around the centre.
    return ((rnd.nextInt(2 * _briefRadius + 1) +
                rnd.nextInt(2 * _briefRadius + 1)) ~/
            2) -
        _briefRadius;
  }

  return [for (var i = 0; i < 256; i++) (r(), r(), r(), r())];
}();

/// Finds up to [maxPoints] corners in [gray]. Cells below 0 are invalid.
List<Keypoint> detectKeypoints(
  Float32List gray,
  int w,
  int h, {
  int maxPoints = 400,
  double threshold = 0.07,
}) {
  final smooth = _boxBlur(gray, w, h);
  final scores = Float32List(w * h);
  const m = _briefRadius + 1;
  for (var y = m; y < h - m; y++) {
    for (var x = m; x < w - m; x++) {
      final c = gray[y * w + x];
      if (c < 0) continue;
      scores[y * w + x] = _fastScore(gray, w, x, y, c, threshold);
    }
  }
  final found = <(double, int, int)>[];
  for (var y = m; y < h - m; y++) {
    for (var x = m; x < w - m; x++) {
      final s = scores[y * w + x];
      if (s <= 0) continue;
      var isMax = true;
      for (var dy = -2; dy <= 2 && isMax; dy++) {
        for (var dx = -2; dx <= 2; dx++) {
          if ((dx != 0 || dy != 0) && scores[(y + dy) * w + x + dx] > s) {
            isMax = false;
            break;
          }
        }
      }
      if (isMax && _windowValid(gray, w, x, y)) found.add((s.toDouble(), x, y));
    }
  }
  found.sort((a, b) => b.$1.compareTo(a.$1));
  return [
    for (final f in found.take(maxPoints))
      Keypoint(f.$2.toDouble(), f.$3.toDouble(), f.$1, _brief(smooth, w, f.$2, f.$3)),
  ];
}

bool _windowValid(Float32List g, int w, int x, int y) {
  const r = _briefRadius;
  return g[(y - r) * w + x - r] >= 0 &&
      g[(y - r) * w + x + r] >= 0 &&
      g[(y + r) * w + x - r] >= 0 &&
      g[(y + r) * w + x + r] >= 0;
}

/// FAST-9 style score: sum of differences over the longest arc, or 0.
double _fastScore(Float32List g, int w, int x, int y, double c, double t) {
  final diff = List<double>.filled(16, 0);
  for (var i = 0; i < 16; i++) {
    final p = g[(y + _circle[i].$2) * w + x + _circle[i].$1];
    if (p < 0) return 0;
    diff[i] = p - c;
  }
  var best = 0.0;
  for (final sign in [1.0, -1.0]) {
    var run = 0;
    var sum = 0.0;
    // Walk the circle twice to catch arcs that wrap around.
    for (var i = 0; i < 32; i++) {
      final d = diff[i % 16] * sign;
      if (d > t) {
        run++;
        sum += d;
        if (run >= 9 && sum > best) best = sum;
      } else {
        run = 0;
        sum = 0;
      }
    }
  }
  return best;
}

Float32List _boxBlur(Float32List g, int w, int h) {
  // Integral image, with invalid cells counted as 0.
  final integral = Float64List((w + 1) * (h + 1));
  for (var y = 0; y < h; y++) {
    var row = 0.0;
    for (var x = 0; x < w; x++) {
      final v = g[y * w + x];
      row += v < 0 ? 0 : v;
      integral[(y + 1) * (w + 1) + x + 1] = integral[y * (w + 1) + x + 1] + row;
    }
  }
  final out = Float32List(w * h);
  const r = 2;
  for (var y = r; y < h - r; y++) {
    for (var x = r; x < w - r; x++) {
      final a = integral[(y - r) * (w + 1) + x - r];
      final b = integral[(y - r) * (w + 1) + x + r + 1];
      final c = integral[(y + r + 1) * (w + 1) + x - r];
      final d = integral[(y + r + 1) * (w + 1) + x + r + 1];
      out[y * w + x] = ((d - b - c + a) / ((2 * r + 1) * (2 * r + 1))).toDouble();
    }
  }
  return out;
}

Uint32List _brief(Float32List smooth, int w, int x, int y) {
  final d = Uint32List(8);
  for (var i = 0; i < 256; i++) {
    final p = _briefPairs[i];
    if (smooth[(y + p.$2) * w + x + p.$1] < smooth[(y + p.$4) * w + x + p.$3]) {
      d[i >> 5] |= 1 << (i & 31);
    }
  }
  return d;
}

int _popcount(int v) {
  v = v - ((v >> 1) & 0x55555555);
  v = (v & 0x33333333) + ((v >> 2) & 0x33333333);
  return (((v + (v >> 4)) & 0x0F0F0F0F) * 0x01010101 >> 24) & 0xFF;
}

int _hamming(Uint32List a, Uint32List b) {
  var n = 0;
  for (var i = 0; i < 8; i++) {
    n += _popcount(a[i] ^ b[i]);
  }
  return n;
}

/// Matches with the ratio test and a symmetric check. Returns index pairs.
List<(int, int)> matchKeypoints(
  List<Keypoint> a,
  List<Keypoint> b, {
  double ratio = 0.8,
}) {
  (int, int, int) nearest(Keypoint q, List<Keypoint> set) {
    var best = 1 << 20, second = 1 << 20, bi = -1;
    for (var i = 0; i < set.length; i++) {
      final dist = _hamming(q.descriptor, set[i].descriptor);
      if (dist < best) {
        second = best;
        best = dist;
        bi = i;
      } else if (dist < second) {
        second = dist;
      }
    }
    return (bi, best, second);
  }

  final back = <int>[];
  for (final q in b) {
    back.add(nearest(q, a).$1);
  }
  final out = <(int, int)>[];
  for (var i = 0; i < a.length; i++) {
    final (j, best, second) = nearest(a[i], b);
    if (j < 0 || best > 80) continue;
    if (best >= ratio * second) continue;
    if (back[j] != i) continue;
    out.add((i, j));
  }
  return out;
}

/// Fits a similarity transform from B points to A points with RANSAC.
///
/// Returns null when too few matches agree. The shift is the content shift
/// at the centre of the inliers, in the units of the keypoint coordinates.
FeatureMatch? robustSimilarity(
  List<Keypoint> a,
  List<Keypoint> b,
  List<(int, int)> matches, {
  double tolerance = 2.5,
  int minInliers = 12,
  double minRatio = 0.3,
  int iterations = 300,
}) {
  if (matches.length < minInliers) return null;
  final rnd = math.Random(11);
  var bestInliers = <int>[];
  for (var it = 0; it < iterations; it++) {
    final i = rnd.nextInt(matches.length);
    final j = rnd.nextInt(matches.length);
    if (i == j) continue;
    final t = _fit2(a, b, matches[i], matches[j]);
    if (t == null) continue;
    // Reject wild scale and rotation. Nadir photos are close to rigid.
    final scale = math.sqrt(t.ar * t.ar + t.ai * t.ai);
    if (scale < 0.85 || scale > 1.15 || t.ai.abs() > 0.2) continue;
    final inl = <int>[];
    for (var k = 0; k < matches.length; k++) {
      final pb = b[matches[k].$2];
      final pa = a[matches[k].$1];
      final (qx, qy) = t.apply(pb.x, pb.y);
      if ((qx - pa.x) * (qx - pa.x) + (qy - pa.y) * (qy - pa.y) <=
          tolerance * tolerance) {
        inl.add(k);
      }
    }
    if (inl.length > bestInliers.length) bestInliers = inl;
  }
  if (bestInliers.length < minInliers) return null;
  final ratio = bestInliers.length / matches.length;
  if (ratio < minRatio) return null;

  final fit = _fitAll(a, b, [for (final k in bestInliers) matches[k]]);
  if (fit == null) return null;
  var cx = 0.0, cy = 0.0;
  for (final k in bestInliers) {
    cx += b[matches[k].$2].x;
    cy += b[matches[k].$2].y;
  }
  cx /= bestInliers.length;
  cy /= bestInliers.length;
  final (qx, qy) = fit.apply(cx, cy);
  return FeatureMatch(
    bestInliers.length,
    ratio,
    qx - cx,
    qy - cy,
    math.atan2(fit.ai, fit.ar),
    math.sqrt(fit.ar * fit.ar + fit.ai * fit.ai),
    cx,
    cy,
  );
}

Similarity? _fit2(
  List<Keypoint> a,
  List<Keypoint> b,
  (int, int) m1,
  (int, int) m2,
) {
  final p1 = b[m1.$2], p2 = b[m2.$2];
  final q1 = a[m1.$1], q2 = a[m2.$1];
  final dpx = p2.x - p1.x, dpy = p2.y - p1.y;
  final den = dpx * dpx + dpy * dpy;
  if (den < 100) return null; // Points too close give a poor fit.
  final dqx = q2.x - q1.x, dqy = q2.y - q1.y;
  final ar = (dqx * dpx + dqy * dpy) / den;
  final ai = (dqy * dpx - dqx * dpy) / den;
  return Similarity(
    ar,
    ai,
    q1.x - (ar * p1.x - ai * p1.y),
    q1.y - (ai * p1.x + ar * p1.y),
  );
}

/// Least-squares similarity over all matches (closed form).
Similarity? _fitAll(
  List<Keypoint> a,
  List<Keypoint> b,
  List<(int, int)> matches,
) {
  final n = matches.length;
  if (n < 2) return null;
  var mpx = 0.0, mpy = 0.0, mqx = 0.0, mqy = 0.0;
  for (final m in matches) {
    mpx += b[m.$2].x;
    mpy += b[m.$2].y;
    mqx += a[m.$1].x;
    mqy += a[m.$1].y;
  }
  mpx /= n;
  mpy /= n;
  mqx /= n;
  mqy /= n;
  var num1 = 0.0, num2 = 0.0, den = 0.0;
  for (final m in matches) {
    final px = b[m.$2].x - mpx, py = b[m.$2].y - mpy;
    final qx = a[m.$1].x - mqx, qy = a[m.$1].y - mqy;
    num1 += qx * px + qy * py;
    num2 += qy * px - qx * py;
    den += px * px + py * py;
  }
  if (den < 1e-9) return null;
  final ar = num1 / den, ai = num2 / den;
  return Similarity(
    ar,
    ai,
    mqx - (ar * mpx - ai * mpy),
    mqy - (ai * mpx + ar * mpy),
  );
}
