// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ParcelsTable extends Parcels with TableInfo<$ParcelsTable, DbParcel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ParcelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _polygonJsonMeta = const VerificationMeta(
    'polygonJson',
  );
  @override
  late final GeneratedColumn<String> polygonJson = GeneratedColumn<String>(
    'polygon_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cadastralMunicipalityMeta =
      const VerificationMeta('cadastralMunicipality');
  @override
  late final GeneratedColumn<int> cadastralMunicipality = GeneratedColumn<int>(
    'cadastral_municipality',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parcelNumberMeta = const VerificationMeta(
    'parcelNumber',
  );
  @override
  late final GeneratedColumn<String> parcelNumber = GeneratedColumn<String>(
    'parcel_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
    'owner',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _forestTypeIndexMeta = const VerificationMeta(
    'forestTypeIndex',
  );
  @override
  late final GeneratedColumn<int> forestTypeIndex = GeneratedColumn<int>(
    'forest_type_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _woodAllowanceMeta = const VerificationMeta(
    'woodAllowance',
  );
  @override
  late final GeneratedColumn<double> woodAllowance = GeneratedColumn<double>(
    'wood_allowance',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _woodCutMeta = const VerificationMeta(
    'woodCut',
  );
  @override
  late final GeneratedColumn<double> woodCut = GeneratedColumn<double>(
    'wood_cut',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _treesCutMeta = const VerificationMeta(
    'treesCut',
  );
  @override
  late final GeneratedColumn<int> treesCut = GeneratedColumn<int>(
    'trees_cut',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    polygonJson,
    createdAt,
    cadastralMunicipality,
    parcelNumber,
    owner,
    notes,
    forestTypeIndex,
    woodAllowance,
    woodCut,
    treesCut,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'parcels';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbParcel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('polygon_json')) {
      context.handle(
        _polygonJsonMeta,
        polygonJson.isAcceptableOrUnknown(
          data['polygon_json']!,
          _polygonJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_polygonJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('cadastral_municipality')) {
      context.handle(
        _cadastralMunicipalityMeta,
        cadastralMunicipality.isAcceptableOrUnknown(
          data['cadastral_municipality']!,
          _cadastralMunicipalityMeta,
        ),
      );
    }
    if (data.containsKey('parcel_number')) {
      context.handle(
        _parcelNumberMeta,
        parcelNumber.isAcceptableOrUnknown(
          data['parcel_number']!,
          _parcelNumberMeta,
        ),
      );
    }
    if (data.containsKey('owner')) {
      context.handle(
        _ownerMeta,
        owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('forest_type_index')) {
      context.handle(
        _forestTypeIndexMeta,
        forestTypeIndex.isAcceptableOrUnknown(
          data['forest_type_index']!,
          _forestTypeIndexMeta,
        ),
      );
    }
    if (data.containsKey('wood_allowance')) {
      context.handle(
        _woodAllowanceMeta,
        woodAllowance.isAcceptableOrUnknown(
          data['wood_allowance']!,
          _woodAllowanceMeta,
        ),
      );
    }
    if (data.containsKey('wood_cut')) {
      context.handle(
        _woodCutMeta,
        woodCut.isAcceptableOrUnknown(data['wood_cut']!, _woodCutMeta),
      );
    }
    if (data.containsKey('trees_cut')) {
      context.handle(
        _treesCutMeta,
        treesCut.isAcceptableOrUnknown(data['trees_cut']!, _treesCutMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbParcel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbParcel(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      polygonJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}polygon_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      cadastralMunicipality: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cadastral_municipality'],
      ),
      parcelNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parcel_number'],
      ),
      owner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      forestTypeIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}forest_type_index'],
      )!,
      woodAllowance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}wood_allowance'],
      )!,
      woodCut: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}wood_cut'],
      )!,
      treesCut: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trees_cut'],
      )!,
    );
  }

  @override
  $ParcelsTable createAlias(String alias) {
    return $ParcelsTable(attachedDatabase, alias);
  }
}

