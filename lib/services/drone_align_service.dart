import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'drone_features.dart';
import 'drone_photo_service.dart';

/// One photo resampled onto a north-up ground grid. Invalid cells hold -1.
class AlignPatch {
  final Float32List gray;
  final int w;
  final int h;

  /// Grid index of the first cell. A cell is [ground size] metres wide.
  final int ox;
  final int oy;

  const AlignPatch({
    required this.gray,
    required this.w,
    required this.h,
    required this.ox,
    required this.oy,
  });
}

class AlignJob {
  final List<AlignPatch> patches;

  /// Ground size of one cell, metres.
  final double cell;

  /// Largest shift to search, in cells.
  final int radius;

  const AlignJob(this.patches, this.cell, this.radius);
}

class AlignResult {
  /// Estimated position correction per photo, metres east and north.
  final List<double> dx;
  final List<double> dy;

  /// Heading correction per photo, degrees. Add it to the heading.
  final List<double> dHeadingDeg;

  /// Height scale per photo. Multiply the height by it.
  final List<double> heightScale;
  final int pairsTried;
  final int pairsUsed;

  const AlignResult(
    this.dx,
    this.dy,
    this.dHeadingDeg,
    this.heightScale,
    this.pairsTried,
    this.pairsUsed,
  );
}

class _Constraint {
  final int a;
  final int b;

  /// Content shift from B to A, metres, measured at point (mx, my).
  final double sx;
  final double sy;
  final double mx;
  final double my;

  /// Rotation from B to A in radians, and log of the scale from B to A.
  /// Null when the pair came from correlation, which fixes both at 0.
  final double? rot;
  final double? logScale;
  final double w;
  const _Constraint(
    this.a,
    this.b,
    this.sx,
    this.sy,
    this.mx,
    this.my,
    this.rot,
    this.logScale,
    this.w,
  );
}

/// Solves for position corrections from the overlap of neighbouring patches.
///
/// For a pair (A, B) the shift s maximises the correlation of B(P) with
/// A(P + s). Then dB - dA = s. The GPS position is a weak prior on every
/// photo. This keeps errors from adding up along a chain of photos.
AlignResult solveAlign(AlignJob job) {
  final patches = job.patches;
  final n = patches.length;
  final r = job.radius;
  final constraints = <_Constraint>[];
  var tried = 0;
  final cache = List<List<Keypoint>?>.filled(n, null);
  List<Keypoint> keypoints(int i) => cache[i] ??= _globalKeypoints(patches[i]);

  for (var i = 0; i < n; i++) {
    // Rank later photos by the size of the grid overlap and keep the best.
    final candidates = <(int, int)>[];
    for (var j = i + 1; j < n; j++) {
      final area = _overlapArea(patches[i], patches[j]);
      if (area > 0.25 * patches[i].w * patches[i].h) {
        candidates.add((area, j));
      }
    }
    candidates.sort((x, y) => y.$1.compareTo(x.$1));
    for (final c in candidates.take(5)) {
      tried++;
      // Features first. They work for large shifts. Correlation is the backup.
      final pa = patches[i], pb = patches[c.$2];
      final fm = _featureFit(keypoints(i), keypoints(c.$2));
      if (fm != null) {
        constraints.add(
          _Constraint(
            i,
            c.$2,
            fm.shiftX * job.cell,
            fm.shiftY * job.cell,
            fm.centreX * job.cell,
            fm.centreY * job.cell,
            fm.angle,
            math.log(fm.scale),
            (fm.inliers / 80).clamp(0.1, 1.0),
          ),
        );
        continue;
      }
      final res = _correlate(pa, pb, r);
      if (res != null) {
        // The shift refers to the middle of the overlap of the two patches.
        final mx = (math.max(pa.ox, pb.ox) + math.min(pa.ox + pa.w, pb.ox + pb.w)) / 2;
        final my = (math.max(pa.oy, pb.oy) + math.min(pa.oy + pa.h, pb.oy + pb.h)) / 2;
        constraints.add(
          _Constraint(
            i,
            c.$2,
            res.$1 * job.cell,
            res.$2 * job.cell,
            mx * job.cell,
            my * job.cell,
            null,
            null,
            res.$3,
          ),
        );
      }
    }
  }

  final centres = [
    for (final p in patches)
      ((p.ox + p.w / 2) * job.cell, (p.oy + p.h / 2) * job.cell),
  ];
  // Square of a typical half patch size, metres. It puts rotation and scale
  // in the same units as shifts: metres of error at the patch edge.
  final halves = [for (final p in patches) p.w * job.cell / 2]..sort();
  final span2 = math.pow(halves[halves.length ~/ 2], 2).toDouble();
  return _solveJoint(n, constraints, centres, span2, tried);
}

