import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/rtk_position_service.dart';

class RtkBridgeScreen extends StatefulWidget {
  const RtkBridgeScreen({super.key});

  @override
  State<RtkBridgeScreen> createState() => _RtkBridgeScreenState();
}

class _RtkBridgeScreenState extends State<RtkBridgeScreen> {
  static final _serviceUuid = Guid('6E400001-B5A3-F393-E0A9-E50E24DCCA9E');
  static final _rxUuid = Guid('6E400002-B5A3-F393-E0A9-E50E24DCCA9E');
  static final _txUuid = Guid('6E400003-B5A3-F393-E0A9-E50E24DCCA9E');

  final _hostController = TextEditingController(text: 'eu.rtkdata.com');
  final _portController = TextEditingController(text: '2101');
  final _mountController = TextEditingController(text: 'AUTO');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mapController = MapController();

  final List<ScanResult> _devices = [];
  final List<int> _headerBytes = [];

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rx;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _nmeaSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  Socket? _casterSocket;

  String _status = 'Ni povezave';
  String _ntripError = '';
  String _rememberedBleDeviceId = '';
  String _latestGga = '';
  String _latestNmea = '';
  String _nmeaBuffer = '';
  double? _externalLatitude;
  double? _externalLongitude;
  double? _externalAltitude;
  double? _externalHdop;
  int? _externalFixQuality;
  int? _externalSatellites;
  bool _mapReady = false;
  bool _isScanning = false;
  bool _isBleConnected = false;
  bool _isBleConnecting = false;
  bool _shouldMaintainBleConnection = false;
  bool _isCasterConnecting = false;
  bool _isCasterConnected = false;
  bool _casterHeaderRead = false;
  bool _isNtripSetupExpanded = true;
  int _rtcmBytes = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _disconnectCaster();
    _disconnectBle();
    _hostController.dispose();
    _portController.dispose();
    _mountController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _hostController.text = 'eu.rtkdata.com';
    _portController.text = '2101';
    _mountController.text = prefs.getString('rtk.mount') ?? _mountController.text;
    _usernameController.text = prefs.getString('rtk.username') ?? '';
    _passwordController.text = prefs.getString('rtk.password') ?? '';
    _rememberedBleDeviceId = prefs.getString('rtk.bleDeviceId') ?? '';
    if (mounted) {
      setState(() {
        _isNtripSetupExpanded =
            _mountController.text.trim().isEmpty ||
            _usernameController.text.trim().isEmpty ||
            _passwordController.text.isEmpty;
      });
    }
    if (_rememberedBleDeviceId.isNotEmpty) {
      _shouldMaintainBleConnection = true;
      await _autoConnectRememberedBle();
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rtk.host', _hostController.text.trim());
    await prefs.setString('rtk.port', _portController.text.trim());
    await prefs.setString('rtk.mount', _mountController.text.trim());
    await prefs.setString('rtk.username', _usernameController.text.trim());
    await prefs.setString('rtk.password', _passwordController.text);
  }

  Future<void> _saveSettingsAndCollapse() async {
    await _saveSettings();
    if (mounted) {
      setState(() {
        _isNtripSetupExpanded = false;
        _status = 'NTRIP nastavitve shranjene';
      });
    }
  }

