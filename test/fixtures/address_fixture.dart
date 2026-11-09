import 'dart:io';

import 'package:gozdar/services/address_lookup_service.dart';
import 'package:sqlite3/sqlite3.dart';

/// Builds a small address database in the shape of
/// `tools/parcels/build_addresses.py` and opens it in the service.
///
/// Babno Polje numbers its houses without streets; Kranj has three streets
/// and one house without a street.
String openAddressFixture(Directory dir) {
  final path = '${dir.path}/addresses.sqlite';
  sqlite3.open(path)
    ..execute('CREATE TABLE meta (k TEXT PRIMARY KEY, v TEXT)')
    ..execute(
      "INSERT INTO meta VALUES ('built','2026-11-09T12:43:25Z'),('rows','7')",
    )
    ..execute('CREATE TABLE municipalities (id INTEGER PRIMARY KEY, name TEXT)')
    ..execute(
      "INSERT INTO municipalities VALUES (1,'Loška dolina'),(2,'Kranj')",
    )
    ..execute(
      'CREATE TABLE posts (id INTEGER PRIMARY KEY, code INTEGER, name TEXT)',
    )
    ..execute(
      "INSERT INTO posts VALUES (10,1386,'Stari trg pri Ložu'),(20,4000,'Kranj')",
    )
    ..execute(
      'CREATE TABLE settlements (id INTEGER PRIMARY KEY, name TEXT, '
      'municipality_id INTEGER)',
    )
    ..execute(
      "INSERT INTO settlements VALUES (100,'Babno Polje',1),(200,'Kranj',2)",
    )
    ..execute(
      'CREATE TABLE streets (id INTEGER PRIMARY KEY, name TEXT, '
      'settlement_id INTEGER)',
    )
    ..execute(
      "INSERT INTO streets VALUES (300,'Poljska ulica',200),"
      "(301,'Jerebova ulica',200),(302,'Šorlijeva ulica',200)",
    )
    ..execute(
      'CREATE TABLE addresses (id INTEGER PRIMARY KEY, number TEXT, '
      'street_id INTEGER, settlement_id INTEGER, post_id INTEGER, '
      'lat_e7 INTEGER, lon_e7 INTEGER, building INTEGER)',
    )
    ..execute(
      'INSERT INTO addresses VALUES '
      "(1,'12',NULL,100,10,456430000,145330000,9001),"
      "(2,'12A',NULL,100,10,456431000,145331000,9002),"
      "(3,'15',300,200,20,462400000,143550000,9003),"
      "(4,'12',300,200,20,462401000,143551000,9004),"
      "(5,'12',301,200,20,462402000,143552000,9005),"
      "(6,'7',302,200,20,462403000,143553000,9006),"
      "(7,'3',NULL,200,20,462404000,143554000,9007)",
    )
    ..close();
  AddressLookupService.instance.openForTesting(path);
  return path;
}