/// Solves shift, rotation and scale of every photo together.
///
/// Photo i draws ground point g at g + d_i + l_i (g - c_i) + r_i J(g - c_i),
/// with J a turn of 90 degrees counter-clockwise. A pair (A, B) measured at
/// point m gives three equations: the content shift s = e_A(m) - e_B(m), the
/// rotation r_A - r_B and the log scale l_A - l_B. Weak priors at 0 remove
/// the free choice. The GPS centres c_i then fix absolute rotation and scale.
AlignResult _solveJoint(
  int n,
  List<_Constraint> constraints,
  List<(double, double)> centres,
  double span2,
  int tried,
) {
  final dx = List<double>.filled(n, 0);
  final dy = List<double>.filled(n, 0);
  final rot = List<double>.filled(n, 0);
  final ls = List<double>.filled(n, 0);
  // The pose priors are weaker than the shift prior, so a bias shared by all
  // photos becomes a common rotation or scale, not a field of shifts.
  const priorD = 0.02;
  final priorR = 0.002 * span2, priorL = 0.002 * span2;

  // Error of photo i at point m without its own shift.
  (double, double) poseError(int i, double mx, double my) {
    final gx = mx - centres[i].$1, gy = my - centres[i].$2;
    return (ls[i] * gx - rot[i] * gy, ls[i] * gy + rot[i] * gx);
  }

  for (var iter = 0; iter < 200; iter++) {
    for (var i = 0; i < n; i++) {
      var nx = 0.0, ny = 0.0, nd = priorD;
      var nr = 0.0, dr = priorR;
      var nl = 0.0, dl = priorL;
      for (final c in constraints) {
        if (c.a != i && c.b != i) continue;
        final isA = c.a == i;
        final j = isA ? c.b : c.a;
        final sign = isA ? 1.0 : -1.0;
        final (ei, eiY) = poseError(i, c.mx, c.my);
        final (ej, ejY) = poseError(j, c.mx, c.my);
        // Residual that the pose of i must explain: s = e_A - e_B.
        final rx = sign * c.sx + dx[j] + ej - ei;
        final ry = sign * c.sy + dy[j] + ejY - eiY;
        nx += c.w * rx;
        ny += c.w * ry;
        nd += c.w;
        // Rotation and scale of i from the shift equation, by projection.
        final gx = c.mx - centres[i].$1, gy = c.my - centres[i].$2;
        final g2 = gx * gx + gy * gy;
        if (g2 > 1) {
          final tx = rx + ei - dx[i], ty = ry + eiY - dy[i];
          nr += c.w * (ty * gx - tx * gy);
          dr += c.w * g2;
          nl += c.w * (tx * gx + ty * gy);
          dl += c.w * g2;
        }
        if (c.rot != null) {
          nr += c.w * span2 * (rot[j] + sign * c.rot!);
          dr += c.w * span2;
          nl += c.w * span2 * (ls[j] + sign * c.logScale!);
          dl += c.w * span2;
        }
      }
      dx[i] = nx / nd;
      dy[i] = ny / nd;
      rot[i] = nr / dr;
      ls[i] = nl / dl;
    }
  }
  // d is the drawing error, so the position correction is its negative.
  // Content turned counter-clockwise means the heading was too small, and
  // content that is too large means the height was too large.
  return AlignResult(
    [for (final v in dx) -v],
    [for (final v in dy) -v],
    [for (final r in rot) r * 180 / math.pi],
    [for (final l in ls) math.exp(-l)],
    tried,
    constraints.length,
  );
}

