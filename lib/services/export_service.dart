import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/log_entry.dart';

class ExportService {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  /// Exports logs to Excel format and opens share sheet
  static Future<void> exportToExcel(List<LogEntry> logs) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Hlodi'];

      // Remove default sheet
      excel.delete('Sheet1');

      // Add headers
      final headers = ['ID', 'Premer (cm)', 'Dolžina (m)', 'Volumen (m³)', 'Lat', 'Lon', 'Opombe', 'Datum'];
      for (var i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = TextCellValue(headers[i]);
      }

      // Add data rows
      for (var rowIndex = 0; rowIndex < logs.length; rowIndex++) {
        final log = logs[rowIndex];
        final row = rowIndex + 1;

        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = IntCellValue(log.id ?? 0);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = log.diameter != null ? DoubleCellValue(log.diameter!) : TextCellValue('');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = log.length != null ? DoubleCellValue(log.length!) : TextCellValue('');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value = DoubleCellValue(log.volume);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value = log.latitude != null ? DoubleCellValue(log.latitude!) : TextCellValue('');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value = log.longitude != null ? DoubleCellValue(log.longitude!) : TextCellValue('');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value = TextCellValue(log.notes ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value = TextCellValue(_dateFormat.format(log.createdAt));
      }

      // Write to temporary file
      final Directory tempDir = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String filePath = '${tempDir.path}/gozdar_hlodi_$timestamp.xlsx';
      final File file = File(filePath);
      final bytes = excel.encode();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
      }

      // Share the file
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          subject: 'Gozdar Hlodi Export',
          text: 'Izvoženih ${logs.length} vnosov',
        ),
      );
    } catch (e) {
      throw Exception('Failed to export Excel: $e');
    }
  }

  /// Exports logs to JSON format and opens share sheet
  static Future<void> exportToJson(List<LogEntry> logs) async {
    try {
      // Create JSON content
      final List<Map<String, dynamic>> jsonList = logs.map((log) {
        return {
          'id': log.id,
          'diameter': log.diameter,
          'length': log.length,
          'volume': log.volume,
          'latitude': log.latitude,
          'longitude': log.longitude,
          'notes': log.notes,
          'createdAt': _dateFormat.format(log.createdAt),
        };
      }).toList();

      final String jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);

      // Write to temporary file
      final Directory tempDir = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String filePath = '${tempDir.path}/gozdar_logs_$timestamp.json';
      final File file = File(filePath);
      await file.writeAsString(jsonString);

      // Share the file
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          subject: 'Gozdar Logs Export',
          text: 'Exported ${logs.length} log entries',
        ),
      );
    } catch (e) {
      throw Exception('Failed to export JSON: $e');
    }
  }
}
