/// Slovenian plural form for [count]: 1 → [one], 2 → [two], 3–4 → [few],
/// otherwise [other]. Applied mod 100 (101 → one, 102 → two, …).
String slPlural(int count, String one, String two, String few, String other) {
  final n = count % 100;
  if (n == 1) return one;
  if (n == 2) return two;
  if (n == 3 || n == 4) return few;
  return other;
}

/// '$count <form>', e.g. slCount(3, 'hlod', 'hloda', 'hlodi', 'hlodov')
/// → '3 hlodi'.
String slCount(int count, String one, String two, String few, String other) =>
    '$count ${slPlural(count, one, two, few, other)}';