/// Keypoints of [p] in global grid cells, so that two patches compare directly.
List<Keypoint> _globalKeypoints(AlignPatch p) => [
  for (final k in detectKeypoints(p.gray, p.w, p.h))
    Keypoint(k.x + p.ox, k.y + p.oy, k.score, k.descriptor),
];

/// Fits B onto A from matched features, or null when the match is weak.
FeatureMatch? _featureFit(List<Keypoint> a, List<Keypoint> b) {
  if (a.length < 12 || b.length < 12) return null;
  return robustSimilarity(a, b, matchKeypoints(a, b));
}

int _overlapArea(AlignPatch a, AlignPatch b) {
  final int w = math.min<int>(a.ox + a.w, b.ox + b.w) - math.max<int>(a.ox, b.ox);
  final int h = math.min<int>(a.oy + a.h, b.oy + b.h) - math.max<int>(a.oy, b.oy);
  return (w > 0 && h > 0) ? w * h : 0;
}

/// Returns (shiftX, shiftY, weight) in cells, or null when not trustworthy.
(double, double, double)? _correlate(AlignPatch a, AlignPatch b, int r) {
  const stride = 3;
  final side = 2 * r + 1;
  final score = Float64List(side * side)..fillRange(0, side * side, -2);

  // Cells of B that could overlap A for some shift.
  final x0 = math.max(b.ox, a.ox - r);
  final x1 = math.min(b.ox + b.w, a.ox + a.w + r);
  final y0 = math.max(b.oy, a.oy - r);
  final y1 = math.min(b.oy + b.h, a.oy + a.h + r);
  if (x1 - x0 < 8 || y1 - y0 < 8) return null;

  var minCount = 1 << 30;
  var maxCount = 0;
  for (var sy = -r; sy <= r; sy++) {
    for (var sx = -r; sx <= r; sx++) {
      var cnt = 0;
      double sa = 0, sb = 0, saa = 0, sbb = 0, sab = 0;
      for (var py = y0; py < y1; py += stride) {
        final ay = py + sy - a.oy;
        if (ay < 0 || ay >= a.h) continue;
        final by = py - b.oy;
        for (var px = x0; px < x1; px += stride) {
          final ax = px + sx - a.ox;
          if (ax < 0 || ax >= a.w) continue;
          final va = a.gray[ay * a.w + ax];
          if (va < 0) continue;
          final vb = b.gray[by * b.w + (px - b.ox)];
          if (vb < 0) continue;
          cnt++;
          sa += va;
          sb += vb;
          saa += va * va;
          sbb += vb * vb;
          sab += va * vb;
        }
      }
      if (cnt > maxCount) maxCount = cnt;
      if (cnt < minCount) minCount = cnt;
      score[(sy + r) * side + (sx + r)] = cnt < 200
          ? -2
          : _ncc(cnt, sa, sb, saa, sbb, sab);
    }
  }
  if (maxCount < 200) return null;

  var best = -2.0;
  var bi = 0;
  for (var i = 0; i < score.length; i++) {
    if (score[i] > best) {
      best = score[i];
      bi = i;
    }
  }
  final bx = bi % side, by = bi ~/ side;
  if (best < 0.45) return null;
  // Peak on the search edge means the true shift is out of range.
  if (bx == 0 || by == 0 || bx == side - 1 || by == side - 1) return null;

  // The runner-up is the best other local maximum of the score surface.
  var second = -2.0;
  for (var y = 1; y < side - 1; y++) {
    for (var x = 1; x < side - 1; x++) {
      if (x == bx && y == by) continue;
      final v = score[y * side + x];
      if (v <= second) continue;
      var isMax = true;
      for (var dy = -1; dy <= 1 && isMax; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if ((dx != 0 || dy != 0) && score[(y + dy) * side + x + dx] > v) {
            isMax = false;
            break;
          }
        }
      }
      if (isMax) second = v;
    }
  }
  final margin = best - second;
  if (margin < 0.08) return null;

  double sub(double l, double c, double rr) {
    final d = l - 2 * c + rr;
    return d.abs() < 1e-9 ? 0 : 0.5 * (l - rr) / d;
  }

  final fx = sub(score[by * side + bx - 1], best, score[by * side + bx + 1]);
  final fy = sub(
    score[(by - 1) * side + bx],
    best,
    score[(by + 1) * side + bx],
  );
  return (
    bx - r + fx.clamp(-0.5, 0.5),
    by - r + fy.clamp(-0.5, 0.5),
    margin.clamp(0.08, 1.0),
  );
}