class DbParcel extends DataClass implements Insertable<DbParcel> {
  final int id;
  final String name;
  final String polygonJson;
  final DateTime createdAt;
  final int? cadastralMunicipality;
  final String? parcelNumber;
  final String? owner;
  final String? notes;
  final int forestTypeIndex;
  final double woodAllowance;
  final double woodCut;
  final int treesCut;
  const DbParcel({
    required this.id,
    required this.name,
    required this.polygonJson,
    required this.createdAt,
    this.cadastralMunicipality,
    this.parcelNumber,
    this.owner,
    this.notes,
    required this.forestTypeIndex,
    required this.woodAllowance,
    required this.woodCut,
    required this.treesCut,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['polygon_json'] = Variable<String>(polygonJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || cadastralMunicipality != null) {
      map['cadastral_municipality'] = Variable<int>(cadastralMunicipality);
    }
    if (!nullToAbsent || parcelNumber != null) {
      map['parcel_number'] = Variable<String>(parcelNumber);
    }
    if (!nullToAbsent || owner != null) {
      map['owner'] = Variable<String>(owner);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['forest_type_index'] = Variable<int>(forestTypeIndex);
    map['wood_allowance'] = Variable<double>(woodAllowance);
    map['wood_cut'] = Variable<double>(woodCut);
    map['trees_cut'] = Variable<int>(treesCut);
    return map;
  }

  ParcelsCompanion toCompanion(bool nullToAbsent) {
    return ParcelsCompanion(
      id: Value(id),
      name: Value(name),
      polygonJson: Value(polygonJson),
      createdAt: Value(createdAt),
      cadastralMunicipality: cadastralMunicipality == null && nullToAbsent
          ? const Value.absent()
          : Value(cadastralMunicipality),
      parcelNumber: parcelNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(parcelNumber),
      owner: owner == null && nullToAbsent
          ? const Value.absent()
          : Value(owner),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      forestTypeIndex: Value(forestTypeIndex),
      woodAllowance: Value(woodAllowance),
      woodCut: Value(woodCut),
      treesCut: Value(treesCut),
    );
  }

  factory DbParcel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbParcel(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      polygonJson: serializer.fromJson<String>(json['polygonJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      cadastralMunicipality: serializer.fromJson<int?>(
        json['cadastralMunicipality'],
      ),
      parcelNumber: serializer.fromJson<String?>(json['parcelNumber']),
      owner: serializer.fromJson<String?>(json['owner']),
      notes: serializer.fromJson<String?>(json['notes']),
      forestTypeIndex: serializer.fromJson<int>(json['forestTypeIndex']),
      woodAllowance: serializer.fromJson<double>(json['woodAllowance']),
      woodCut: serializer.fromJson<double>(json['woodCut']),
      treesCut: serializer.fromJson<int>(json['treesCut']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'polygonJson': serializer.toJson<String>(polygonJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'cadastralMunicipality': serializer.toJson<int?>(cadastralMunicipality),
      'parcelNumber': serializer.toJson<String?>(parcelNumber),
      'owner': serializer.toJson<String?>(owner),
      'notes': serializer.toJson<String?>(notes),
      'forestTypeIndex': serializer.toJson<int>(forestTypeIndex),
      'woodAllowance': serializer.toJson<double>(woodAllowance),
      'woodCut': serializer.toJson<double>(woodCut),
      'treesCut': serializer.toJson<int>(treesCut),
    };
  }

  DbParcel copyWith({
    int? id,
    String? name,
    String? polygonJson,
    DateTime? createdAt,
    Value<int?> cadastralMunicipality = const Value.absent(),
    Value<String?> parcelNumber = const Value.absent(),
    Value<String?> owner = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    int? forestTypeIndex,
    double? woodAllowance,
    double? woodCut,
    int? treesCut,
  }) => DbParcel(
    id: id ?? this.id,
    name: name ?? this.name,
    polygonJson: polygonJson ?? this.polygonJson,
    createdAt: createdAt ?? this.createdAt,
    cadastralMunicipality: cadastralMunicipality.present
        ? cadastralMunicipality.value
        : this.cadastralMunicipality,
    parcelNumber: parcelNumber.present ? parcelNumber.value : this.parcelNumber,
    owner: owner.present ? owner.value : this.owner,
    notes: notes.present ? notes.value : this.notes,
    forestTypeIndex: forestTypeIndex ?? this.forestTypeIndex,
    woodAllowance: woodAllowance ?? this.woodAllowance,
    woodCut: woodCut ?? this.woodCut,
    treesCut: treesCut ?? this.treesCut,
  );
  DbParcel copyWithCompanion(ParcelsCompanion data) {
    return DbParcel(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      polygonJson: data.polygonJson.present
          ? data.polygonJson.value
          : this.polygonJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      cadastralMunicipality: data.cadastralMunicipality.present
          ? data.cadastralMunicipality.value
          : this.cadastralMunicipality,
      parcelNumber: data.parcelNumber.present
          ? data.parcelNumber.value
          : this.parcelNumber,
      owner: data.owner.present ? data.owner.value : this.owner,
      notes: data.notes.present ? data.notes.value : this.notes,
      forestTypeIndex: data.forestTypeIndex.present
          ? data.forestTypeIndex.value
          : this.forestTypeIndex,
      woodAllowance: data.woodAllowance.present
          ? data.woodAllowance.value
          : this.woodAllowance,
      woodCut: data.woodCut.present ? data.woodCut.value : this.woodCut,
      treesCut: data.treesCut.present ? data.treesCut.value : this.treesCut,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbParcel(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('polygonJson: $polygonJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('cadastralMunicipality: $cadastralMunicipality, ')
          ..write('parcelNumber: $parcelNumber, ')
          ..write('owner: $owner, ')
          ..write('notes: $notes, ')
          ..write('forestTypeIndex: $forestTypeIndex, ')
          ..write('woodAllowance: $woodAllowance, ')
          ..write('woodCut: $woodCut, ')
          ..write('treesCut: $treesCut')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    polygonJson,
    createdAt,
    cadastralMunicipality,
    parcelNumber,
    owner,
    notes,
    forestTypeIndex,
    woodAllowance,
    woodCut,
    treesCut,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbParcel &&
          other.id == this.id &&
          other.name == this.name &&
          other.polygonJson == this.polygonJson &&
          other.createdAt == this.createdAt &&
          other.cadastralMunicipality == this.cadastralMunicipality &&
          other.parcelNumber == this.parcelNumber &&
          other.owner == this.owner &&
          other.notes == this.notes &&
          other.forestTypeIndex == this.forestTypeIndex &&
          other.woodAllowance == this.woodAllowance &&
          other.woodCut == this.woodCut &&
          other.treesCut == this.treesCut);
}

class ParcelsCompanion extends UpdateCompanion<DbParcel> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> polygonJson;
  final Value<DateTime> createdAt;
  final Value<int?> cadastralMunicipality;
  final Value<String?> parcelNumber;
  final Value<String?> owner;
  final Value<String?> notes;
  final Value<int> forestTypeIndex;
  final Value<double> woodAllowance;
  final Value<double> woodCut;
  final Value<int> treesCut;
  const ParcelsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.polygonJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.cadastralMunicipality = const Value.absent(),
    this.parcelNumber = const Value.absent(),
    this.owner = const Value.absent(),
    this.notes = const Value.absent(),
    this.forestTypeIndex = const Value.absent(),
    this.woodAllowance = const Value.absent(),
    this.woodCut = const Value.absent(),
    this.treesCut = const Value.absent(),
  });
  ParcelsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String polygonJson,
    required DateTime createdAt,
    this.cadastralMunicipality = const Value.absent(),
    this.parcelNumber = const Value.absent(),
    this.owner = const Value.absent(),
    this.notes = const Value.absent(),
    this.forestTypeIndex = const Value.absent(),
    this.woodAllowance = const Value.absent(),
    this.woodCut = const Value.absent(),
    this.treesCut = const Value.absent(),
  }) : name = Value(name),
       polygonJson = Value(polygonJson),
       createdAt = Value(createdAt);
  static Insertable<DbParcel> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? polygonJson,
    Expression<DateTime>? createdAt,
    Expression<int>? cadastralMunicipality,
    Expression<String>? parcelNumber,
    Expression<String>? owner,
    Expression<String>? notes,
    Expression<int>? forestTypeIndex,
    Expression<double>? woodAllowance,
    Expression<double>? woodCut,
    Expression<int>? treesCut,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (polygonJson != null) 'polygon_json': polygonJson,
      if (createdAt != null) 'created_at': createdAt,
      if (cadastralMunicipality != null)
        'cadastral_municipality': cadastralMunicipality,
      if (parcelNumber != null) 'parcel_number': parcelNumber,
      if (owner != null) 'owner': owner,
      if (notes != null) 'notes': notes,
      if (forestTypeIndex != null) 'forest_type_index': forestTypeIndex,
      if (woodAllowance != null) 'wood_allowance': woodAllowance,
      if (woodCut != null) 'wood_cut': woodCut,
      if (treesCut != null) 'trees_cut': treesCut,
    });
  }

  ParcelsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? polygonJson,
    Value<DateTime>? createdAt,
    Value<int?>? cadastralMunicipality,
    Value<String?>? parcelNumber,
    Value<String?>? owner,
    Value<String?>? notes,
    Value<int>? forestTypeIndex,
    Value<double>? woodAllowance,
    Value<double>? woodCut,
    Value<int>? treesCut,
  }) {
    return ParcelsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      polygonJson: polygonJson ?? this.polygonJson,
      createdAt: createdAt ?? this.createdAt,
      cadastralMunicipality:
          cadastralMunicipality ?? this.cadastralMunicipality,
      parcelNumber: parcelNumber ?? this.parcelNumber,
      owner: owner ?? this.owner,
      notes: notes ?? this.notes,
      forestTypeIndex: forestTypeIndex ?? this.forestTypeIndex,
      woodAllowance: woodAllowance ?? this.woodAllowance,
      woodCut: woodCut ?? this.woodCut,
      treesCut: treesCut ?? this.treesCut,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (polygonJson.present) {
      map['polygon_json'] = Variable<String>(polygonJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (cadastralMunicipality.present) {
      map['cadastral_municipality'] = Variable<int>(
        cadastralMunicipality.value,
      );
    }
    if (parcelNumber.present) {
      map['parcel_number'] = Variable<String>(parcelNumber.value);
    }
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (forestTypeIndex.present) {
      map['forest_type_index'] = Variable<int>(forestTypeIndex.value);
    }
    if (woodAllowance.present) {
      map['wood_allowance'] = Variable<double>(woodAllowance.value);
    }
    if (woodCut.present) {
      map['wood_cut'] = Variable<double>(woodCut.value);
    }
    if (treesCut.present) {
      map['trees_cut'] = Variable<int>(treesCut.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ParcelsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('polygonJson: $polygonJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('cadastralMunicipality: $cadastralMunicipality, ')
          ..write('parcelNumber: $parcelNumber, ')
          ..write('owner: $owner, ')
          ..write('notes: $notes, ')
          ..write('forestTypeIndex: $forestTypeIndex, ')
          ..write('woodAllowance: $woodAllowance, ')
          ..write('woodCut: $woodCut, ')
          ..write('treesCut: $treesCut')
          ..write(')'))
        .toString();
  }
}

class $LogBatchesTable extends LogBatches
    with TableInfo<$LogBatchesTable, DbLogBatch> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LogBatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
    'owner',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalVolumeMeta = const VerificationMeta(
    'totalVolume',
  );
  @override
  late final GeneratedColumn<double> totalVolume = GeneratedColumn<double>(
    'total_volume',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _logCountMeta = const VerificationMeta(
    'logCount',
  );
  @override
  late final GeneratedColumn<int> logCount = GeneratedColumn<int>(
    'log_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    owner,
    notes,
    latitude,
    longitude,
    totalVolume,
    logCount,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'log_batches';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbLogBatch> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('owner')) {
      context.handle(
        _ownerMeta,
        owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('total_volume')) {
      context.handle(
        _totalVolumeMeta,
        totalVolume.isAcceptableOrUnknown(
          data['total_volume']!,
          _totalVolumeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalVolumeMeta);
    }
    if (data.containsKey('log_count')) {
      context.handle(
        _logCountMeta,
        logCount.isAcceptableOrUnknown(data['log_count']!, _logCountMeta),
      );
    } else if (isInserting) {
      context.missing(_logCountMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbLogBatch map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbLogBatch(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      owner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      totalVolume: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_volume'],
      )!,
      logCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}log_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LogBatchesTable createAlias(String alias) {
    return $LogBatchesTable(attachedDatabase, alias);
  }
}

class DbLogBatch extends DataClass implements Insertable<DbLogBatch> {
  final int id;
  final String? owner;
  final String? notes;
  final double? latitude;
  final double? longitude;
  final double totalVolume;
  final int logCount;
  final DateTime createdAt;
  const DbLogBatch({
    required this.id,
    this.owner,
    this.notes,
    this.latitude,
    this.longitude,
    required this.totalVolume,
    required this.logCount,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || owner != null) {
      map['owner'] = Variable<String>(owner);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    map['total_volume'] = Variable<double>(totalVolume);
    map['log_count'] = Variable<int>(logCount);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LogBatchesCompanion toCompanion(bool nullToAbsent) {
    return LogBatchesCompanion(
      id: Value(id),
      owner: owner == null && nullToAbsent
          ? const Value.absent()
          : Value(owner),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      totalVolume: Value(totalVolume),
      logCount: Value(logCount),
      createdAt: Value(createdAt),
    );
  }

  factory DbLogBatch.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbLogBatch(
      id: serializer.fromJson<int>(json['id']),
      owner: serializer.fromJson<String?>(json['owner']),
      notes: serializer.fromJson<String?>(json['notes']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      totalVolume: serializer.fromJson<double>(json['totalVolume']),
      logCount: serializer.fromJson<int>(json['logCount']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'owner': serializer.toJson<String?>(owner),
      'notes': serializer.toJson<String?>(notes),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'totalVolume': serializer.toJson<double>(totalVolume),
      'logCount': serializer.toJson<int>(logCount),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DbLogBatch copyWith({
    int? id,
    Value<String?> owner = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    double? totalVolume,
    int? logCount,
    DateTime? createdAt,
  }) => DbLogBatch(
    id: id ?? this.id,
    owner: owner.present ? owner.value : this.owner,
    notes: notes.present ? notes.value : this.notes,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    totalVolume: totalVolume ?? this.totalVolume,
    logCount: logCount ?? this.logCount,
    createdAt: createdAt ?? this.createdAt,
  );
  DbLogBatch copyWithCompanion(LogBatchesCompanion data) {
    return DbLogBatch(
      id: data.id.present ? data.id.value : this.id,
      owner: data.owner.present ? data.owner.value : this.owner,
      notes: data.notes.present ? data.notes.value : this.notes,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      totalVolume: data.totalVolume.present
          ? data.totalVolume.value
          : this.totalVolume,
      logCount: data.logCount.present ? data.logCount.value : this.logCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbLogBatch(')
          ..write('id: $id, ')
          ..write('owner: $owner, ')
          ..write('notes: $notes, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('totalVolume: $totalVolume, ')
          ..write('logCount: $logCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    owner,
    notes,
    latitude,
    longitude,
    totalVolume,
    logCount,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbLogBatch &&
          other.id == this.id &&
          other.owner == this.owner &&
          other.notes == this.notes &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.totalVolume == this.totalVolume &&
          other.logCount == this.logCount &&
          other.createdAt == this.createdAt);
}

class LogBatchesCompanion extends UpdateCompanion<DbLogBatch> {
  final Value<int> id;
  final Value<String?> owner;
  final Value<String?> notes;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<double> totalVolume;
  final Value<int> logCount;
  final Value<DateTime> createdAt;
  const LogBatchesCompanion({
    this.id = const Value.absent(),
    this.owner = const Value.absent(),
    this.notes = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.totalVolume = const Value.absent(),
    this.logCount = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LogBatchesCompanion.insert({
    this.id = const Value.absent(),
    this.owner = const Value.absent(),
    this.notes = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    required double totalVolume,
    required int logCount,
    required DateTime createdAt,
  }) : totalVolume = Value(totalVolume),
       logCount = Value(logCount),
       createdAt = Value(createdAt);
  static Insertable<DbLogBatch> custom({
    Expression<int>? id,
    Expression<String>? owner,
    Expression<String>? notes,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? totalVolume,
    Expression<int>? logCount,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (owner != null) 'owner': owner,
      if (notes != null) 'notes': notes,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (totalVolume != null) 'total_volume': totalVolume,
      if (logCount != null) 'log_count': logCount,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LogBatchesCompanion copyWith({
    Value<int>? id,
    Value<String?>? owner,
    Value<String?>? notes,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<double>? totalVolume,
    Value<int>? logCount,
    Value<DateTime>? createdAt,
  }) {
    return LogBatchesCompanion(
      id: id ?? this.id,
      owner: owner ?? this.owner,
      notes: notes ?? this.notes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      totalVolume: totalVolume ?? this.totalVolume,
      logCount: logCount ?? this.logCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (totalVolume.present) {
      map['total_volume'] = Variable<double>(totalVolume.value);
    }
    if (logCount.present) {
      map['log_count'] = Variable<int>(logCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LogBatchesCompanion(')
          ..write('id: $id, ')
          ..write('owner: $owner, ')
          ..write('notes: $notes, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('totalVolume: $totalVolume, ')
          ..write('logCount: $logCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $LogEntriesTable extends LogEntries
    with TableInfo<$LogEntriesTable, DbLogEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LogEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _diameterMeta = const VerificationMeta(
    'diameter',
  );
  @override
  late final GeneratedColumn<double> diameter = GeneratedColumn<double>(
    'diameter',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lengthMeta = const VerificationMeta('length');
  @override
  late final GeneratedColumn<double> length = GeneratedColumn<double>(
    'length',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _volumeMeta = const VerificationMeta('volume');
  @override
  late final GeneratedColumn<double> volume = GeneratedColumn<double>(
    'volume',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _speciesMeta = const VerificationMeta(
    'species',
  );
  @override
  late final GeneratedColumn<String> species = GeneratedColumn<String>(
    'species',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _batchIdMeta = const VerificationMeta(
    'batchId',
  );
  @override
  late final GeneratedColumn<int> batchId = GeneratedColumn<int>(
    'batch_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES log_batches (id)',
    ),
  );
  static const VerificationMeta _parcelIdMeta = const VerificationMeta(
    'parcelId',
  );
  @override
  late final GeneratedColumn<int> parcelId = GeneratedColumn<int>(
    'parcel_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES parcels (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    diameter,
    length,
    volume,
    latitude,
    longitude,
    notes,
    species,
    createdAt,
    batchId,
    parcelId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'log_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbLogEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('diameter')) {
      context.handle(
        _diameterMeta,
        diameter.isAcceptableOrUnknown(data['diameter']!, _diameterMeta),
      );
    }
    if (data.containsKey('length')) {
      context.handle(
        _lengthMeta,
        length.isAcceptableOrUnknown(data['length']!, _lengthMeta),
      );
    }
    if (data.containsKey('volume')) {
      context.handle(
        _volumeMeta,
        volume.isAcceptableOrUnknown(data['volume']!, _volumeMeta),
      );
    } else if (isInserting) {
      context.missing(_volumeMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('species')) {
      context.handle(
        _speciesMeta,
        species.isAcceptableOrUnknown(data['species']!, _speciesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('batch_id')) {
      context.handle(
        _batchIdMeta,
        batchId.isAcceptableOrUnknown(data['batch_id']!, _batchIdMeta),
      );
    }
    if (data.containsKey('parcel_id')) {
      context.handle(
        _parcelIdMeta,
        parcelId.isAcceptableOrUnknown(data['parcel_id']!, _parcelIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbLogEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbLogEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      diameter: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}diameter'],
      ),
      length: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}length'],
      ),
      volume: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}volume'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      species: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}species'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      batchId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}batch_id'],
      ),
      parcelId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parcel_id'],
      ),
    );
  }

  @override
  $LogEntriesTable createAlias(String alias) {
    return $LogEntriesTable(attachedDatabase, alias);
  }
}

class DbLogEntry extends DataClass implements Insertable<DbLogEntry> {
  final int id;
  final double? diameter;
  final double? length;
  final double volume;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final String? species;
  final DateTime createdAt;
  final int? batchId;
  final int? parcelId;
  const DbLogEntry({
    required this.id,
    this.diameter,
    this.length,
    required this.volume,
    this.latitude,
    this.longitude,
    this.notes,
    this.species,
    required this.createdAt,
    this.batchId,
    this.parcelId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || diameter != null) {
      map['diameter'] = Variable<double>(diameter);
    }
    if (!nullToAbsent || length != null) {
      map['length'] = Variable<double>(length);
    }
    map['volume'] = Variable<double>(volume);
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || species != null) {
      map['species'] = Variable<String>(species);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || batchId != null) {
      map['batch_id'] = Variable<int>(batchId);
    }
    if (!nullToAbsent || parcelId != null) {
      map['parcel_id'] = Variable<int>(parcelId);
    }
    return map;
  }

  LogEntriesCompanion toCompanion(bool nullToAbsent) {
    return LogEntriesCompanion(
      id: Value(id),
      diameter: diameter == null && nullToAbsent
          ? const Value.absent()
          : Value(diameter),
      length: length == null && nullToAbsent
          ? const Value.absent()
          : Value(length),
      volume: Value(volume),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      species: species == null && nullToAbsent
          ? const Value.absent()
          : Value(species),
      createdAt: Value(createdAt),
      batchId: batchId == null && nullToAbsent
          ? const Value.absent()
          : Value(batchId),
      parcelId: parcelId == null && nullToAbsent
          ? const Value.absent()
          : Value(parcelId),
    );
  }

  factory DbLogEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbLogEntry(
      id: serializer.fromJson<int>(json['id']),
      diameter: serializer.fromJson<double?>(json['diameter']),
      length: serializer.fromJson<double?>(json['length']),
      volume: serializer.fromJson<double>(json['volume']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      notes: serializer.fromJson<String?>(json['notes']),
      species: serializer.fromJson<String?>(json['species']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      batchId: serializer.fromJson<int?>(json['batchId']),
      parcelId: serializer.fromJson<int?>(json['parcelId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'diameter': serializer.toJson<double?>(diameter),
      'length': serializer.toJson<double?>(length),
      'volume': serializer.toJson<double>(volume),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'notes': serializer.toJson<String?>(notes),
      'species': serializer.toJson<String?>(species),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'batchId': serializer.toJson<int?>(batchId),
      'parcelId': serializer.toJson<int?>(parcelId),
    };
  }

  DbLogEntry copyWith({
    int? id,
    Value<double?> diameter = const Value.absent(),
    Value<double?> length = const Value.absent(),
    double? volume,
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> species = const Value.absent(),
    DateTime? createdAt,
    Value<int?> batchId = const Value.absent(),
    Value<int?> parcelId = const Value.absent(),
  }) => DbLogEntry(
    id: id ?? this.id,
    diameter: diameter.present ? diameter.value : this.diameter,
    length: length.present ? length.value : this.length,
    volume: volume ?? this.volume,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    notes: notes.present ? notes.value : this.notes,
    species: species.present ? species.value : this.species,
    createdAt: createdAt ?? this.createdAt,
    batchId: batchId.present ? batchId.value : this.batchId,
    parcelId: parcelId.present ? parcelId.value : this.parcelId,
  );
  DbLogEntry copyWithCompanion(LogEntriesCompanion data) {
    return DbLogEntry(
      id: data.id.present ? data.id.value : this.id,
      diameter: data.diameter.present ? data.diameter.value : this.diameter,
      length: data.length.present ? data.length.value : this.length,
      volume: data.volume.present ? data.volume.value : this.volume,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      notes: data.notes.present ? data.notes.value : this.notes,
      species: data.species.present ? data.species.value : this.species,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      batchId: data.batchId.present ? data.batchId.value : this.batchId,
      parcelId: data.parcelId.present ? data.parcelId.value : this.parcelId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbLogEntry(')
          ..write('id: $id, ')
          ..write('diameter: $diameter, ')
          ..write('length: $length, ')
          ..write('volume: $volume, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('notes: $notes, ')
          ..write('species: $species, ')
          ..write('createdAt: $createdAt, ')
          ..write('batchId: $batchId, ')
          ..write('parcelId: $parcelId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    diameter,
    length,
    volume,
    latitude,
    longitude,
    notes,
    species,
    createdAt,
    batchId,
    parcelId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbLogEntry &&
          other.id == this.id &&
          other.diameter == this.diameter &&
          other.length == this.length &&
          other.volume == this.volume &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.notes == this.notes &&
          other.species == this.species &&
          other.createdAt == this.createdAt &&
          other.batchId == this.batchId &&
          other.parcelId == this.parcelId);
}

class LogEntriesCompanion extends UpdateCompanion<DbLogEntry> {
  final Value<int> id;
  final Value<double?> diameter;
  final Value<double?> length;
  final Value<double> volume;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<String?> notes;
  final Value<String?> species;
  final Value<DateTime> createdAt;
  final Value<int?> batchId;
  final Value<int?> parcelId;
  const LogEntriesCompanion({
    this.id = const Value.absent(),
    this.diameter = const Value.absent(),
    this.length = const Value.absent(),
    this.volume = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.notes = const Value.absent(),
    this.species = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.batchId = const Value.absent(),
    this.parcelId = const Value.absent(),
  });
  LogEntriesCompanion.insert({
    this.id = const Value.absent(),
    this.diameter = const Value.absent(),
    this.length = const Value.absent(),
    required double volume,
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.notes = const Value.absent(),
    this.species = const Value.absent(),
    required DateTime createdAt,
    this.batchId = const Value.absent(),
    this.parcelId = const Value.absent(),
  }) : volume = Value(volume),
       createdAt = Value(createdAt);
  static Insertable<DbLogEntry> custom({
    Expression<int>? id,
    Expression<double>? diameter,
    Expression<double>? length,
    Expression<double>? volume,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? notes,
    Expression<String>? species,
    Expression<DateTime>? createdAt,
    Expression<int>? batchId,
    Expression<int>? parcelId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (diameter != null) 'diameter': diameter,
      if (length != null) 'length': length,
      if (volume != null) 'volume': volume,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (notes != null) 'notes': notes,
      if (species != null) 'species': species,
      if (createdAt != null) 'created_at': createdAt,
      if (batchId != null) 'batch_id': batchId,
      if (parcelId != null) 'parcel_id': parcelId,
    });
  }

  LogEntriesCompanion copyWith({
    Value<int>? id,
    Value<double?>? diameter,
    Value<double?>? length,
    Value<double>? volume,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<String?>? notes,
    Value<String?>? species,
    Value<DateTime>? createdAt,
    Value<int?>? batchId,
    Value<int?>? parcelId,
  }) {
    return LogEntriesCompanion(
      id: id ?? this.id,
      diameter: diameter ?? this.diameter,
      length: length ?? this.length,
      volume: volume ?? this.volume,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
      species: species ?? this.species,
      createdAt: createdAt ?? this.createdAt,
      batchId: batchId ?? this.batchId,
      parcelId: parcelId ?? this.parcelId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (diameter.present) {
      map['diameter'] = Variable<double>(diameter.value);
    }
    if (length.present) {
      map['length'] = Variable<double>(length.value);
    }
    if (volume.present) {
      map['volume'] = Variable<double>(volume.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (species.present) {
      map['species'] = Variable<String>(species.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (batchId.present) {
      map['batch_id'] = Variable<int>(batchId.value);
    }
    if (parcelId.present) {
      map['parcel_id'] = Variable<int>(parcelId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LogEntriesCompanion(')
          ..write('id: $id, ')
          ..write('diameter: $diameter, ')
          ..write('length: $length, ')
          ..write('volume: $volume, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('notes: $notes, ')
          ..write('species: $species, ')
          ..write('createdAt: $createdAt, ')
          ..write('batchId: $batchId, ')
          ..write('parcelId: $parcelId')
          ..write(')'))
        .toString();
  }
}

class $MapLocationsTable extends MapLocations
    with TableInfo<$MapLocationsTable, DbMapLocation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MapLocationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeIndexMeta = const VerificationMeta(
    'typeIndex',
  );
  @override
  late final GeneratedColumn<int> typeIndex = GeneratedColumn<int>(
    'type_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    latitude,
    longitude,
    typeIndex,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'map_locations';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbMapLocation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('type_index')) {
      context.handle(
        _typeIndexMeta,
        typeIndex.isAcceptableOrUnknown(data['type_index']!, _typeIndexMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbMapLocation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbMapLocation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      typeIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type_index'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MapLocationsTable createAlias(String alias) {
    return $MapLocationsTable(attachedDatabase, alias);
  }
}

class DbMapLocation extends DataClass implements Insertable<DbMapLocation> {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final int typeIndex;
  final DateTime createdAt;
  const DbMapLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.typeIndex,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['type_index'] = Variable<int>(typeIndex);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MapLocationsCompanion toCompanion(bool nullToAbsent) {
    return MapLocationsCompanion(
      id: Value(id),
      name: Value(name),
      latitude: Value(latitude),
      longitude: Value(longitude),
      typeIndex: Value(typeIndex),
      createdAt: Value(createdAt),
    );
  }

  factory DbMapLocation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbMapLocation(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      typeIndex: serializer.fromJson<int>(json['typeIndex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'typeIndex': serializer.toJson<int>(typeIndex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DbMapLocation copyWith({
    int? id,
    String? name,
    double? latitude,
    double? longitude,
    int? typeIndex,
    DateTime? createdAt,
  }) => DbMapLocation(
    id: id ?? this.id,
    name: name ?? this.name,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    typeIndex: typeIndex ?? this.typeIndex,
    createdAt: createdAt ?? this.createdAt,
  );
  DbMapLocation copyWithCompanion(MapLocationsCompanion data) {
    return DbMapLocation(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      typeIndex: data.typeIndex.present ? data.typeIndex.value : this.typeIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbMapLocation(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('typeIndex: $typeIndex, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, latitude, longitude, typeIndex, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbMapLocation &&
          other.id == this.id &&
          other.name == this.name &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.typeIndex == this.typeIndex &&
          other.createdAt == this.createdAt);
}

class MapLocationsCompanion extends UpdateCompanion<DbMapLocation> {
  final Value<int> id;
  final Value<String> name;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<int> typeIndex;
  final Value<DateTime> createdAt;
  const MapLocationsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.typeIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  MapLocationsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required double latitude,
    required double longitude,
    this.typeIndex = const Value.absent(),
    required DateTime createdAt,
  }) : name = Value(name),
       latitude = Value(latitude),
       longitude = Value(longitude),
       createdAt = Value(createdAt);
  static Insertable<DbMapLocation> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<int>? typeIndex,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (typeIndex != null) 'type_index': typeIndex,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  MapLocationsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<int>? typeIndex,
    Value<DateTime>? createdAt,
  }) {
    return MapLocationsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      typeIndex: typeIndex ?? this.typeIndex,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (typeIndex.present) {
      map['type_index'] = Variable<int>(typeIndex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MapLocationsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('typeIndex: $typeIndex, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ImportedOverlaysTable extends ImportedOverlays
    with TableInfo<$ImportedOverlaysTable, DbImportedOverlay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportedOverlaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _layerNameMeta = const VerificationMeta(
    'layerName',
  );
  @override
  late final GeneratedColumn<String> layerName = GeneratedColumn<String>(
    'layer_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _geometryTypeMeta = const VerificationMeta(
    'geometryType',
  );
  @override
  late final GeneratedColumn<String> geometryType = GeneratedColumn<String>(
    'geometry_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _geometryJsonMeta = const VerificationMeta(
    'geometryJson',
  );
  @override
  late final GeneratedColumn<String> geometryJson = GeneratedColumn<String>(
    'geometry_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _propertiesMeta = const VerificationMeta(
    'properties',
  );
  @override
  late final GeneratedColumn<String> properties = GeneratedColumn<String>(
    'properties',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _visibleMeta = const VerificationMeta(
    'visible',
  );
  @override
  late final GeneratedColumn<bool> visible = GeneratedColumn<bool>(
    'visible',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("visible" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    layerName,
    geometryType,
    geometryJson,
    properties,
    colorValue,
    visible,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'imported_overlays';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbImportedOverlay> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('layer_name')) {
      context.handle(
        _layerNameMeta,
        layerName.isAcceptableOrUnknown(data['layer_name']!, _layerNameMeta),
      );
    } else if (isInserting) {
      context.missing(_layerNameMeta);
    }
    if (data.containsKey('geometry_type')) {
      context.handle(
        _geometryTypeMeta,
        geometryType.isAcceptableOrUnknown(
          data['geometry_type']!,
          _geometryTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_geometryTypeMeta);
    }
    if (data.containsKey('geometry_json')) {
      context.handle(
        _geometryJsonMeta,
        geometryJson.isAcceptableOrUnknown(
          data['geometry_json']!,
          _geometryJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_geometryJsonMeta);
    }
    if (data.containsKey('properties')) {
      context.handle(
        _propertiesMeta,
        properties.isAcceptableOrUnknown(data['properties']!, _propertiesMeta),
      );
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('visible')) {
      context.handle(
        _visibleMeta,
        visible.isAcceptableOrUnknown(data['visible']!, _visibleMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbImportedOverlay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbImportedOverlay(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      layerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layer_name'],
      )!,
      geometryType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}geometry_type'],
      )!,
      geometryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}geometry_json'],
      )!,
      properties: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}properties'],
      ),
      colorValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_value'],
      )!,
      visible: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}visible'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ImportedOverlaysTable createAlias(String alias) {
    return $ImportedOverlaysTable(attachedDatabase, alias);
  }
}

class DbImportedOverlay extends DataClass
    implements Insertable<DbImportedOverlay> {
  final int id;
  final String name;
  final String layerName;
  final String geometryType;
  final String geometryJson;
  final String? properties;
  final int colorValue;
  final bool visible;
  final DateTime createdAt;
  const DbImportedOverlay({
    required this.id,
    required this.name,
    required this.layerName,
    required this.geometryType,
    required this.geometryJson,
    this.properties,
    required this.colorValue,
    required this.visible,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['layer_name'] = Variable<String>(layerName);
    map['geometry_type'] = Variable<String>(geometryType);
    map['geometry_json'] = Variable<String>(geometryJson);
    if (!nullToAbsent || properties != null) {
      map['properties'] = Variable<String>(properties);
    }
    map['color_value'] = Variable<int>(colorValue);
    map['visible'] = Variable<bool>(visible);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ImportedOverlaysCompanion toCompanion(bool nullToAbsent) {
    return ImportedOverlaysCompanion(
      id: Value(id),
      name: Value(name),
      layerName: Value(layerName),
      geometryType: Value(geometryType),
      geometryJson: Value(geometryJson),
      properties: properties == null && nullToAbsent
          ? const Value.absent()
          : Value(properties),
      colorValue: Value(colorValue),
      visible: Value(visible),
      createdAt: Value(createdAt),
    );
  }

  factory DbImportedOverlay.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbImportedOverlay(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      layerName: serializer.fromJson<String>(json['layerName']),
      geometryType: serializer.fromJson<String>(json['geometryType']),
      geometryJson: serializer.fromJson<String>(json['geometryJson']),
      properties: serializer.fromJson<String?>(json['properties']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      visible: serializer.fromJson<bool>(json['visible']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'layerName': serializer.toJson<String>(layerName),
      'geometryType': serializer.toJson<String>(geometryType),
      'geometryJson': serializer.toJson<String>(geometryJson),
      'properties': serializer.toJson<String?>(properties),
      'colorValue': serializer.toJson<int>(colorValue),
      'visible': serializer.toJson<bool>(visible),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DbImportedOverlay copyWith({
    int? id,
    String? name,
    String? layerName,
    String? geometryType,
    String? geometryJson,
    Value<String?> properties = const Value.absent(),
    int? colorValue,
    bool? visible,
    DateTime? createdAt,
  }) => DbImportedOverlay(
    id: id ?? this.id,
    name: name ?? this.name,
    layerName: layerName ?? this.layerName,
    geometryType: geometryType ?? this.geometryType,
    geometryJson: geometryJson ?? this.geometryJson,
    properties: properties.present ? properties.value : this.properties,
    colorValue: colorValue ?? this.colorValue,
    visible: visible ?? this.visible,
    createdAt: createdAt ?? this.createdAt,
  );
  DbImportedOverlay copyWithCompanion(ImportedOverlaysCompanion data) {
    return DbImportedOverlay(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      layerName: data.layerName.present ? data.layerName.value : this.layerName,
      geometryType: data.geometryType.present
          ? data.geometryType.value
          : this.geometryType,
      geometryJson: data.geometryJson.present
          ? data.geometryJson.value
          : this.geometryJson,
      properties: data.properties.present
          ? data.properties.value
          : this.properties,
      colorValue: data.colorValue.present
          ? data.colorValue.value
          : this.colorValue,
      visible: data.visible.present ? data.visible.value : this.visible,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbImportedOverlay(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('layerName: $layerName, ')
          ..write('geometryType: $geometryType, ')
          ..write('geometryJson: $geometryJson, ')
          ..write('properties: $properties, ')
          ..write('colorValue: $colorValue, ')
          ..write('visible: $visible, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    layerName,
    geometryType,
    geometryJson,
    properties,
    colorValue,
    visible,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbImportedOverlay &&
          other.id == this.id &&
          other.name == this.name &&
          other.layerName == this.layerName &&
          other.geometryType == this.geometryType &&
          other.geometryJson == this.geometryJson &&
          other.properties == this.properties &&
          other.colorValue == this.colorValue &&
          other.visible == this.visible &&
          other.createdAt == this.createdAt);
}

class ImportedOverlaysCompanion extends UpdateCompanion<DbImportedOverlay> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> layerName;
  final Value<String> geometryType;
  final Value<String> geometryJson;
  final Value<String?> properties;
  final Value<int> colorValue;
  final Value<bool> visible;
  final Value<DateTime> createdAt;
  const ImportedOverlaysCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.layerName = const Value.absent(),
    this.geometryType = const Value.absent(),
    this.geometryJson = const Value.absent(),
    this.properties = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.visible = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ImportedOverlaysCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String layerName,
    required String geometryType,
    required String geometryJson,
    this.properties = const Value.absent(),
    required int colorValue,
    this.visible = const Value.absent(),
    required DateTime createdAt,
  }) : name = Value(name),
       layerName = Value(layerName),
       geometryType = Value(geometryType),
       geometryJson = Value(geometryJson),
       colorValue = Value(colorValue),
       createdAt = Value(createdAt);
  static Insertable<DbImportedOverlay> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? layerName,
    Expression<String>? geometryType,
    Expression<String>? geometryJson,
    Expression<String>? properties,
    Expression<int>? colorValue,
    Expression<bool>? visible,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (layerName != null) 'layer_name': layerName,
      if (geometryType != null) 'geometry_type': geometryType,
      if (geometryJson != null) 'geometry_json': geometryJson,
      if (properties != null) 'properties': properties,
      if (colorValue != null) 'color_value': colorValue,
      if (visible != null) 'visible': visible,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ImportedOverlaysCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? layerName,
    Value<String>? geometryType,
    Value<String>? geometryJson,
    Value<String?>? properties,
    Value<int>? colorValue,
    Value<bool>? visible,
    Value<DateTime>? createdAt,
  }) {
    return ImportedOverlaysCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      layerName: layerName ?? this.layerName,
      geometryType: geometryType ?? this.geometryType,
      geometryJson: geometryJson ?? this.geometryJson,
      properties: properties ?? this.properties,
      colorValue: colorValue ?? this.colorValue,
      visible: visible ?? this.visible,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (layerName.present) {
      map['layer_name'] = Variable<String>(layerName.value);
    }
    if (geometryType.present) {
      map['geometry_type'] = Variable<String>(geometryType.value);
    }
    if (geometryJson.present) {
      map['geometry_json'] = Variable<String>(geometryJson.value);
    }
    if (properties.present) {
      map['properties'] = Variable<String>(properties.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (visible.present) {
      map['visible'] = Variable<bool>(visible.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportedOverlaysCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('layerName: $layerName, ')
          ..write('geometryType: $geometryType, ')
          ..write('geometryJson: $geometryJson, ')
          ..write('properties: $properties, ')
          ..write('colorValue: $colorValue, ')
          ..write('visible: $visible, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $HttpCacheTable extends HttpCache
    with TableInfo<$HttpCacheTable, DbHttpCacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HttpCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _urlHashMeta = const VerificationMeta(
    'urlHash',
  );
  @override
  late final GeneratedColumn<String> urlHash = GeneratedColumn<String>(
    'url_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _responseBodyMeta = const VerificationMeta(
    'responseBody',
  );
  @override
  late final GeneratedColumn<String> responseBody = GeneratedColumn<String>(
    'response_body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusCodeMeta = const VerificationMeta(
    'statusCode',
  );
  @override
  late final GeneratedColumn<int> statusCode = GeneratedColumn<int>(
    'status_code',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    urlHash,
    url,
    responseBody,
    statusCode,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'http_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<DbHttpCacheEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('url_hash')) {
      context.handle(
        _urlHashMeta,
        urlHash.isAcceptableOrUnknown(data['url_hash']!, _urlHashMeta),
      );
    } else if (isInserting) {
      context.missing(_urlHashMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('response_body')) {
      context.handle(
        _responseBodyMeta,
        responseBody.isAcceptableOrUnknown(
          data['response_body']!,
          _responseBodyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_responseBodyMeta);
    }
    if (data.containsKey('status_code')) {
      context.handle(
        _statusCodeMeta,
        statusCode.isAcceptableOrUnknown(data['status_code']!, _statusCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_statusCodeMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DbHttpCacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DbHttpCacheEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      urlHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url_hash'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      responseBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}response_body'],
      )!,
      statusCode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status_code'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $HttpCacheTable createAlias(String alias) {
    return $HttpCacheTable(attachedDatabase, alias);
  }
}

class DbHttpCacheEntry extends DataClass
    implements Insertable<DbHttpCacheEntry> {
  final int id;
  final String urlHash;
  final String url;
  final String responseBody;
  final int statusCode;
  final DateTime cachedAt;
  const DbHttpCacheEntry({
    required this.id,
    required this.urlHash,
    required this.url,
    required this.responseBody,
    required this.statusCode,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['url_hash'] = Variable<String>(urlHash);
    map['url'] = Variable<String>(url);
    map['response_body'] = Variable<String>(responseBody);
    map['status_code'] = Variable<int>(statusCode);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  HttpCacheCompanion toCompanion(bool nullToAbsent) {
    return HttpCacheCompanion(
      id: Value(id),
      urlHash: Value(urlHash),
      url: Value(url),
      responseBody: Value(responseBody),
      statusCode: Value(statusCode),
      cachedAt: Value(cachedAt),
    );
  }

  factory DbHttpCacheEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DbHttpCacheEntry(
      id: serializer.fromJson<int>(json['id']),
      urlHash: serializer.fromJson<String>(json['urlHash']),
      url: serializer.fromJson<String>(json['url']),
      responseBody: serializer.fromJson<String>(json['responseBody']),
      statusCode: serializer.fromJson<int>(json['statusCode']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'urlHash': serializer.toJson<String>(urlHash),
      'url': serializer.toJson<String>(url),
      'responseBody': serializer.toJson<String>(responseBody),
      'statusCode': serializer.toJson<int>(statusCode),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  DbHttpCacheEntry copyWith({
    int? id,
    String? urlHash,
    String? url,
    String? responseBody,
    int? statusCode,
    DateTime? cachedAt,
  }) => DbHttpCacheEntry(
    id: id ?? this.id,
    urlHash: urlHash ?? this.urlHash,
    url: url ?? this.url,
    responseBody: responseBody ?? this.responseBody,
    statusCode: statusCode ?? this.statusCode,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  DbHttpCacheEntry copyWithCompanion(HttpCacheCompanion data) {
    return DbHttpCacheEntry(
      id: data.id.present ? data.id.value : this.id,
      urlHash: data.urlHash.present ? data.urlHash.value : this.urlHash,
      url: data.url.present ? data.url.value : this.url,
      responseBody: data.responseBody.present
          ? data.responseBody.value
          : this.responseBody,
      statusCode: data.statusCode.present
          ? data.statusCode.value
          : this.statusCode,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DbHttpCacheEntry(')
          ..write('id: $id, ')
          ..write('urlHash: $urlHash, ')
          ..write('url: $url, ')
          ..write('responseBody: $responseBody, ')
          ..write('statusCode: $statusCode, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, urlHash, url, responseBody, statusCode, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DbHttpCacheEntry &&
          other.id == this.id &&
          other.urlHash == this.urlHash &&
          other.url == this.url &&
          other.responseBody == this.responseBody &&
          other.statusCode == this.statusCode &&
          other.cachedAt == this.cachedAt);
}

class HttpCacheCompanion extends UpdateCompanion<DbHttpCacheEntry> {
  final Value<int> id;
  final Value<String> urlHash;
  final Value<String> url;
  final Value<String> responseBody;
  final Value<int> statusCode;
  final Value<DateTime> cachedAt;
  const HttpCacheCompanion({
    this.id = const Value.absent(),
    this.urlHash = const Value.absent(),
    this.url = const Value.absent(),
    this.responseBody = const Value.absent(),
    this.statusCode = const Value.absent(),
    this.cachedAt = const Value.absent(),
  });
  HttpCacheCompanion.insert({
    this.id = const Value.absent(),
    required String urlHash,
    required String url,
    required String responseBody,
    required int statusCode,
    required DateTime cachedAt,
  }) : urlHash = Value(urlHash),
       url = Value(url),
       responseBody = Value(responseBody),
       statusCode = Value(statusCode),
       cachedAt = Value(cachedAt);
  static Insertable<DbHttpCacheEntry> custom({
    Expression<int>? id,
    Expression<String>? urlHash,
    Expression<String>? url,
    Expression<String>? responseBody,
    Expression<int>? statusCode,
    Expression<DateTime>? cachedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (urlHash != null) 'url_hash': urlHash,
      if (url != null) 'url': url,
      if (responseBody != null) 'response_body': responseBody,
      if (statusCode != null) 'status_code': statusCode,
      if (cachedAt != null) 'cached_at': cachedAt,
    });
  }

  HttpCacheCompanion copyWith({
    Value<int>? id,
    Value<String>? urlHash,
    Value<String>? url,
    Value<String>? responseBody,
    Value<int>? statusCode,
    Value<DateTime>? cachedAt,
  }) {
    return HttpCacheCompanion(
      id: id ?? this.id,
      urlHash: urlHash ?? this.urlHash,
      url: url ?? this.url,
      responseBody: responseBody ?? this.responseBody,
      statusCode: statusCode ?? this.statusCode,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (urlHash.present) {
      map['url_hash'] = Variable<String>(urlHash.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (responseBody.present) {
      map['response_body'] = Variable<String>(responseBody.value);
    }
    if (statusCode.present) {
      map['status_code'] = Variable<int>(statusCode.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HttpCacheCompanion(')
          ..write('id: $id, ')
          ..write('urlHash: $urlHash, ')
          ..write('url: $url, ')
          ..write('responseBody: $responseBody, ')
          ..write('statusCode: $statusCode, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ParcelsTable parcels = $ParcelsTable(this);
  late final $LogBatchesTable logBatches = $LogBatchesTable(this);
  late final $LogEntriesTable logEntries = $LogEntriesTable(this);
  late final $MapLocationsTable mapLocations = $MapLocationsTable(this);
  late final $ImportedOverlaysTable importedOverlays = $ImportedOverlaysTable(
    this,
  );
  late final $HttpCacheTable httpCache = $HttpCacheTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    parcels,
    logBatches,
    logEntries,
    mapLocations,
    importedOverlays,
    httpCache,
  ];
}

typedef $$ParcelsTableCreateCompanionBuilder =
    ParcelsCompanion Function({
      Value<int> id,
      required String name,
      required String polygonJson,
      required DateTime createdAt,
      Value<int?> cadastralMunicipality,
      Value<String?> parcelNumber,
      Value<String?> owner,
      Value<String?> notes,
      Value<int> forestTypeIndex,
      Value<double> woodAllowance,
      Value<double> woodCut,
      Value<int> treesCut,
    });
typedef $$ParcelsTableUpdateCompanionBuilder =
    ParcelsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> polygonJson,
      Value<DateTime> createdAt,
      Value<int?> cadastralMunicipality,
      Value<String?> parcelNumber,
      Value<String?> owner,
      Value<String?> notes,
      Value<int> forestTypeIndex,
      Value<double> woodAllowance,
      Value<double> woodCut,
      Value<int> treesCut,
    });

final class $$ParcelsTableReferences
    extends BaseReferences<_$AppDatabase, $ParcelsTable, DbParcel> {
  $$ParcelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LogEntriesTable, List<DbLogEntry>>
  _logEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.logEntries,
    aliasName: $_aliasNameGenerator(db.parcels.id, db.logEntries.parcelId),
  );

  $$LogEntriesTableProcessedTableManager get logEntriesRefs {
    final manager = $$LogEntriesTableTableManager(
      $_db,
      $_db.logEntries,
    ).filter((f) => f.parcelId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_logEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ParcelsTableFilterComposer
    extends Composer<_$AppDatabase, $ParcelsTable> {
  $$ParcelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get polygonJson => $composableBuilder(
    column: $table.polygonJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cadastralMunicipality => $composableBuilder(
    column: $table.cadastralMunicipality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parcelNumber => $composableBuilder(
    column: $table.parcelNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get forestTypeIndex => $composableBuilder(
    column: $table.forestTypeIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get woodAllowance => $composableBuilder(
    column: $table.woodAllowance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get woodCut => $composableBuilder(
    column: $table.woodCut,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get treesCut => $composableBuilder(
    column: $table.treesCut,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> logEntriesRefs(
    Expression<bool> Function($$LogEntriesTableFilterComposer f) f,
  ) {
    final $$LogEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.logEntries,
      getReferencedColumn: (t) => t.parcelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LogEntriesTableFilterComposer(
            $db: $db,
            $table: $db.logEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ParcelsTableOrderingComposer
    extends Composer<_$AppDatabase, $ParcelsTable> {
  $$ParcelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get polygonJson => $composableBuilder(
    column: $table.polygonJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cadastralMunicipality => $composableBuilder(
    column: $table.cadastralMunicipality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parcelNumber => $composableBuilder(
    column: $table.parcelNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get forestTypeIndex => $composableBuilder(
    column: $table.forestTypeIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get woodAllowance => $composableBuilder(
    column: $table.woodAllowance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get woodCut => $composableBuilder(
    column: $table.woodCut,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get treesCut => $composableBuilder(
    column: $table.treesCut,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ParcelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ParcelsTable> {
  $$ParcelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get polygonJson => $composableBuilder(
    column: $table.polygonJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get cadastralMunicipality => $composableBuilder(
    column: $table.cadastralMunicipality,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parcelNumber => $composableBuilder(
    column: $table.parcelNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get forestTypeIndex => $composableBuilder(
    column: $table.forestTypeIndex,
    builder: (column) => column,
  );

  GeneratedColumn<double> get woodAllowance => $composableBuilder(
    column: $table.woodAllowance,
    builder: (column) => column,
  );

  GeneratedColumn<double> get woodCut =>
      $composableBuilder(column: $table.woodCut, builder: (column) => column);

  GeneratedColumn<int> get treesCut =>
      $composableBuilder(column: $table.treesCut, builder: (column) => column);

  Expression<T> logEntriesRefs<T extends Object>(
    Expression<T> Function($$LogEntriesTableAnnotationComposer a) f,
  ) {
    final $$LogEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.logEntries,
      getReferencedColumn: (t) => t.parcelId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LogEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.logEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ParcelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ParcelsTable,
          DbParcel,
          $$ParcelsTableFilterComposer,
          $$ParcelsTableOrderingComposer,
          $$ParcelsTableAnnotationComposer,
          $$ParcelsTableCreateCompanionBuilder,
          $$ParcelsTableUpdateCompanionBuilder,
          (DbParcel, $$ParcelsTableReferences),
          DbParcel,
          PrefetchHooks Function({bool logEntriesRefs})
        > {
  $$ParcelsTableTableManager(_$AppDatabase db, $ParcelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ParcelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ParcelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ParcelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> polygonJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int?> cadastralMunicipality = const Value.absent(),
                Value<String?> parcelNumber = const Value.absent(),
                Value<String?> owner = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> forestTypeIndex = const Value.absent(),
                Value<double> woodAllowance = const Value.absent(),
                Value<double> woodCut = const Value.absent(),
                Value<int> treesCut = const Value.absent(),
              }) => ParcelsCompanion(
                id: id,
                name: name,
                polygonJson: polygonJson,
                createdAt: createdAt,
                cadastralMunicipality: cadastralMunicipality,
                parcelNumber: parcelNumber,
                owner: owner,
                notes: notes,
                forestTypeIndex: forestTypeIndex,
                woodAllowance: woodAllowance,
                woodCut: woodCut,
                treesCut: treesCut,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String polygonJson,
                required DateTime createdAt,
                Value<int?> cadastralMunicipality = const Value.absent(),
                Value<String?> parcelNumber = const Value.absent(),
                Value<String?> owner = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> forestTypeIndex = const Value.absent(),
                Value<double> woodAllowance = const Value.absent(),
                Value<double> woodCut = const Value.absent(),
                Value<int> treesCut = const Value.absent(),
              }) => ParcelsCompanion.insert(
                id: id,
                name: name,
                polygonJson: polygonJson,
                createdAt: createdAt,
                cadastralMunicipality: cadastralMunicipality,
                parcelNumber: parcelNumber,
                owner: owner,
                notes: notes,
                forestTypeIndex: forestTypeIndex,
                woodAllowance: woodAllowance,
                woodCut: woodCut,
                treesCut: treesCut,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ParcelsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({logEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (logEntriesRefs) db.logEntries],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (logEntriesRefs)
                    await $_getPrefetchedData<
                      DbParcel,
                      $ParcelsTable,
                      DbLogEntry
                    >(
                      currentTable: table,
                      referencedTable: $$ParcelsTableReferences
                          ._logEntriesRefsTable(db),
                      managerFromTypedResult: (p0) => $$ParcelsTableReferences(
                        db,
                        table,
                        p0,
                      ).logEntriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.parcelId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ParcelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ParcelsTable,
      DbParcel,
      $$ParcelsTableFilterComposer,
      $$ParcelsTableOrderingComposer,
      $$ParcelsTableAnnotationComposer,
      $$ParcelsTableCreateCompanionBuilder,
      $$ParcelsTableUpdateCompanionBuilder,
      (DbParcel, $$ParcelsTableReferences),
      DbParcel,
      PrefetchHooks Function({bool logEntriesRefs})
    >;
typedef $$LogBatchesTableCreateCompanionBuilder =
    LogBatchesCompanion Function({
      Value<int> id,
      Value<String?> owner,
      Value<String?> notes,
      Value<double?> latitude,
      Value<double?> longitude,
      required double totalVolume,
      required int logCount,
      required DateTime createdAt,
    });
typedef $$LogBatchesTableUpdateCompanionBuilder =
    LogBatchesCompanion Function({
      Value<int> id,
      Value<String?> owner,
      Value<String?> notes,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<double> totalVolume,
      Value<int> logCount,
      Value<DateTime> createdAt,
    });

final class $$LogBatchesTableReferences
    extends BaseReferences<_$AppDatabase, $LogBatchesTable, DbLogBatch> {
  $$LogBatchesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LogEntriesTable, List<DbLogEntry>>
  _logEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.logEntries,
    aliasName: $_aliasNameGenerator(db.logBatches.id, db.logEntries.batchId),
  );

  $$LogEntriesTableProcessedTableManager get logEntriesRefs {
    final manager = $$LogEntriesTableTableManager(
      $_db,
      $_db.logEntries,
    ).filter((f) => f.batchId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_logEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LogBatchesTableFilterComposer
    extends Composer<_$AppDatabase, $LogBatchesTable> {
  $$LogBatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalVolume => $composableBuilder(
    column: $table.totalVolume,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get logCount => $composableBuilder(
    column: $table.logCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> logEntriesRefs(
    Expression<bool> Function($$LogEntriesTableFilterComposer f) f,
  ) {
    final $$LogEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.logEntries,
      getReferencedColumn: (t) => t.batchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LogEntriesTableFilterComposer(
            $db: $db,
            $table: $db.logEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LogBatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $LogBatchesTable> {
  $$LogBatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalVolume => $composableBuilder(
    column: $table.totalVolume,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get logCount => $composableBuilder(
    column: $table.logCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LogBatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LogBatchesTable> {
  $$LogBatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get totalVolume => $composableBuilder(
    column: $table.totalVolume,
    builder: (column) => column,
  );

  GeneratedColumn<int> get logCount =>
      $composableBuilder(column: $table.logCount, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> logEntriesRefs<T extends Object>(
    Expression<T> Function($$LogEntriesTableAnnotationComposer a) f,
  ) {
    final $$LogEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.logEntries,
      getReferencedColumn: (t) => t.batchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LogEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.logEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LogBatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LogBatchesTable,
          DbLogBatch,
          $$LogBatchesTableFilterComposer,
          $$LogBatchesTableOrderingComposer,
          $$LogBatchesTableAnnotationComposer,
          $$LogBatchesTableCreateCompanionBuilder,
          $$LogBatchesTableUpdateCompanionBuilder,
          (DbLogBatch, $$LogBatchesTableReferences),
          DbLogBatch,
          PrefetchHooks Function({bool logEntriesRefs})
        > {
  $$LogBatchesTableTableManager(_$AppDatabase db, $LogBatchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LogBatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LogBatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LogBatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> owner = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<double> totalVolume = const Value.absent(),
                Value<int> logCount = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LogBatchesCompanion(
                id: id,
                owner: owner,
                notes: notes,
                latitude: latitude,
                longitude: longitude,
                totalVolume: totalVolume,
                logCount: logCount,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> owner = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                required double totalVolume,
                required int logCount,
                required DateTime createdAt,
              }) => LogBatchesCompanion.insert(
                id: id,
                owner: owner,
                notes: notes,
                latitude: latitude,
                longitude: longitude,
                totalVolume: totalVolume,
                logCount: logCount,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LogBatchesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({logEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (logEntriesRefs) db.logEntries],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (logEntriesRefs)
                    await $_getPrefetchedData<
                      DbLogBatch,
                      $LogBatchesTable,
                      DbLogEntry
                    >(
                      currentTable: table,
                      referencedTable: $$LogBatchesTableReferences
                          ._logEntriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LogBatchesTableReferences(
                            db,
                            table,
                            p0,
                          ).logEntriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.batchId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LogBatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LogBatchesTable,
      DbLogBatch,
      $$LogBatchesTableFilterComposer,
      $$LogBatchesTableOrderingComposer,
      $$LogBatchesTableAnnotationComposer,
      $$LogBatchesTableCreateCompanionBuilder,
      $$LogBatchesTableUpdateCompanionBuilder,
      (DbLogBatch, $$LogBatchesTableReferences),
      DbLogBatch,
      PrefetchHooks Function({bool logEntriesRefs})
    >;
typedef $$LogEntriesTableCreateCompanionBuilder =
    LogEntriesCompanion Function({
      Value<int> id,
      Value<double?> diameter,
      Value<double?> length,
      required double volume,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<String?> notes,
      Value<String?> species,
      required DateTime createdAt,
      Value<int?> batchId,
      Value<int?> parcelId,
    });
typedef $$LogEntriesTableUpdateCompanionBuilder =
    LogEntriesCompanion Function({
      Value<int> id,
      Value<double?> diameter,
      Value<double?> length,
      Value<double> volume,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<String?> notes,
      Value<String?> species,
      Value<DateTime> createdAt,
      Value<int?> batchId,
      Value<int?> parcelId,
    });

final class $$LogEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $LogEntriesTable, DbLogEntry> {
  $$LogEntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LogBatchesTable _batchIdTable(_$AppDatabase db) =>
      db.logBatches.createAlias(
        $_aliasNameGenerator(db.logEntries.batchId, db.logBatches.id),
      );

  $$LogBatchesTableProcessedTableManager? get batchId {
    final $_column = $_itemColumn<int>('batch_id');
    if ($_column == null) return null;
    final manager = $$LogBatchesTableTableManager(
      $_db,
      $_db.logBatches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_batchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ParcelsTable _parcelIdTable(_$AppDatabase db) => db.parcels
      .createAlias($_aliasNameGenerator(db.logEntries.parcelId, db.parcels.id));

  $$ParcelsTableProcessedTableManager? get parcelId {
    final $_column = $_itemColumn<int>('parcel_id');
    if ($_column == null) return null;
    final manager = $$ParcelsTableTableManager(
      $_db,
      $_db.parcels,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parcelIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LogEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $LogEntriesTable> {
  $$LogEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get diameter => $composableBuilder(
    column: $table.diameter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get length => $composableBuilder(
    column: $table.length,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get species => $composableBuilder(
    column: $table.species,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LogBatchesTableFilterComposer get batchId {
    final $$LogBatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.batchId,
      referencedTable: $db.logBatches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LogBatchesTableFilterComposer(
            $db: $db,
            $table: $db.logBatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ParcelsTableFilterComposer get parcelId {
    final $$ParcelsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parcelId,
      referencedTable: $db.parcels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ParcelsTableFilterComposer(
            $db: $db,
            $table: $db.parcels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LogEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $LogEntriesTable> {
  $$LogEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get diameter => $composableBuilder(
    column: $table.diameter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get length => $composableBuilder(
    column: $table.length,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get species => $composableBuilder(
    column: $table.species,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LogBatchesTableOrderingComposer get batchId {
    final $$LogBatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.batchId,
      referencedTable: $db.logBatches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LogBatchesTableOrderingComposer(
            $db: $db,
            $table: $db.logBatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ParcelsTableOrderingComposer get parcelId {
    final $$ParcelsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parcelId,
      referencedTable: $db.parcels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ParcelsTableOrderingComposer(
            $db: $db,
            $table: $db.parcels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LogEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LogEntriesTable> {
  $$LogEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get diameter =>
      $composableBuilder(column: $table.diameter, builder: (column) => column);

  GeneratedColumn<double> get length =>
      $composableBuilder(column: $table.length, builder: (column) => column);

  GeneratedColumn<double> get volume =>
      $composableBuilder(column: $table.volume, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get species =>
      $composableBuilder(column: $table.species, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$LogBatchesTableAnnotationComposer get batchId {
    final $$LogBatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.batchId,
      referencedTable: $db.logBatches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LogBatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.logBatches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ParcelsTableAnnotationComposer get parcelId {
    final $$ParcelsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parcelId,
      referencedTable: $db.parcels,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ParcelsTableAnnotationComposer(
            $db: $db,
            $table: $db.parcels,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LogEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LogEntriesTable,
          DbLogEntry,
          $$LogEntriesTableFilterComposer,
          $$LogEntriesTableOrderingComposer,
          $$LogEntriesTableAnnotationComposer,
          $$LogEntriesTableCreateCompanionBuilder,
          $$LogEntriesTableUpdateCompanionBuilder,
          (DbLogEntry, $$LogEntriesTableReferences),
          DbLogEntry,
          PrefetchHooks Function({bool batchId, bool parcelId})
        > {
  $$LogEntriesTableTableManager(_$AppDatabase db, $LogEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LogEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LogEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LogEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<double?> diameter = const Value.absent(),
                Value<double?> length = const Value.absent(),
                Value<double> volume = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> species = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int?> batchId = const Value.absent(),
                Value<int?> parcelId = const Value.absent(),
              }) => LogEntriesCompanion(
                id: id,
                diameter: diameter,
                length: length,
                volume: volume,
                latitude: latitude,
                longitude: longitude,
                notes: notes,
                species: species,
                createdAt: createdAt,
                batchId: batchId,
                parcelId: parcelId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<double?> diameter = const Value.absent(),
                Value<double?> length = const Value.absent(),
                required double volume,
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> species = const Value.absent(),
                required DateTime createdAt,
                Value<int?> batchId = const Value.absent(),
                Value<int?> parcelId = const Value.absent(),
              }) => LogEntriesCompanion.insert(
                id: id,
                diameter: diameter,
                length: length,
                volume: volume,
                latitude: latitude,
                longitude: longitude,
                notes: notes,
                species: species,
                createdAt: createdAt,
                batchId: batchId,
                parcelId: parcelId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LogEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({batchId = false, parcelId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (batchId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.batchId,
                                referencedTable: $$LogEntriesTableReferences
                                    ._batchIdTable(db),
                                referencedColumn: $$LogEntriesTableReferences
                                    ._batchIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (parcelId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.parcelId,
                                referencedTable: $$LogEntriesTableReferences
                                    ._parcelIdTable(db),
                                referencedColumn: $$LogEntriesTableReferences
                                    ._parcelIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LogEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LogEntriesTable,
      DbLogEntry,
      $$LogEntriesTableFilterComposer,
      $$LogEntriesTableOrderingComposer,
      $$LogEntriesTableAnnotationComposer,
      $$LogEntriesTableCreateCompanionBuilder,
      $$LogEntriesTableUpdateCompanionBuilder,
      (DbLogEntry, $$LogEntriesTableReferences),
      DbLogEntry,
      PrefetchHooks Function({bool batchId, bool parcelId})
    >;
typedef $$MapLocationsTableCreateCompanionBuilder =
    MapLocationsCompanion Function({
      Value<int> id,
      required String name,
      required double latitude,
      required double longitude,
      Value<int> typeIndex,
      required DateTime createdAt,
    });
typedef $$MapLocationsTableUpdateCompanionBuilder =
    MapLocationsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<double> latitude,
      Value<double> longitude,
      Value<int> typeIndex,
      Value<DateTime> createdAt,
    });

class $$MapLocationsTableFilterComposer
    extends Composer<_$AppDatabase, $MapLocationsTable> {
  $$MapLocationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get typeIndex => $composableBuilder(
    column: $table.typeIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MapLocationsTableOrderingComposer
    extends Composer<_$AppDatabase, $MapLocationsTable> {
  $$MapLocationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get typeIndex => $composableBuilder(
    column: $table.typeIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MapLocationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MapLocationsTable> {
  $$MapLocationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<int> get typeIndex =>
      $composableBuilder(column: $table.typeIndex, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MapLocationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MapLocationsTable,
          DbMapLocation,
          $$MapLocationsTableFilterComposer,
          $$MapLocationsTableOrderingComposer,
          $$MapLocationsTableAnnotationComposer,
          $$MapLocationsTableCreateCompanionBuilder,
          $$MapLocationsTableUpdateCompanionBuilder,
          (
            DbMapLocation,
            BaseReferences<_$AppDatabase, $MapLocationsTable, DbMapLocation>,
          ),
          DbMapLocation,
          PrefetchHooks Function()
        > {
  $$MapLocationsTableTableManager(_$AppDatabase db, $MapLocationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MapLocationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MapLocationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MapLocationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<int> typeIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => MapLocationsCompanion(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                typeIndex: typeIndex,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required double latitude,
                required double longitude,
                Value<int> typeIndex = const Value.absent(),
                required DateTime createdAt,
              }) => MapLocationsCompanion.insert(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                typeIndex: typeIndex,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MapLocationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MapLocationsTable,
      DbMapLocation,
      $$MapLocationsTableFilterComposer,
      $$MapLocationsTableOrderingComposer,
      $$MapLocationsTableAnnotationComposer,
      $$MapLocationsTableCreateCompanionBuilder,
      $$MapLocationsTableUpdateCompanionBuilder,
      (
        DbMapLocation,
        BaseReferences<_$AppDatabase, $MapLocationsTable, DbMapLocation>,
      ),
      DbMapLocation,
      PrefetchHooks Function()
    >;
typedef $$ImportedOverlaysTableCreateCompanionBuilder =
    ImportedOverlaysCompanion Function({
      Value<int> id,
      required String name,
      required String layerName,
      required String geometryType,
      required String geometryJson,
      Value<String?> properties,
      required int colorValue,
      Value<bool> visible,
      required DateTime createdAt,
    });
typedef $$ImportedOverlaysTableUpdateCompanionBuilder =
    ImportedOverlaysCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> layerName,
      Value<String> geometryType,
      Value<String> geometryJson,
      Value<String?> properties,
      Value<int> colorValue,
      Value<bool> visible,
      Value<DateTime> createdAt,
    });

class $$ImportedOverlaysTableFilterComposer
    extends Composer<_$AppDatabase, $ImportedOverlaysTable> {
  $$ImportedOverlaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get layerName => $composableBuilder(
    column: $table.layerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get geometryType => $composableBuilder(
    column: $table.geometryType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get geometryJson => $composableBuilder(
    column: $table.geometryJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get properties => $composableBuilder(
    column: $table.properties,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get visible => $composableBuilder(
    column: $table.visible,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ImportedOverlaysTableOrderingComposer
    extends Composer<_$AppDatabase, $ImportedOverlaysTable> {
  $$ImportedOverlaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get layerName => $composableBuilder(
    column: $table.layerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get geometryType => $composableBuilder(
    column: $table.geometryType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get geometryJson => $composableBuilder(
    column: $table.geometryJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get properties => $composableBuilder(
    column: $table.properties,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get visible => $composableBuilder(
    column: $table.visible,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImportedOverlaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImportedOverlaysTable> {
  $$ImportedOverlaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get layerName =>
      $composableBuilder(column: $table.layerName, builder: (column) => column);

  GeneratedColumn<String> get geometryType => $composableBuilder(
    column: $table.geometryType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get geometryJson => $composableBuilder(
    column: $table.geometryJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get properties => $composableBuilder(
    column: $table.properties,
    builder: (column) => column,
  );

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get visible =>
      $composableBuilder(column: $table.visible, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ImportedOverlaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImportedOverlaysTable,
          DbImportedOverlay,
          $$ImportedOverlaysTableFilterComposer,
          $$ImportedOverlaysTableOrderingComposer,
          $$ImportedOverlaysTableAnnotationComposer,
          $$ImportedOverlaysTableCreateCompanionBuilder,
          $$ImportedOverlaysTableUpdateCompanionBuilder,
          (
            DbImportedOverlay,
            BaseReferences<
              _$AppDatabase,
              $ImportedOverlaysTable,
              DbImportedOverlay
            >,
          ),
          DbImportedOverlay,
          PrefetchHooks Function()
        > {
  $$ImportedOverlaysTableTableManager(
    _$AppDatabase db,
    $ImportedOverlaysTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportedOverlaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportedOverlaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportedOverlaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> layerName = const Value.absent(),
                Value<String> geometryType = const Value.absent(),
                Value<String> geometryJson = const Value.absent(),
                Value<String?> properties = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<bool> visible = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ImportedOverlaysCompanion(
                id: id,
                name: name,
                layerName: layerName,
                geometryType: geometryType,
                geometryJson: geometryJson,
                properties: properties,
                colorValue: colorValue,
                visible: visible,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String layerName,
                required String geometryType,
                required String geometryJson,
                Value<String?> properties = const Value.absent(),
                required int colorValue,
                Value<bool> visible = const Value.absent(),
                required DateTime createdAt,
              }) => ImportedOverlaysCompanion.insert(
                id: id,
                name: name,
                layerName: layerName,
                geometryType: geometryType,
                geometryJson: geometryJson,
                properties: properties,
                colorValue: colorValue,
                visible: visible,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ImportedOverlaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImportedOverlaysTable,
      DbImportedOverlay,
      $$ImportedOverlaysTableFilterComposer,
      $$ImportedOverlaysTableOrderingComposer,
      $$ImportedOverlaysTableAnnotationComposer,
      $$ImportedOverlaysTableCreateCompanionBuilder,
      $$ImportedOverlaysTableUpdateCompanionBuilder,
      (
        DbImportedOverlay,
        BaseReferences<
          _$AppDatabase,
          $ImportedOverlaysTable,
          DbImportedOverlay
        >,
      ),
      DbImportedOverlay,
      PrefetchHooks Function()
    >;
typedef $$HttpCacheTableCreateCompanionBuilder =
    HttpCacheCompanion Function({
      Value<int> id,
      required String urlHash,
      required String url,
      required String responseBody,
      required int statusCode,
      required DateTime cachedAt,
    });
typedef $$HttpCacheTableUpdateCompanionBuilder =
    HttpCacheCompanion Function({
      Value<int> id,
      Value<String> urlHash,
      Value<String> url,
      Value<String> responseBody,
      Value<int> statusCode,
      Value<DateTime> cachedAt,
    });

class $$HttpCacheTableFilterComposer
    extends Composer<_$AppDatabase, $HttpCacheTable> {
  $$HttpCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get urlHash => $composableBuilder(
    column: $table.urlHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get responseBody => $composableBuilder(
    column: $table.responseBody,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get statusCode => $composableBuilder(
    column: $table.statusCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HttpCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $HttpCacheTable> {
  $$HttpCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get urlHash => $composableBuilder(
    column: $table.urlHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get responseBody => $composableBuilder(
    column: $table.responseBody,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get statusCode => $composableBuilder(
    column: $table.statusCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HttpCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $HttpCacheTable> {
  $$HttpCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get urlHash =>
      $composableBuilder(column: $table.urlHash, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get responseBody => $composableBuilder(
    column: $table.responseBody,
    builder: (column) => column,
  );

  GeneratedColumn<int> get statusCode => $composableBuilder(
    column: $table.statusCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$HttpCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HttpCacheTable,
          DbHttpCacheEntry,
          $$HttpCacheTableFilterComposer,
          $$HttpCacheTableOrderingComposer,
          $$HttpCacheTableAnnotationComposer,
          $$HttpCacheTableCreateCompanionBuilder,
          $$HttpCacheTableUpdateCompanionBuilder,
          (
            DbHttpCacheEntry,
            BaseReferences<_$AppDatabase, $HttpCacheTable, DbHttpCacheEntry>,
          ),
          DbHttpCacheEntry,
          PrefetchHooks Function()
        > {
  $$HttpCacheTableTableManager(_$AppDatabase db, $HttpCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HttpCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HttpCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HttpCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> urlHash = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> responseBody = const Value.absent(),
                Value<int> statusCode = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
              }) => HttpCacheCompanion(
                id: id,
                urlHash: urlHash,
                url: url,
                responseBody: responseBody,
                statusCode: statusCode,
                cachedAt: cachedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String urlHash,
                required String url,
                required String responseBody,
                required int statusCode,
                required DateTime cachedAt,
              }) => HttpCacheCompanion.insert(
                id: id,
                urlHash: urlHash,
                url: url,
                responseBody: responseBody,
                statusCode: statusCode,
                cachedAt: cachedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HttpCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HttpCacheTable,
      DbHttpCacheEntry,
      $$HttpCacheTableFilterComposer,
      $$HttpCacheTableOrderingComposer,
      $$HttpCacheTableAnnotationComposer,
      $$HttpCacheTableCreateCompanionBuilder,
      $$HttpCacheTableUpdateCompanionBuilder,
      (
        DbHttpCacheEntry,
        BaseReferences<_$AppDatabase, $HttpCacheTable, DbHttpCacheEntry>,
      ),
      DbHttpCacheEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ParcelsTableTableManager get parcels =>
      $$ParcelsTableTableManager(_db, _db.parcels);
  $$LogBatchesTableTableManager get logBatches =>
      $$LogBatchesTableTableManager(_db, _db.logBatches);
  $$LogEntriesTableTableManager get logEntries =>
      $$LogEntriesTableTableManager(_db, _db.logEntries);
  $$MapLocationsTableTableManager get mapLocations =>
      $$MapLocationsTableTableManager(_db, _db.mapLocations);
  $$ImportedOverlaysTableTableManager get importedOverlays =>
      $$ImportedOverlaysTableTableManager(_db, _db.importedOverlays);
  $$HttpCacheTableTableManager get httpCache =>
      $$HttpCacheTableTableManager(_db, _db.httpCache);
}