  Future<void> _scan() async {
    setState(() {
      _devices.clear();
      _isScanning = true;
      _status = 'Iskanje Gozdar-RTK...';
    });

    await _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        for (final result in results) {
          final name = result.advertisementData.advName;
          final id = result.device.remoteId.str;
          final exists = _devices.any((item) => item.device.remoteId.str == id);
          if (!exists && (name == 'Gozdar-RTK' || name.contains('RTK'))) {
            _devices.add(result);
          }
        }
      });
    });

    try {
      await FlutterBluePlus.startScan(
        withNames: ['Gozdar-RTK'],
        timeout: const Duration(seconds: 8),
      );
      await FlutterBluePlus.isScanning.where((value) => value == false).first;
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'BLE napaka: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _connectBle(BluetoothDevice device) async {
    await _disconnectBle(clearRememberedDevice: false);
    setState(() {
      _isBleConnecting = true;
      _shouldMaintainBleConnection = true;
      _status = 'Povezovanje z GNSS...';
    });

    try {
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 15),
      );
    } catch (e) {
      final alreadyConnected = e.toString().contains('already connected');
      if (!alreadyConnected) rethrow;
    }

    try {
      await device.requestMtu(247);
    } catch (_) {}

    final services = await device.discoverServices();
    BluetoothCharacteristic? rx;
    BluetoothCharacteristic? tx;

    for (final service in services) {
      if (service.uuid != _serviceUuid) continue;
      for (final characteristic in service.characteristics) {
        if (characteristic.uuid == _rxUuid) rx = characteristic;
        if (characteristic.uuid == _txUuid) tx = characteristic;
      }
    }

    if (rx == null || tx == null) {
      await device.disconnect();
      setState(() {
        _isBleConnecting = false;
        _status = 'Gozdar-RTK BLE UART ni najden';
      });
      return;
    }

    await tx.setNotifyValue(true);
    _nmeaSubscription = tx.lastValueStream.listen(_handleNmeaBytes);
    await _connectionSubscription?.cancel();
    _connectionSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _handleBleDisconnected();
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rtk.bleDeviceId', device.remoteId.str);

    setState(() {
      _device = device;
      _rx = rx;
      _rememberedBleDeviceId = device.remoteId.str;
      _isBleConnected = true;
      _isBleConnecting = false;
      _status = 'GNSS povezan';
    });
  }

  Future<void> _disconnectBle({
    bool clearRememberedDevice = true,
    bool updateStatus = false,
  }) async {
    if (clearRememberedDevice) {
      _shouldMaintainBleConnection = false;
      _rememberedBleDeviceId = '';
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('rtk.bleDeviceId');
    }
    await _disconnectCaster();
    await _nmeaSubscription?.cancel();
    _nmeaSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    final device = _device;
    _device = null;
    _rx = null;
    _isBleConnected = false;
    _isBleConnecting = false;
    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
    if (mounted && updateStatus) {
      setState(() => _status = 'GNSS prekinjen');
    }
  }

  void _handleBleDisconnected() {
    if (!mounted || !_isBleConnected) return;
    setState(() {
      _device = null;
      _rx = null;
      _isBleConnected = false;
      _status = 'GNSS povezava izgubljena';
    });
    _disconnectCaster();
    if (_shouldMaintainBleConnection && _rememberedBleDeviceId.isNotEmpty) {
      unawaited(_autoConnectRememberedBle());
    }
  }

  Future<void> _autoConnectRememberedBle() async {
    if (_isBleConnected || _isBleConnecting || _rememberedBleDeviceId.isEmpty) {
      return;
    }
    if (mounted) {
      setState(() {
        _isBleConnecting = true;
        _status = 'Samodejno povezujem GNSS...';
      });
    }

    final completer = Completer<BluetoothDevice?>();
    StreamSubscription<List<ScanResult>>? subscription;
    try {
      subscription = FlutterBluePlus.onScanResults.listen((results) {
        for (final result in results) {
          if (result.device.remoteId.str == _rememberedBleDeviceId &&
              !completer.isCompleted) {
            completer.complete(result.device);
          }
        }
      });
      await FlutterBluePlus.startScan(
        withNames: ['Gozdar-RTK'],
        timeout: const Duration(seconds: 8),
      );
      final device = await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => null,
      );
      if (device != null && mounted) {
        await _connectBle(device);
      } else if (mounted) {
        setState(() {
          _isBleConnecting = false;
          _status = 'GNSS ni najden, poskusim znova ob odpiranju zaslona';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBleConnecting = false;
          _status = 'BLE samodejna povezava ni uspela: $e';
        });
      }
    } finally {
      await subscription?.cancel();
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    }
  }

  void _handleNmeaBytes(List<int> data) {
    final text = String.fromCharCodes(data);
    _nmeaBuffer += text;

    while (_nmeaBuffer.contains('\n')) {
      final index = _nmeaBuffer.indexOf('\n');
      final line = _nmeaBuffer.substring(0, index).trim();
      _nmeaBuffer = _nmeaBuffer.substring(index + 1);
      if (line.isEmpty) continue;

      _latestNmea = line;
      if (line.startsWith(r'$') && line.contains('GGA,')) {
        _latestGga = line;
        _parseGga(line);
        _sendGga(line);
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _connectCaster() async {
    if (_rx == null) {
      setState(() {
        _status = 'Najprej poveži Gozdar-RTK';
        _ntripError = 'NTRIP potrebuje BLE povezavo, ker mora app RTCM popravke poslati v zunanji GNSS.';
      });
      return;
    }

    await _saveSettings();
    await _disconnectCaster();

    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 2101;
    final mount = _mountController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (mount.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() {
        _status = 'Manjkajo NTRIP podatki';
        _ntripError = 'Vnesi mountpoint, RTKdata username in RTKdata password.';
      });
      return;
    }

    setState(() {
      _isCasterConnecting = true;
      _ntripError = '';
      _status = 'Povezovanje na NTRIP...';
    });

    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 10));
      final auth = base64Encode(utf8.encode('$username:$password'));
      final request = StringBuffer()
        ..write('GET /$mount HTTP/1.0\r\n')
        ..write('User-Agent: NTRIP Gozdar/1.0\r\n')
        ..write('Ntrip-Version: Ntrip/2.0\r\n')
        ..write('Authorization: Basic $auth\r\n')
        ..write('Connection: close\r\n\r\n');

      socket.write(request.toString());
      socket.listen(
        _handleCasterBytes,
        onDone: () {
          if (mounted) {
            setState(() {
              _casterSocket = null;
              _isCasterConnecting = false;
              _isCasterConnected = false;
              if (_status == 'NTRIP povezan') {
                _status = 'NTRIP povezava zaprta';
                _ntripError = 'Caster je zaprl TCP povezavo.';
              }
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _casterSocket = null;
              _isCasterConnecting = false;
              _isCasterConnected = false;
              _status = 'NTRIP napaka';
              _ntripError = _describeSocketError(error);
            });
          }
        },
      );

      _casterSocket = socket;
      _casterHeaderRead = false;
      _headerBytes.clear();
      _rtcmBytes = 0;

      setState(() {
        _status = 'NTRIP TCP povezan, čakam caster...';
      });

      if (_latestGga.isNotEmpty) {
        _sendGga(_latestGga);
      }
    } on TimeoutException {
      setState(() {
        _isCasterConnecting = false;
        _status = 'NTRIP timeout';
        _ntripError = 'eu.rtkdata.com:2101 se ni odzval v 10 sekundah. Preveri internetno povezavo.';
      });
    } catch (e) {
      setState(() {
        _isCasterConnecting = false;
        _status = 'NTRIP napaka';
        _ntripError = _describeSocketError(e);
      });
    }
  }

  Future<void> _disconnectCaster({bool updateStatus = false}) async {
    final socket = _casterSocket;
    _casterSocket = null;
    _isCasterConnecting = false;
    _isCasterConnected = false;
    _casterHeaderRead = false;
    _headerBytes.clear();
    if (socket != null) {
      await socket.close();
    }
    if (mounted && updateStatus) {
      setState(() {
        _status = 'NTRIP prekinjen';
        _ntripError = '';
      });
    }
  }

  void _sendGga(String line) {
    final socket = _casterSocket;
    if (socket == null) return;
    socket.write('${line.trim()}\r\n');
  }

  void _handleCasterBytes(Uint8List data) {
    if (!_casterHeaderRead) {
      _headerBytes.addAll(data);
      final split = _findHeaderEnd(_headerBytes);
      if (split == -1) return;

      final header = ascii.decode(_headerBytes.sublist(0, split), allowInvalid: true);
      _casterHeaderRead = true;
      if (!_isNtripSuccessHeader(header)) {
        setState(() {
          _isCasterConnecting = false;
          _isCasterConnected = false;
          _status = 'NTRIP zavrnjen';
          _ntripError = _describeNtripHeaderFailure(header);
        });
        _disconnectCaster();
        return;
      }

      setState(() {
        _isCasterConnecting = false;
        _isCasterConnected = true;
        _isNtripSetupExpanded = false;
        _status = 'NTRIP povezan';
        _ntripError = '';
      });

      final body = _headerBytes.sublist(split);
      _headerBytes.clear();
      if (body.isNotEmpty) {
        _writeRtcm(body);
      }
      return;
    }

    _writeRtcm(data);
  }

  bool _isNtripSuccessHeader(String header) {
    final firstLine = header.split('\r\n').first.trim().toUpperCase();
    return firstLine == 'ICY 200 OK' ||
        firstLine == 'HTTP/1.1 200 OK' ||
        firstLine == 'HTTP/1.0 200 OK';
  }

  String _describeNtripHeaderFailure(String header) {
    final lines = header.split(RegExp(r'\r?\n')).where((line) => line.trim().isNotEmpty).toList();
    final firstLine = lines.isEmpty ? 'Prazen odgovor casterja' : lines.first.trim();
    final lowerHeader = header.toLowerCase();

    if (lowerHeader.contains('401') || lowerHeader.contains('unauthorized')) {
      return '$firstLine\nPreveri RTKdata username/password. To niso website login podatki.';
    }
    if (lowerHeader.contains('403') || lowerHeader.contains('forbidden')) {
      return '$firstLine\nRačun nima dostopa do tega mountpointa ali casterja.';
    }
    if (lowerHeader.contains('404') || lowerHeader.contains('not found')) {
      return '$firstLine\nMountpoint ni najden. Za RTKdata EU uporabi AUTO, z velikimi črkami.';
    }
    if (lowerHeader.contains('sourcetable')) {
      return '$firstLine\nCaster je vrnil sourcetable namesto RTCM toka. Preveri mountpoint.';
    }
    return '$firstLine\n${lines.skip(1).take(4).join('\n')}';
  }

  String _describeSocketError(Object error) {
    if (error is SocketException) {
      final osError = error.osError == null ? '' : ' (${error.osError!.message})';
      return '${error.message}$osError';
    }
    return error.toString();
  }

  int _findHeaderEnd(List<int> data) {
    for (var i = 3; i < data.length; i++) {
      if (data[i - 3] == 13 && data[i - 2] == 10 && data[i - 1] == 13 && data[i] == 10) {
        return i + 1;
      }
      if (data[i - 1] == 10 && data[i] == 10) {
        return i + 1;
      }
    }
    return -1;
  }

  Future<void> _writeRtcm(List<int> data) async {
    final rx = _rx;
    if (rx == null) return;

    for (var offset = 0; offset < data.length; offset += 180) {
      final end = offset + 180 > data.length ? data.length : offset + 180;
      await rx.write(data.sublist(offset, end), withoutResponse: true);
    }

    if (mounted) {
      setState(() => _rtcmBytes += data.length);
    }
  }

  void _setRegion(String host) {
    setState(() {
      _hostController.text = 'eu.rtkdata.com';
      _portController.text = '2101';
      _mountController.text = 'AUTO';
    });
  }

  void _parseGga(String line) {
    final cleanLine = line.split('*').first;
    final fields = cleanLine.split(',');
    if (fields.length < 10) return;

    final latitude = _parseNmeaCoordinate(fields[2], fields[3]);
    final longitude = _parseNmeaCoordinate(fields[4], fields[5]);
    if (latitude == null || longitude == null) return;

    _externalLatitude = latitude;
    _externalLongitude = longitude;
    _externalFixQuality = int.tryParse(fields[6]);
    _externalSatellites = int.tryParse(fields[7]);
    _externalHdop = double.tryParse(fields[8]);
    _externalAltitude = double.tryParse(fields[9]);
    rtkPositionService.update(
      latitude: latitude,
      longitude: longitude,
      altitude: _externalAltitude,
      hdop: _externalHdop,
      accuracyMeters: _estimatedHorizontalAccuracyMeters(),
      fixQuality: _externalFixQuality,
      satellites: _externalSatellites,
    );
    _moveMapToExternalPosition();
  }

  void _moveMapToExternalPosition() {
    if (!_mapReady || _externalLatitude == null || _externalLongitude == null) {
      return;
    }

    _mapController.move(
      LatLng(_externalLatitude!, _externalLongitude!),
      20,
    );
  }

  double? _parseNmeaCoordinate(String value, String hemisphere) {
    if (value.isEmpty || hemisphere.isEmpty) return null;

    final dotIndex = value.indexOf('.');
    if (dotIndex < 0 || dotIndex < 2) return null;

    final degreeDigits = dotIndex > 4 ? 3 : 2;
    if (value.length < degreeDigits + 2) return null;

    final degrees = double.tryParse(value.substring(0, degreeDigits));
    final minutes = double.tryParse(value.substring(degreeDigits));
    if (degrees == null || minutes == null) return null;

    var coordinate = degrees + (minutes / 60);
    if (hemisphere == 'S' || hemisphere == 'W') {
      coordinate = -coordinate;
    }
    return coordinate;
  }

  String _fixQualityLabel() {
    switch (_externalFixQuality) {
      case 0:
        return 'Brez fixa';
      case 1:
        return 'GPS';
      case 2:
        return 'DGPS';
      case 4:
        return 'RTK fixed';
      case 5:
        return 'RTK float';
      default:
        return _externalFixQuality == null ? '-' : 'Fix $_externalFixQuality';
    }
  }

  String _accuracyEstimateLabel() {
    if (_externalFixQuality == 4) return 'Centimetrska';
    if (_externalFixQuality == 5) return 'Decimetrska';
    if (_externalFixQuality == 2) return 'Submetrska';
    if (_externalFixQuality == 1) return 'Metrska';
    return 'Ni ocene';
  }

  double? _estimatedHorizontalAccuracyMeters() {
    final hdop = _externalHdop;
    if (hdop == null || _externalFixQuality == null || _externalFixQuality == 0) {
      return null;
    }

    final baseAccuracy = switch (_externalFixQuality) {
      4 => 0.02,
      5 => 0.20,
      2 => 0.70,
      _ => 4.00,
    };
    return baseAccuracy * hdop.clamp(0.5, 3.0);
  }

  String _estimatedAccuracyLabel() {
    final accuracy = _estimatedHorizontalAccuracyMeters();
    if (accuracy == null) return '-';
    if (accuracy < 1) return '${(accuracy * 100).round()} cm';
    return '${accuracy.toStringAsFixed(1)} m';
  }

  Color _fixQualityColor(ColorScheme colorScheme) {
    if (_externalFixQuality == 4) return Colors.green;
    if (_externalFixQuality == 5 || _externalFixQuality == 2) return Colors.orange;
    return colorScheme.surfaceContainerHighest;
  }

  Color _markerColor(ColorScheme colorScheme) {
    if (_externalFixQuality == 4) return Colors.green;
    if (_externalFixQuality == 5) return Colors.orange;
    if (_externalFixQuality == 2) return Colors.amber;
    return colorScheme.primary;
  }

  Color _accuracyCircleColor(ColorScheme colorScheme) {
    if (_externalFixQuality == 4) return Colors.green.withValues(alpha: 0.18);
    if (_externalFixQuality == 5) return Colors.orange.withValues(alpha: 0.20);
    if (_externalFixQuality == 2) return Colors.amber.withValues(alpha: 0.22);
    return colorScheme.primary.withValues(alpha: 0.16);
  }

  Color _accuracyCircleBorderColor(ColorScheme colorScheme) {
    if (_externalFixQuality == 4) return Colors.green;
    if (_externalFixQuality == 5) return Colors.orange;
    if (_externalFixQuality == 2) return Colors.amber;
    return colorScheme.primary;
  }

  String _ntripSetupSummary() {
    final username = _usernameController.text.trim();
    final mount = _mountController.text.trim();
    if (username.isEmpty || mount.isEmpty || _passwordController.text.isEmpty) {
      return 'NTRIP podatki niso shranjeni';
    }
    return '${_hostController.text.trim()}:2101 / $mount / $username';
  }

  Widget _buildPositionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccuracyCheck(
    BuildContext context, {
    required bool checked,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = checked ? Colors.green : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_circle : Icons.radio_button_unchecked,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: checked ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccuracyChecklist(BuildContext context) {
    final hasPosition = _externalLatitude != null && _externalLongitude != null;
    final hasCorrections = _rtcmBytes > 0;
    final hasRtk = _externalFixQuality == 4 || _externalFixQuality == 5;
    final hasFixed = _externalFixQuality == 4;
    final hasEnoughSatellites = (_externalSatellites ?? 0) >= 12;
    final hasGoodHdop = _externalHdop != null && _externalHdop! <= 1.0;
    final estimatedAccuracy = _estimatedHorizontalAccuracyMeters();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 24),
        Text(
          'Natančnost',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        _buildAccuracyCheck(
          context,
          checked: hasPosition,
          label: 'Zunanja pozicija',
          value: hasPosition ? 'OK' : '-',
        ),
        _buildAccuracyCheck(
          context,
          checked: hasCorrections,
          label: 'RTCM popravki',
          value: hasCorrections ? '$_rtcmBytes B' : '0 B',
        ),
        _buildAccuracyCheck(
          context,
          checked: hasRtk,
          label: 'RTK rešitev',
          value: _fixQualityLabel(),
        ),
        _buildAccuracyCheck(
          context,
          checked: hasFixed,
          label: 'RTK fixed',
          value: hasFixed ? 'cm' : '-',
        ),
        _buildAccuracyCheck(
          context,
          checked: hasEnoughSatellites,
          label: 'Sateliti',
          value: _externalSatellites == null ? '-' : _externalSatellites.toString(),
        ),
        _buildAccuracyCheck(
          context,
          checked: hasGoodHdop,
          label: 'HDOP <= 1.0',
          value: _externalHdop == null ? '-' : _externalHdop!.toStringAsFixed(1),
        ),
        _buildAccuracyCheck(
          context,
          checked: estimatedAccuracy != null && estimatedAccuracy <= 0.05,
          label: 'Ocenjena natancnost',
          value: _estimatedAccuracyLabel(),
        ),
        const SizedBox(height: 6),
        Text(
          'Ocena: ${_accuracyEstimateLabel()} (${_estimatedAccuracyLabel()})',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final estimatedAccuracy = _estimatedHorizontalAccuracyMeters();

    return Scaffold(
      appBar: AppBar(title: const Text('RTK GNSS')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Stanje', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(_status),
                  if (_ntripError.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SelectableText(
                              _ntripError,
                              style: TextStyle(color: colorScheme.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(_isBleConnected ? 'BLE povezan' : 'BLE ni povezan')),
                      Chip(label: Text(_isCasterConnected ? 'NTRIP povezan' : 'NTRIP ni povezan')),
                      Chip(
                        label: Text(_fixQualityLabel()),
                        backgroundColor: _fixQualityColor(colorScheme),
                      ),
                      Chip(label: Text('RTCM $_rtcmBytes B')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 260,
              child: _externalLatitude == null || _externalLongitude == null
                  ? Center(
                      child: Text(
                        'Čakam zunanjo GNSS pozicijo',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: LatLng(_externalLatitude!, _externalLongitude!),
                        initialZoom: 20,
                        minZoom: 3,
                        maxZoom: 22,
                        onMapReady: () {
                          _mapReady = true;
                          _moveMapToExternalPosition();
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          maxZoom: 22,
                          maxNativeZoom: 19,
                          userAgentPackageName: 'dev.dz0ny.gozdar',
                        ),
                        if (estimatedAccuracy != null)
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: LatLng(_externalLatitude!, _externalLongitude!),
                                radius: estimatedAccuracy,
                                useRadiusInMeter: true,
                                color: _accuracyCircleColor(colorScheme),
                                borderColor: _accuracyCircleBorderColor(colorScheme),
                                borderStrokeWidth: 2,
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(_externalLatitude!, _externalLongitude!),
                              width: 48,
                              height: 48,
                              child: Icon(
                                Icons.gps_fixed,
                                color: _markerColor(colorScheme),
                                size: 36,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Zunanja GNSS pozicija', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _buildPositionRow(
                    'Koordinate',
                    _externalLatitude == null || _externalLongitude == null
                        ? '-'
                        : '${_externalLatitude!.toStringAsFixed(8)}, ${_externalLongitude!.toStringAsFixed(8)}',
                  ),
                  _buildPositionRow(
                    'Višina',
                    _externalAltitude == null ? '-' : '${_externalAltitude!.toStringAsFixed(2)} m',
                  ),
                  _buildPositionRow(
                    'Sateliti',
                    _externalSatellites == null ? '-' : _externalSatellites.toString(),
                  ),
                  _buildPositionRow(
                    'HDOP',
                    _externalHdop == null ? '-' : _externalHdop!.toStringAsFixed(1),
                  ),
                  _buildPositionRow('Fix', _fixQualityLabel()),
                  _buildAccuracyChecklist(context),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Gozdar-RTK naprava', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _isScanning || _isBleConnecting ? null : _scan,
                    icon: _isScanning || _isBleConnecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bluetooth_searching),
                    label: Text(
                      _isBleConnecting
                          ? 'Povezujem...'
                          : _isScanning
                          ? 'Iščem...'
                          : 'Poišči napravo',
                    ),
                  ),
                  if (_isBleConnected) ...[
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => _disconnectBle(updateStatus: true),
                      icon: const Icon(Icons.bluetooth_disabled),
                      label: const Text('Prekini GNSS'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  for (final result in _devices)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.bluetooth),
                      title: Text(result.advertisementData.advName),
                      subtitle: Text('${result.device.remoteId.str}  RSSI ${result.rssi}'),
                      trailing: FilledButton(
                        onPressed: _isBleConnecting
                            ? null
                            : _device?.remoteId == result.device.remoteId
                            ? () => _disconnectBle(updateStatus: true)
                            : () => _connectBle(result.device),
                        child: Text(
                          _device?.remoteId == result.device.remoteId ? 'Prekini' : 'Poveži',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('NTRIP', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              _ntripSetupSummary(),
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() => _isNtripSetupExpanded = !_isNtripSetupExpanded);
                        },
                        icon: Icon(
                          _isNtripSetupExpanded ? Icons.expand_less : Icons.edit,
                        ),
                        tooltip: _isNtripSetupExpanded ? 'Skrij nastavitve' : 'Uredi NTRIP',
                      ),
                    ],
                  ),
                  if (_isNtripSetupExpanded) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _hostController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'RTKdata EU caster',
                        helperText: 'EU only: eu.rtkdata.com',
                      ),
                    ),
                    TextField(
                      controller: _portController,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: 'Port'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: _mountController,
                      decoration: const InputDecoration(
                        labelText: 'Mountpoint',
                        helperText: 'Use AUTO unless RTKdata gave you another EU mountpoint',
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'RTKdata RTK username',
                        helperText: 'Starts with rtk; not your website login',
                      ),
                    ),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'RTKdata RTK password',
                        helperText: 'From RTK Credentials',
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('Shrani in skrij'),
                          onPressed: _saveSettingsAndCollapse,
                        ),
                        ActionChip(
                          label: const Text('Reset EU defaults'),
                          onPressed: () => _setRegion('eu.rtkdata.com'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _isCasterConnecting
                        ? null
                        : _isCasterConnected
                        ? () => _disconnectCaster(updateStatus: true)
                        : _connectCaster,
                    icon: _isCasterConnecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_isCasterConnected ? Icons.link_off : Icons.link),
                    label: Text(
                      _isCasterConnecting
                          ? 'Povezujem NTRIP...'
                          : _isCasterConnected
                          ? 'Prekini NTRIP'
                          : 'Poveži NTRIP',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GNSS podatki', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('GGA: ${_latestGga.isEmpty ? '-' : _latestGga}'),
                  const SizedBox(height: 8),
                  Text('Zadnji NMEA: ${_latestNmea.isEmpty ? '-' : _latestNmea}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