double _ncc(int n, double sa, double sb, double saa, double sbb, double sab) {
  final cov = sab - sa * sb / n;
  final va = saa - sa * sa / n;
  final vb = sbb - sb * sb / n;
  // A flat patch carries no information.
  if (va < 1e-3 * n || vb < 1e-3 * n) return -2;
  return cov / math.sqrt(va * vb);
}

/// Builds ground patches from photos and refines their GPS positions.
class DroneAlignService {
  DroneAlignService._();
  static final DroneAlignService instance = DroneAlignService._();

  static const _cells = 192;
  static const _radiusCells = 14;
  static const _earthR = 6378137.0;

  /// Returns [photos] with positions corrected by the overlap with neighbours.
  /// Photos without a trustworthy match keep their GPS position.
  Future<(List<DronePhoto>, AlignResult?)> align(
    List<DronePhoto> photos,
    List<LatLng> polygon, {
    PhotoFootprintOptions options = const PhotoFootprintOptions(),
    void Function(String message)? onProgress,
  }) async {
    if (photos.length < 2) return (photos, null);
    final ps = DronePhotoService.instance;
    final origin = LatLng(
      polygon.map((p) => p.latitude).reduce((a, b) => a + b) / polygon.length,
      polygon.map((p) => p.longitude).reduce((a, b) => a + b) / polygon.length,
    );
    const full = PhotoFootprintOptions(keep: 0.9);
    final longs = [
      for (final p in photos) p.relativeAltitudeM * options.footprintPerMetre,
    ]..sort();
    final cell = longs[longs.length ~/ 2] / _cells;
    if (cell <= 0) return (photos, null);

    final smalls = <_SmallGray>[];
    for (var i = 0; i < photos.length; i++) {
      onProgress?.call('Poravnava: fotografija ${i + 1} / ${photos.length}');
      smalls.add(await _decodeSmall(photos[i]));
    }

    // Pass 1 finds heading and height errors. Those bias the shifts, so
    // pass 2 resamples with the corrected pose and solves the shifts again.
    var current = photos;
    AlignResult? result;
    for (var pass = 1; pass <= 2; pass++) {
      onProgress?.call('Poravnava: iskanje ujemanj ($pass/2) …');
      final patches = [
        for (var i = 0; i < photos.length; i++)
          _resample(
            current[i],
            smalls[i],
            origin,
            cell,
            ps,
            options.footprintPerMetre,
            full.keep,
          ),
      ];
      final r = await compute(
        solveAlign,
        AlignJob(patches, cell, _radiusCells),
      );
      result = r;
      current = [
        for (var i = 0; i < photos.length; i++)
          _correct(
            current[i],
            pass == 2 ? r.dx[i] : 0,
            pass == 2 ? r.dy[i] : 0,
            r.dHeadingDeg[i],
            r.heightScale[i],
          ),
      ];
    }
    return (current, result);
  }

