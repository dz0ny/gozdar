import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Update status enum
enum UpdateStatus {
  idle,
  checking,
  available,
  downloading,
  readyToInstall,
  error,
}

/// Release info from GitHub
class ReleaseInfo {
  final String version;
  final int buildNumber;
  final String downloadUrl;
  final String releaseNotes;
  final DateTime publishedAt;

  ReleaseInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.publishedAt,
  });
}

/// Service for checking and downloading app updates from GitHub Releases
class UpdateService extends ChangeNotifier {
  static final UpdateService _instance = UpdateService._internal();

  // GitHub repository configuration
  // TODO: Update these values for your repository
  static const String _githubOwner = 'dz0ny';
  static const String _githubRepo = 'gozdar';

  // State
  UpdateStatus _status = UpdateStatus.idle;
  double _downloadProgress = 0.0;
  String? _errorMessage;
  ReleaseInfo? _latestRelease;
  PackageInfo? _packageInfo;

  factory UpdateService() {
    return _instance;
  }

  UpdateService._internal();

  // Getters
  UpdateStatus get status => _status;
  double get downloadProgress => _downloadProgress;
  String? get errorMessage => _errorMessage;
  ReleaseInfo? get latestRelease => _latestRelease;
  String get currentVersion => _packageInfo?.version ?? '0.0.0';
  int get currentBuildNumber =>
      int.tryParse(_packageInfo?.buildNumber ?? '0') ?? 0;

  /// Initialize the service
  Future<void> init() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }

  /// Check for updates from GitHub Releases
  Future<bool> checkForUpdate() async {
    if (_status == UpdateStatus.checking || _status == UpdateStatus.downloading) {
      return false;
    }

    _status = UpdateStatus.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      // Ensure package info is loaded
      _packageInfo ??= await PackageInfo.fromPlatform();

      // Fetch latest release from GitHub API
      final uri = Uri.parse(
        'https://api.github.com/repos/$_githubOwner/$_githubRepo/releases/latest',
      );

      final response = await http.get(uri, headers: {
        'Accept': 'application/vnd.github.v3+json',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 404) {
        // No releases yet
        _status = UpdateStatus.idle;
        notifyListeners();
        return false;
      }

      if (response.statusCode != 200) {
        throw Exception('GitHub API error: ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      _latestRelease = _parseRelease(data);

      if (_latestRelease == null) {
        _status = UpdateStatus.idle;
        notifyListeners();
        return false;
      }

      // Compare versions
      final hasUpdate = _isNewerVersion(_latestRelease!);

      _status = hasUpdate ? UpdateStatus.available : UpdateStatus.idle;
      notifyListeners();
      return hasUpdate;
    } catch (e) {
      _status = UpdateStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Parse GitHub release JSON
  ReleaseInfo? _parseRelease(Map<String, dynamic> data) {
    final tagName = data['tag_name'] as String?;
    if (tagName == null) return null;

    // Parse version from tag (e.g., "v1.0.1+2" or "v1.0.1")
    final versionMatch = RegExp(r'v?(\d+\.\d+\.\d+)(?:\+(\d+))?').firstMatch(tagName);
    if (versionMatch == null) return null;

    final version = versionMatch.group(1)!;
    final buildNumber = int.tryParse(versionMatch.group(2) ?? '0') ?? 0;

    // Find APK asset
    final assets = data['assets'] as List<dynamic>? ?? [];
    String? downloadUrl;

    for (final asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name.endsWith('.apk')) {
        downloadUrl = asset['browser_download_url'] as String?;
        break;
      }
    }

    if (downloadUrl == null) return null;

    return ReleaseInfo(
      version: version,
      buildNumber: buildNumber,
      downloadUrl: downloadUrl,
      releaseNotes: data['body'] as String? ?? '',
      publishedAt: DateTime.tryParse(data['published_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Compare versions to check if release is newer
  bool _isNewerVersion(ReleaseInfo release) {
    final currentParts = currentVersion.split('.').map(int.tryParse).toList();
    final releaseParts = release.version.split('.').map(int.tryParse).toList();

    // Pad to ensure same length
    while (currentParts.length < 3) {
      currentParts.add(0);
    }
    while (releaseParts.length < 3) {
      releaseParts.add(0);
    }

    // Compare major.minor.patch
    for (int i = 0; i < 3; i++) {
      final current = currentParts[i] ?? 0;
      final remote = releaseParts[i] ?? 0;

      if (remote > current) return true;
      if (remote < current) return false;
    }

    // Same version, compare build number
    return release.buildNumber > currentBuildNumber;
  }

  /// Download and install the update
  Future<void> downloadAndInstall() async {
    if (_latestRelease == null || _status == UpdateStatus.downloading) {
      return;
    }

    _status = UpdateStatus.downloading;
    _downloadProgress = 0.0;
    _errorMessage = null;
    notifyListeners();

    try {
      OtaUpdate()
          .execute(
        _latestRelease!.downloadUrl,
        destinationFilename: 'gozdar-${_latestRelease!.version}.apk',
      )
          .listen(
        (event) {
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              _downloadProgress = double.tryParse(event.value ?? '0') ?? 0;
              _downloadProgress = _downloadProgress / 100;
              notifyListeners();
              break;
            case OtaStatus.INSTALLING:
              _status = UpdateStatus.readyToInstall;
              _downloadProgress = 1.0;
              notifyListeners();
              break;
            case OtaStatus.ALREADY_RUNNING_ERROR:
              _status = UpdateStatus.error;
              _errorMessage = 'Download already in progress';
              notifyListeners();
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              _status = UpdateStatus.error;
              _errorMessage = 'Permission denied for installation';
              notifyListeners();
              break;
            case OtaStatus.INTERNAL_ERROR:
              _status = UpdateStatus.error;
              _errorMessage = event.value ?? 'Internal error';
              notifyListeners();
              break;
            case OtaStatus.DOWNLOAD_ERROR:
              _status = UpdateStatus.error;
              _errorMessage = event.value ?? 'Download failed';
              notifyListeners();
              break;
            case OtaStatus.CHECKSUM_ERROR:
              _status = UpdateStatus.error;
              _errorMessage = 'Checksum verification failed';
              notifyListeners();
              break;
            case OtaStatus.INSTALLATION_DONE:
              // Installation completed successfully
              _status = UpdateStatus.idle;
              notifyListeners();
              break;
          }
        },
        onError: (e) {
          _status = UpdateStatus.error;
          _errorMessage = e.toString();
          notifyListeners();
        },
      );
    } catch (e) {
      _status = UpdateStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Reset update status (e.g., after dismissing)
  void reset() {
    _status = UpdateStatus.idle;
    _downloadProgress = 0.0;
    _errorMessage = null;
    _latestRelease = null;
    notifyListeners();
  }

  /// Dismiss the update notification
  void dismiss() {
    if (_status == UpdateStatus.available) {
      _status = UpdateStatus.idle;
      notifyListeners();
    }
  }
}