  DronePhoto _correct(
    DronePhoto p,
    double dxM,
    double dyM,
    double dHeadingDeg,
    double heightScale,
  ) {
    final lat = p.position.latitude + dyM / _earthR * 180 / math.pi;
    final cosLat = math.cos(p.position.latitude * math.pi / 180);
    final lon = p.position.longitude + dxM / (_earthR * cosLat) * 180 / math.pi;
    return DronePhoto(
      file: p.file,
      position: LatLng(lat, lon),
      relativeAltitudeM: p.relativeAltitudeM * heightScale,
      headingDeg: p.headingDeg + dHeadingDeg,
      pitchDeg: p.pitchDeg,
      width: p.width,
      height: p.height,
    );
  }

  /// Decodes [photo] small and converts it to gray. Done once per photo.
  Future<_SmallGray> _decodeSmall(DronePhoto photo) async {
    final landscape = photo.width >= photo.height;
    final ratio = landscape
        ? photo.height / photo.width
        : photo.width / photo.height;
    final bytes = await photo.file.readAsBytes();
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: landscape ? 288 : (288 * ratio).round().clamp(16, 288),
    );
    final img = (await codec.getNextFrame()).image;
    codec.dispose();
    final data = (await img.toByteData())!;
    final iw = img.width, ih = img.height;
    img.dispose();
    final gray = Float32List(iw * ih);
    for (var i = 0; i < iw * ih; i++) {
      gray[i] =
          (0.299 * data.getUint8(i * 4) +
              0.587 * data.getUint8(i * 4 + 1) +
              0.114 * data.getUint8(i * 4 + 2)) /
          255.0;
    }
    return _SmallGray(gray, iw, ih);
  }

  /// Resamples [small] onto the ground grid with the photo's current pose.
  AlignPatch _resample(
    DronePhoto photo,
    _SmallGray small,
    LatLng origin,
    double cell,
    DronePhotoService ps,
    double footprintPerMetre,
    double keep,
  ) {
    final (cx, cy) = ps.toLocal(photo.position, origin);
    final long = photo.relativeAltitudeM * footprintPerMetre;
    final landscape = photo.width >= photo.height;
    final ratio = landscape
        ? photo.height / photo.width
        : photo.width / photo.height;
    final wm = landscape ? long : long * ratio;
    final hm = landscape ? long * ratio : long;
    final iw = small.w, ih = small.h;
    double grayAt(int x, int y) =>
        small.gray[y.clamp(0, ih - 1) * iw + x.clamp(0, iw - 1)];

    final half = math.sqrt(wm * wm + hm * hm) / 2;
    final ox = ((cx - half) / cell).floor();
    final oy = ((cy - half) / cell).floor();
    final n = (2 * half / cell).ceil() + 2;
    final gray = Float32List(n * n)..fillRange(0, n * n, -1);
    final th = photo.headingDeg * math.pi / 180;
    final upX = math.sin(th), upY = math.cos(th);
    final rtX = math.cos(th), rtY = -math.sin(th);
    for (var v = 0; v < n; v++) {
      final gy = (oy + v + 0.5) * cell - cy;
      for (var u = 0; u < n; u++) {
        final gx = (ox + u + 0.5) * cell - cx;
        final right = gx * rtX + gy * rtY;
        final up = gx * upX + gy * upY;
        if (right.abs() > wm * keep / 2 || up.abs() > hm * keep / 2) continue;
        final fx = (right / wm + 0.5) * iw - 0.5;
        final fy = (0.5 - up / hm) * ih - 0.5;
        final x0 = fx.floor(), y0 = fy.floor();
        final tx = fx - x0, ty = fy - y0;
        final g =
            grayAt(x0, y0) * (1 - tx) * (1 - ty) +
            grayAt(x0 + 1, y0) * tx * (1 - ty) +
            grayAt(x0, y0 + 1) * (1 - tx) * ty +
            grayAt(x0 + 1, y0 + 1) * tx * ty;
        gray[v * n + u] = g;
      }
    }
    return AlignPatch(gray: gray, w: n, h: n, ox: ox, oy: oy);
  }
}

class _SmallGray {
  final Float32List gray;
  final int w;
  final int h;
  const _SmallGray(this.gray, this.w, this.h);
}
