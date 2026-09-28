// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $VehiclesTable extends Vehicles
    with TableInfo<$VehiclesTable, VehicleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VehiclesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nicknameMeta = const VerificationMeta(
    'nickname',
  );
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
    'nickname',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vinMeta = const VerificationMeta('vin');
  @override
  late final GeneratedColumn<String> vin = GeneratedColumn<String>(
    'vin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vinUnverifiedMeta = const VerificationMeta(
    'vinUnverified',
  );
  @override
  late final GeneratedColumn<bool> vinUnverified = GeneratedColumn<bool>(
    'vin_unverified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("vin_unverified" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _makeMeta = const VerificationMeta('make');
  @override
  late final GeneratedColumn<String> make = GeneratedColumn<String>(
    'make',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _trimMeta = const VerificationMeta('trim');
  @override
  late final GeneratedColumn<String> trim = GeneratedColumn<String>(
    'trim',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<VehicleFuel, String> fuelType =
      GeneratedColumn<String>(
        'fuel_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<VehicleFuel>($VehiclesTable.$converterfuelType);
  static const VerificationMeta _odometerKmMeta = const VerificationMeta(
    'odometerKm',
  );
  @override
  late final GeneratedColumn<double> odometerKm = GeneratedColumn<double>(
    'odometer_km',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _odometerUpdatedAtMeta = const VerificationMeta(
    'odometerUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> odometerUpdatedAt =
      GeneratedColumn<DateTime>(
        'odometer_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _plateMeta = const VerificationMeta('plate');
  @override
  late final GeneratedColumn<String> plate = GeneratedColumn<String>(
    'plate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedProtocolMeta = const VerificationMeta(
    'cachedProtocol',
  );
  @override
  late final GeneratedColumn<int> cachedProtocol = GeneratedColumn<int>(
    'cached_protocol',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _supportedPidsJsonMeta = const VerificationMeta(
    'supportedPidsJson',
  );
  @override
  late final GeneratedColumn<String> supportedPidsJson =
      GeneratedColumn<String>(
        'supported_pids_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _supportsBatchingMeta = const VerificationMeta(
    'supportsBatching',
  );
  @override
  late final GeneratedColumn<bool> supportsBatching = GeneratedColumn<bool>(
    'supports_batching',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("supports_batching" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isPrimaryMeta = const VerificationMeta(
    'isPrimary',
  );
  @override
  late final GeneratedColumn<bool> isPrimary = GeneratedColumn<bool>(
    'is_primary',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_primary" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    nickname,
    vin,
    vinUnverified,
    make,
    model,
    trim,
    year,
    fuelType,
    odometerKm,
    odometerUpdatedAt,
    plate,
    photoPath,
    cachedProtocol,
    supportedPidsJson,
    supportsBatching,
    isPrimary,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vehicles';
  @override
  VerificationContext validateIntegrity(
    Insertable<VehicleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('nickname')) {
      context.handle(
        _nicknameMeta,
        nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta),
      );
    } else if (isInserting) {
      context.missing(_nicknameMeta);
    }
    if (data.containsKey('vin')) {
      context.handle(
        _vinMeta,
        vin.isAcceptableOrUnknown(data['vin']!, _vinMeta),
      );
    }
    if (data.containsKey('vin_unverified')) {
      context.handle(
        _vinUnverifiedMeta,
        vinUnverified.isAcceptableOrUnknown(
          data['vin_unverified']!,
          _vinUnverifiedMeta,
        ),
      );
    }
    if (data.containsKey('make')) {
      context.handle(
        _makeMeta,
        make.isAcceptableOrUnknown(data['make']!, _makeMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('trim')) {
      context.handle(
        _trimMeta,
        trim.isAcceptableOrUnknown(data['trim']!, _trimMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('odometer_km')) {
      context.handle(
        _odometerKmMeta,
        odometerKm.isAcceptableOrUnknown(data['odometer_km']!, _odometerKmMeta),
      );
    }
    if (data.containsKey('odometer_updated_at')) {
      context.handle(
        _odometerUpdatedAtMeta,
        odometerUpdatedAt.isAcceptableOrUnknown(
          data['odometer_updated_at']!,
          _odometerUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('plate')) {
      context.handle(
        _plateMeta,
        plate.isAcceptableOrUnknown(data['plate']!, _plateMeta),
      );
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
      );
    }
    if (data.containsKey('cached_protocol')) {
      context.handle(
        _cachedProtocolMeta,
        cachedProtocol.isAcceptableOrUnknown(
          data['cached_protocol']!,
          _cachedProtocolMeta,
        ),
      );
    }
    if (data.containsKey('supported_pids_json')) {
      context.handle(
        _supportedPidsJsonMeta,
        supportedPidsJson.isAcceptableOrUnknown(
          data['supported_pids_json']!,
          _supportedPidsJsonMeta,
        ),
      );
    }
    if (data.containsKey('supports_batching')) {
      context.handle(
        _supportsBatchingMeta,
        supportsBatching.isAcceptableOrUnknown(
          data['supports_batching']!,
          _supportsBatchingMeta,
        ),
      );
    }
    if (data.containsKey('is_primary')) {
      context.handle(
        _isPrimaryMeta,
        isPrimary.isAcceptableOrUnknown(data['is_primary']!, _isPrimaryMeta),
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
  VehicleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VehicleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nickname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nickname'],
      )!,
      vin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vin'],
      ),
      vinUnverified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}vin_unverified'],
      )!,
      make: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}make'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      trim: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trim'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      fuelType: $VehiclesTable.$converterfuelType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}fuel_type'],
        )!,
      ),
      odometerKm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}odometer_km'],
      ),
      odometerUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}odometer_updated_at'],
      ),
      plate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plate'],
      ),
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      ),
      cachedProtocol: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_protocol'],
      ),
      supportedPidsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supported_pids_json'],
      ),
      supportsBatching: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}supports_batching'],
      )!,
      isPrimary: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_primary'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $VehiclesTable createAlias(String alias) {
    return $VehiclesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<VehicleFuel, String, String> $converterfuelType =
      const EnumNameConverter<VehicleFuel>(VehicleFuel.values);
}

class VehicleRow extends DataClass implements Insertable<VehicleRow> {
  final String id;
  final String nickname;

  /// Full VIN, or null for a car that never answered Mode 09 (pre-2008 is
  /// common). Stored unmasked; masking is a display decision. Not unique:
  /// SPEC §9.8 says a duplicate VIN is warned about, then allowed.
  final String? vin;

  /// SPEC §9.6: a VIN whose check digit failed twice is kept but flagged,
  /// and never decoded.
  final bool vinUnverified;
  final String make;
  final String model;
  final String trim;
  final int? year;
  final VehicleFuel fuelType;
  final double? odometerKm;
  final DateTime? odometerUpdatedAt;
  final String? plate;
  final String? photoPath;

  /// The ATSP number that worked last time — skips the protocol ladder on
  /// the next connect (SPEC §4.2).
  final int? cachedProtocol;

  /// JSON list of supported PID hex strings from the 0100/0120/… bitmasks.
  final String? supportedPidsJson;
  final bool supportsBatching;
  final bool isPrimary;
  final DateTime createdAt;
  const VehicleRow({
    required this.id,
    required this.nickname,
    this.vin,
    required this.vinUnverified,
    required this.make,
    required this.model,
    required this.trim,
    this.year,
    required this.fuelType,
    this.odometerKm,
    this.odometerUpdatedAt,
    this.plate,
    this.photoPath,
    this.cachedProtocol,
    this.supportedPidsJson,
    required this.supportsBatching,
    required this.isPrimary,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['nickname'] = Variable<String>(nickname);
    if (!nullToAbsent || vin != null) {
      map['vin'] = Variable<String>(vin);
    }
    map['vin_unverified'] = Variable<bool>(vinUnverified);
    map['make'] = Variable<String>(make);
    map['model'] = Variable<String>(model);
    map['trim'] = Variable<String>(trim);
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    {
      map['fuel_type'] = Variable<String>(
        $VehiclesTable.$converterfuelType.toSql(fuelType),
      );
    }
    if (!nullToAbsent || odometerKm != null) {
      map['odometer_km'] = Variable<double>(odometerKm);
    }
    if (!nullToAbsent || odometerUpdatedAt != null) {
      map['odometer_updated_at'] = Variable<DateTime>(odometerUpdatedAt);
    }
    if (!nullToAbsent || plate != null) {
      map['plate'] = Variable<String>(plate);
    }
    if (!nullToAbsent || photoPath != null) {
      map['photo_path'] = Variable<String>(photoPath);
    }
    if (!nullToAbsent || cachedProtocol != null) {
      map['cached_protocol'] = Variable<int>(cachedProtocol);
    }
    if (!nullToAbsent || supportedPidsJson != null) {
      map['supported_pids_json'] = Variable<String>(supportedPidsJson);
    }
    map['supports_batching'] = Variable<bool>(supportsBatching);
    map['is_primary'] = Variable<bool>(isPrimary);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  VehiclesCompanion toCompanion(bool nullToAbsent) {
    return VehiclesCompanion(
      id: Value(id),
      nickname: Value(nickname),
      vin: vin == null && nullToAbsent ? const Value.absent() : Value(vin),
      vinUnverified: Value(vinUnverified),
      make: Value(make),
      model: Value(model),
      trim: Value(trim),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      fuelType: Value(fuelType),
      odometerKm: odometerKm == null && nullToAbsent
          ? const Value.absent()
          : Value(odometerKm),
      odometerUpdatedAt: odometerUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(odometerUpdatedAt),
      plate: plate == null && nullToAbsent
          ? const Value.absent()
          : Value(plate),
      photoPath: photoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(photoPath),
      cachedProtocol: cachedProtocol == null && nullToAbsent
          ? const Value.absent()
          : Value(cachedProtocol),
      supportedPidsJson: supportedPidsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(supportedPidsJson),
      supportsBatching: Value(supportsBatching),
      isPrimary: Value(isPrimary),
      createdAt: Value(createdAt),
    );
  }

  factory VehicleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VehicleRow(
      id: serializer.fromJson<String>(json['id']),
      nickname: serializer.fromJson<String>(json['nickname']),
      vin: serializer.fromJson<String?>(json['vin']),
      vinUnverified: serializer.fromJson<bool>(json['vinUnverified']),
      make: serializer.fromJson<String>(json['make']),
      model: serializer.fromJson<String>(json['model']),
      trim: serializer.fromJson<String>(json['trim']),
      year: serializer.fromJson<int?>(json['year']),
      fuelType: $VehiclesTable.$converterfuelType.fromJson(
        serializer.fromJson<String>(json['fuelType']),
      ),
      odometerKm: serializer.fromJson<double?>(json['odometerKm']),
      odometerUpdatedAt: serializer.fromJson<DateTime?>(
        json['odometerUpdatedAt'],
      ),
      plate: serializer.fromJson<String?>(json['plate']),
      photoPath: serializer.fromJson<String?>(json['photoPath']),
      cachedProtocol: serializer.fromJson<int?>(json['cachedProtocol']),
      supportedPidsJson: serializer.fromJson<String?>(
        json['supportedPidsJson'],
      ),
      supportsBatching: serializer.fromJson<bool>(json['supportsBatching']),
      isPrimary: serializer.fromJson<bool>(json['isPrimary']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nickname': serializer.toJson<String>(nickname),
      'vin': serializer.toJson<String?>(vin),
      'vinUnverified': serializer.toJson<bool>(vinUnverified),
      'make': serializer.toJson<String>(make),
      'model': serializer.toJson<String>(model),
      'trim': serializer.toJson<String>(trim),
      'year': serializer.toJson<int?>(year),
      'fuelType': serializer.toJson<String>(
        $VehiclesTable.$converterfuelType.toJson(fuelType),
      ),
      'odometerKm': serializer.toJson<double?>(odometerKm),
      'odometerUpdatedAt': serializer.toJson<DateTime?>(odometerUpdatedAt),
      'plate': serializer.toJson<String?>(plate),
      'photoPath': serializer.toJson<String?>(photoPath),
      'cachedProtocol': serializer.toJson<int?>(cachedProtocol),
      'supportedPidsJson': serializer.toJson<String?>(supportedPidsJson),
      'supportsBatching': serializer.toJson<bool>(supportsBatching),
      'isPrimary': serializer.toJson<bool>(isPrimary),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  VehicleRow copyWith({
    String? id,
    String? nickname,
    Value<String?> vin = const Value.absent(),
    bool? vinUnverified,
    String? make,
    String? model,
    String? trim,
    Value<int?> year = const Value.absent(),
    VehicleFuel? fuelType,
    Value<double?> odometerKm = const Value.absent(),
    Value<DateTime?> odometerUpdatedAt = const Value.absent(),
    Value<String?> plate = const Value.absent(),
    Value<String?> photoPath = const Value.absent(),
    Value<int?> cachedProtocol = const Value.absent(),
    Value<String?> supportedPidsJson = const Value.absent(),
    bool? supportsBatching,
    bool? isPrimary,
    DateTime? createdAt,
  }) => VehicleRow(
    id: id ?? this.id,
    nickname: nickname ?? this.nickname,
    vin: vin.present ? vin.value : this.vin,
    vinUnverified: vinUnverified ?? this.vinUnverified,
    make: make ?? this.make,
    model: model ?? this.model,
    trim: trim ?? this.trim,
    year: year.present ? year.value : this.year,
    fuelType: fuelType ?? this.fuelType,
    odometerKm: odometerKm.present ? odometerKm.value : this.odometerKm,
    odometerUpdatedAt: odometerUpdatedAt.present
        ? odometerUpdatedAt.value
        : this.odometerUpdatedAt,
    plate: plate.present ? plate.value : this.plate,
    photoPath: photoPath.present ? photoPath.value : this.photoPath,
    cachedProtocol: cachedProtocol.present
        ? cachedProtocol.value
        : this.cachedProtocol,
    supportedPidsJson: supportedPidsJson.present
        ? supportedPidsJson.value
        : this.supportedPidsJson,
    supportsBatching: supportsBatching ?? this.supportsBatching,
    isPrimary: isPrimary ?? this.isPrimary,
    createdAt: createdAt ?? this.createdAt,
  );
  VehicleRow copyWithCompanion(VehiclesCompanion data) {
    return VehicleRow(
      id: data.id.present ? data.id.value : this.id,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      vin: data.vin.present ? data.vin.value : this.vin,
      vinUnverified: data.vinUnverified.present
          ? data.vinUnverified.value
          : this.vinUnverified,
      make: data.make.present ? data.make.value : this.make,
      model: data.model.present ? data.model.value : this.model,
      trim: data.trim.present ? data.trim.value : this.trim,
      year: data.year.present ? data.year.value : this.year,
      fuelType: data.fuelType.present ? data.fuelType.value : this.fuelType,
      odometerKm: data.odometerKm.present
          ? data.odometerKm.value
          : this.odometerKm,
      odometerUpdatedAt: data.odometerUpdatedAt.present
          ? data.odometerUpdatedAt.value
          : this.odometerUpdatedAt,
      plate: data.plate.present ? data.plate.value : this.plate,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
      cachedProtocol: data.cachedProtocol.present
          ? data.cachedProtocol.value
          : this.cachedProtocol,
      supportedPidsJson: data.supportedPidsJson.present
          ? data.supportedPidsJson.value
          : this.supportedPidsJson,
      supportsBatching: data.supportsBatching.present
          ? data.supportsBatching.value
          : this.supportsBatching,
      isPrimary: data.isPrimary.present ? data.isPrimary.value : this.isPrimary,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VehicleRow(')
          ..write('id: $id, ')
          ..write('nickname: $nickname, ')
          ..write('vin: $vin, ')
          ..write('vinUnverified: $vinUnverified, ')
          ..write('make: $make, ')
          ..write('model: $model, ')
          ..write('trim: $trim, ')
          ..write('year: $year, ')
          ..write('fuelType: $fuelType, ')
          ..write('odometerKm: $odometerKm, ')
          ..write('odometerUpdatedAt: $odometerUpdatedAt, ')
          ..write('plate: $plate, ')
          ..write('photoPath: $photoPath, ')
          ..write('cachedProtocol: $cachedProtocol, ')
          ..write('supportedPidsJson: $supportedPidsJson, ')
          ..write('supportsBatching: $supportsBatching, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    nickname,
    vin,
    vinUnverified,
    make,
    model,
    trim,
    year,
    fuelType,
    odometerKm,
    odometerUpdatedAt,
    plate,
    photoPath,
    cachedProtocol,
    supportedPidsJson,
    supportsBatching,
    isPrimary,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VehicleRow &&
          other.id == this.id &&
          other.nickname == this.nickname &&
          other.vin == this.vin &&
          other.vinUnverified == this.vinUnverified &&
          other.make == this.make &&
          other.model == this.model &&
          other.trim == this.trim &&
          other.year == this.year &&
          other.fuelType == this.fuelType &&
          other.odometerKm == this.odometerKm &&
          other.odometerUpdatedAt == this.odometerUpdatedAt &&
          other.plate == this.plate &&
          other.photoPath == this.photoPath &&
          other.cachedProtocol == this.cachedProtocol &&
          other.supportedPidsJson == this.supportedPidsJson &&
          other.supportsBatching == this.supportsBatching &&
          other.isPrimary == this.isPrimary &&
          other.createdAt == this.createdAt);
}

class VehiclesCompanion extends UpdateCompanion<VehicleRow> {
  final Value<String> id;
  final Value<String> nickname;
  final Value<String?> vin;
  final Value<bool> vinUnverified;
  final Value<String> make;
  final Value<String> model;
  final Value<String> trim;
  final Value<int?> year;
  final Value<VehicleFuel> fuelType;
  final Value<double?> odometerKm;
  final Value<DateTime?> odometerUpdatedAt;
  final Value<String?> plate;
  final Value<String?> photoPath;
  final Value<int?> cachedProtocol;
  final Value<String?> supportedPidsJson;
  final Value<bool> supportsBatching;
  final Value<bool> isPrimary;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const VehiclesCompanion({
    this.id = const Value.absent(),
    this.nickname = const Value.absent(),
    this.vin = const Value.absent(),
    this.vinUnverified = const Value.absent(),
    this.make = const Value.absent(),
    this.model = const Value.absent(),
    this.trim = const Value.absent(),
    this.year = const Value.absent(),
    this.fuelType = const Value.absent(),
    this.odometerKm = const Value.absent(),
    this.odometerUpdatedAt = const Value.absent(),
    this.plate = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.cachedProtocol = const Value.absent(),
    this.supportedPidsJson = const Value.absent(),
    this.supportsBatching = const Value.absent(),
    this.isPrimary = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VehiclesCompanion.insert({
    required String id,
    required String nickname,
    this.vin = const Value.absent(),
    this.vinUnverified = const Value.absent(),
    this.make = const Value.absent(),
    this.model = const Value.absent(),
    this.trim = const Value.absent(),
    this.year = const Value.absent(),
    required VehicleFuel fuelType,
    this.odometerKm = const Value.absent(),
    this.odometerUpdatedAt = const Value.absent(),
    this.plate = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.cachedProtocol = const Value.absent(),
    this.supportedPidsJson = const Value.absent(),
    this.supportsBatching = const Value.absent(),
    this.isPrimary = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nickname = Value(nickname),
       fuelType = Value(fuelType),
       createdAt = Value(createdAt);
  static Insertable<VehicleRow> custom({
    Expression<String>? id,
    Expression<String>? nickname,
    Expression<String>? vin,
    Expression<bool>? vinUnverified,
    Expression<String>? make,
    Expression<String>? model,
    Expression<String>? trim,
    Expression<int>? year,
    Expression<String>? fuelType,
    Expression<double>? odometerKm,
    Expression<DateTime>? odometerUpdatedAt,
    Expression<String>? plate,
    Expression<String>? photoPath,
    Expression<int>? cachedProtocol,
    Expression<String>? supportedPidsJson,
    Expression<bool>? supportsBatching,
    Expression<bool>? isPrimary,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nickname != null) 'nickname': nickname,
      if (vin != null) 'vin': vin,
      if (vinUnverified != null) 'vin_unverified': vinUnverified,
      if (make != null) 'make': make,
      if (model != null) 'model': model,
      if (trim != null) 'trim': trim,
      if (year != null) 'year': year,
      if (fuelType != null) 'fuel_type': fuelType,
      if (odometerKm != null) 'odometer_km': odometerKm,
      if (odometerUpdatedAt != null) 'odometer_updated_at': odometerUpdatedAt,
      if (plate != null) 'plate': plate,
      if (photoPath != null) 'photo_path': photoPath,
      if (cachedProtocol != null) 'cached_protocol': cachedProtocol,
      if (supportedPidsJson != null) 'supported_pids_json': supportedPidsJson,
      if (supportsBatching != null) 'supports_batching': supportsBatching,
      if (isPrimary != null) 'is_primary': isPrimary,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VehiclesCompanion copyWith({
    Value<String>? id,
    Value<String>? nickname,
    Value<String?>? vin,
    Value<bool>? vinUnverified,
    Value<String>? make,
    Value<String>? model,
    Value<String>? trim,
    Value<int?>? year,
    Value<VehicleFuel>? fuelType,
    Value<double?>? odometerKm,
    Value<DateTime?>? odometerUpdatedAt,
    Value<String?>? plate,
    Value<String?>? photoPath,
    Value<int?>? cachedProtocol,
    Value<String?>? supportedPidsJson,
    Value<bool>? supportsBatching,
    Value<bool>? isPrimary,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return VehiclesCompanion(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      vin: vin ?? this.vin,
      vinUnverified: vinUnverified ?? this.vinUnverified,
      make: make ?? this.make,
      model: model ?? this.model,
      trim: trim ?? this.trim,
      year: year ?? this.year,
      fuelType: fuelType ?? this.fuelType,
      odometerKm: odometerKm ?? this.odometerKm,
      odometerUpdatedAt: odometerUpdatedAt ?? this.odometerUpdatedAt,
      plate: plate ?? this.plate,
      photoPath: photoPath ?? this.photoPath,
      cachedProtocol: cachedProtocol ?? this.cachedProtocol,
      supportedPidsJson: supportedPidsJson ?? this.supportedPidsJson,
      supportsBatching: supportsBatching ?? this.supportsBatching,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (vin.present) {
      map['vin'] = Variable<String>(vin.value);
    }
    if (vinUnverified.present) {
      map['vin_unverified'] = Variable<bool>(vinUnverified.value);
    }
    if (make.present) {
      map['make'] = Variable<String>(make.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (trim.present) {
      map['trim'] = Variable<String>(trim.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (fuelType.present) {
      map['fuel_type'] = Variable<String>(
        $VehiclesTable.$converterfuelType.toSql(fuelType.value),
      );
    }
    if (odometerKm.present) {
      map['odometer_km'] = Variable<double>(odometerKm.value);
    }
    if (odometerUpdatedAt.present) {
      map['odometer_updated_at'] = Variable<DateTime>(odometerUpdatedAt.value);
    }
    if (plate.present) {
      map['plate'] = Variable<String>(plate.value);
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (cachedProtocol.present) {
      map['cached_protocol'] = Variable<int>(cachedProtocol.value);
    }
    if (supportedPidsJson.present) {
      map['supported_pids_json'] = Variable<String>(supportedPidsJson.value);
    }
    if (supportsBatching.present) {
      map['supports_batching'] = Variable<bool>(supportsBatching.value);
    }
    if (isPrimary.present) {
      map['is_primary'] = Variable<bool>(isPrimary.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VehiclesCompanion(')
          ..write('id: $id, ')
          ..write('nickname: $nickname, ')
          ..write('vin: $vin, ')
          ..write('vinUnverified: $vinUnverified, ')
          ..write('make: $make, ')
          ..write('model: $model, ')
          ..write('trim: $trim, ')
          ..write('year: $year, ')
          ..write('fuelType: $fuelType, ')
          ..write('odometerKm: $odometerKm, ')
          ..write('odometerUpdatedAt: $odometerUpdatedAt, ')
          ..write('plate: $plate, ')
          ..write('photoPath: $photoPath, ')
          ..write('cachedProtocol: $cachedProtocol, ')
          ..write('supportedPidsJson: $supportedPidsJson, ')
          ..write('supportsBatching: $supportsBatching, ')
          ..write('isPrimary: $isPrimary, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ServiceRecordsTable extends ServiceRecords
    with TableInfo<$ServiceRecordsTable, ServiceRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServiceRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ServiceType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ServiceType>($ServiceRecordsTable.$convertertype);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    check: () => ComparableExpr(title.length).isBetweenValues(1, 200),
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _odometerKmMeta = const VerificationMeta(
    'odometerKm',
  );
  @override
  late final GeneratedColumn<double> odometerKm = GeneratedColumn<double>(
    'odometer_km',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _costMeta = const VerificationMeta('cost');
  @override
  late final GeneratedColumn<double> cost = GeneratedColumn<double>(
    'cost',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    check: () => currencyCode.length.equals(3),
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('USD'),
  );
  static const VerificationMeta _vendorMeta = const VerificationMeta('vendor');
  @override
  late final GeneratedColumn<String> vendor = GeneratedColumn<String>(
    'vendor',
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
    check: () =>
        notes.isNull() |
        ComparableExpr(notes.length).isSmallerOrEqualValue(5000),
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 5000),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attachmentPathsJsonMeta =
      const VerificationMeta('attachmentPathsJson');
  @override
  late final GeneratedColumn<String> attachmentPathsJson =
      GeneratedColumn<String>(
        'attachment_paths_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _linkedDtcsJsonMeta = const VerificationMeta(
    'linkedDtcsJson',
  );
  @override
  late final GeneratedColumn<String> linkedDtcsJson = GeneratedColumn<String>(
    'linked_dtcs_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
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
    vehicleId,
    type,
    title,
    date,
    odometerKm,
    cost,
    currencyCode,
    vendor,
    notes,
    attachmentPathsJson,
    linkedDtcsJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'service_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<ServiceRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('odometer_km')) {
      context.handle(
        _odometerKmMeta,
        odometerKm.isAcceptableOrUnknown(data['odometer_km']!, _odometerKmMeta),
      );
    }
    if (data.containsKey('cost')) {
      context.handle(
        _costMeta,
        cost.isAcceptableOrUnknown(data['cost']!, _costMeta),
      );
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    }
    if (data.containsKey('vendor')) {
      context.handle(
        _vendorMeta,
        vendor.isAcceptableOrUnknown(data['vendor']!, _vendorMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('attachment_paths_json')) {
      context.handle(
        _attachmentPathsJsonMeta,
        attachmentPathsJson.isAcceptableOrUnknown(
          data['attachment_paths_json']!,
          _attachmentPathsJsonMeta,
        ),
      );
    }
    if (data.containsKey('linked_dtcs_json')) {
      context.handle(
        _linkedDtcsJsonMeta,
        linkedDtcsJson.isAcceptableOrUnknown(
          data['linked_dtcs_json']!,
          _linkedDtcsJsonMeta,
        ),
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
  ServiceRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ServiceRecordRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      type: $ServiceRecordsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      odometerKm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}odometer_km'],
      ),
      cost: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cost'],
      ),
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      vendor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vendor'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      attachmentPathsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_paths_json'],
      )!,
      linkedDtcsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_dtcs_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ServiceRecordsTable createAlias(String alias) {
    return $ServiceRecordsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ServiceType, String, String> $convertertype =
      const EnumNameConverter<ServiceType>(ServiceType.values);
}

class ServiceRecordRow extends DataClass
    implements Insertable<ServiceRecordRow> {
  final String id;
  final String vehicleId;
  final ServiceType type;
  final String title;
  final DateTime date;
  final double? odometerKm;
  final double? cost;
  final String currencyCode;
  final String? vendor;
  final String? notes;

  /// JSON list of file paths relative to the documents directory.
  final String attachmentPathsJson;

  /// JSON list of DTC codes this work addressed, e.g. `["P0301"]`. Links a
  /// repair back to the fault it cleared.
  final String linkedDtcsJson;
  final DateTime createdAt;
  const ServiceRecordRow({
    required this.id,
    required this.vehicleId,
    required this.type,
    required this.title,
    required this.date,
    this.odometerKm,
    this.cost,
    required this.currencyCode,
    this.vendor,
    this.notes,
    required this.attachmentPathsJson,
    required this.linkedDtcsJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['vehicle_id'] = Variable<String>(vehicleId);
    {
      map['type'] = Variable<String>(
        $ServiceRecordsTable.$convertertype.toSql(type),
      );
    }
    map['title'] = Variable<String>(title);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || odometerKm != null) {
      map['odometer_km'] = Variable<double>(odometerKm);
    }
    if (!nullToAbsent || cost != null) {
      map['cost'] = Variable<double>(cost);
    }
    map['currency_code'] = Variable<String>(currencyCode);
    if (!nullToAbsent || vendor != null) {
      map['vendor'] = Variable<String>(vendor);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['attachment_paths_json'] = Variable<String>(attachmentPathsJson);
    map['linked_dtcs_json'] = Variable<String>(linkedDtcsJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ServiceRecordsCompanion toCompanion(bool nullToAbsent) {
    return ServiceRecordsCompanion(
      id: Value(id),
      vehicleId: Value(vehicleId),
      type: Value(type),
      title: Value(title),
      date: Value(date),
      odometerKm: odometerKm == null && nullToAbsent
          ? const Value.absent()
          : Value(odometerKm),
      cost: cost == null && nullToAbsent ? const Value.absent() : Value(cost),
      currencyCode: Value(currencyCode),
      vendor: vendor == null && nullToAbsent
          ? const Value.absent()
          : Value(vendor),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      attachmentPathsJson: Value(attachmentPathsJson),
      linkedDtcsJson: Value(linkedDtcsJson),
      createdAt: Value(createdAt),
    );
  }

  factory ServiceRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ServiceRecordRow(
      id: serializer.fromJson<String>(json['id']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      type: $ServiceRecordsTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      title: serializer.fromJson<String>(json['title']),
      date: serializer.fromJson<DateTime>(json['date']),
      odometerKm: serializer.fromJson<double?>(json['odometerKm']),
      cost: serializer.fromJson<double?>(json['cost']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      vendor: serializer.fromJson<String?>(json['vendor']),
      notes: serializer.fromJson<String?>(json['notes']),
      attachmentPathsJson: serializer.fromJson<String>(
        json['attachmentPathsJson'],
      ),
      linkedDtcsJson: serializer.fromJson<String>(json['linkedDtcsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'type': serializer.toJson<String>(
        $ServiceRecordsTable.$convertertype.toJson(type),
      ),
      'title': serializer.toJson<String>(title),
      'date': serializer.toJson<DateTime>(date),
      'odometerKm': serializer.toJson<double?>(odometerKm),
      'cost': serializer.toJson<double?>(cost),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'vendor': serializer.toJson<String?>(vendor),
      'notes': serializer.toJson<String?>(notes),
      'attachmentPathsJson': serializer.toJson<String>(attachmentPathsJson),
      'linkedDtcsJson': serializer.toJson<String>(linkedDtcsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ServiceRecordRow copyWith({
    String? id,
    String? vehicleId,
    ServiceType? type,
    String? title,
    DateTime? date,
    Value<double?> odometerKm = const Value.absent(),
    Value<double?> cost = const Value.absent(),
    String? currencyCode,
    Value<String?> vendor = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    String? attachmentPathsJson,
    String? linkedDtcsJson,
    DateTime? createdAt,
  }) => ServiceRecordRow(
    id: id ?? this.id,
    vehicleId: vehicleId ?? this.vehicleId,
    type: type ?? this.type,
    title: title ?? this.title,
    date: date ?? this.date,
    odometerKm: odometerKm.present ? odometerKm.value : this.odometerKm,
    cost: cost.present ? cost.value : this.cost,
    currencyCode: currencyCode ?? this.currencyCode,
    vendor: vendor.present ? vendor.value : this.vendor,
    notes: notes.present ? notes.value : this.notes,
    attachmentPathsJson: attachmentPathsJson ?? this.attachmentPathsJson,
    linkedDtcsJson: linkedDtcsJson ?? this.linkedDtcsJson,
    createdAt: createdAt ?? this.createdAt,
  );
  ServiceRecordRow copyWithCompanion(ServiceRecordsCompanion data) {
    return ServiceRecordRow(
      id: data.id.present ? data.id.value : this.id,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      date: data.date.present ? data.date.value : this.date,
      odometerKm: data.odometerKm.present
          ? data.odometerKm.value
          : this.odometerKm,
      cost: data.cost.present ? data.cost.value : this.cost,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      vendor: data.vendor.present ? data.vendor.value : this.vendor,
      notes: data.notes.present ? data.notes.value : this.notes,
      attachmentPathsJson: data.attachmentPathsJson.present
          ? data.attachmentPathsJson.value
          : this.attachmentPathsJson,
      linkedDtcsJson: data.linkedDtcsJson.present
          ? data.linkedDtcsJson.value
          : this.linkedDtcsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ServiceRecordRow(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('date: $date, ')
          ..write('odometerKm: $odometerKm, ')
          ..write('cost: $cost, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('vendor: $vendor, ')
          ..write('notes: $notes, ')
          ..write('attachmentPathsJson: $attachmentPathsJson, ')
          ..write('linkedDtcsJson: $linkedDtcsJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    type,
    title,
    date,
    odometerKm,
    cost,
    currencyCode,
    vendor,
    notes,
    attachmentPathsJson,
    linkedDtcsJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServiceRecordRow &&
          other.id == this.id &&
          other.vehicleId == this.vehicleId &&
          other.type == this.type &&
          other.title == this.title &&
          other.date == this.date &&
          other.odometerKm == this.odometerKm &&
          other.cost == this.cost &&
          other.currencyCode == this.currencyCode &&
          other.vendor == this.vendor &&
          other.notes == this.notes &&
          other.attachmentPathsJson == this.attachmentPathsJson &&
          other.linkedDtcsJson == this.linkedDtcsJson &&
          other.createdAt == this.createdAt);
}

class ServiceRecordsCompanion extends UpdateCompanion<ServiceRecordRow> {
  final Value<String> id;
  final Value<String> vehicleId;
  final Value<ServiceType> type;
  final Value<String> title;
  final Value<DateTime> date;
  final Value<double?> odometerKm;
  final Value<double?> cost;
  final Value<String> currencyCode;
  final Value<String?> vendor;
  final Value<String?> notes;
  final Value<String> attachmentPathsJson;
  final Value<String> linkedDtcsJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ServiceRecordsCompanion({
    this.id = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.date = const Value.absent(),
    this.odometerKm = const Value.absent(),
    this.cost = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.vendor = const Value.absent(),
    this.notes = const Value.absent(),
    this.attachmentPathsJson = const Value.absent(),
    this.linkedDtcsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ServiceRecordsCompanion.insert({
    required String id,
    required String vehicleId,
    required ServiceType type,
    required String title,
    required DateTime date,
    this.odometerKm = const Value.absent(),
    this.cost = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.vendor = const Value.absent(),
    this.notes = const Value.absent(),
    this.attachmentPathsJson = const Value.absent(),
    this.linkedDtcsJson = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       vehicleId = Value(vehicleId),
       type = Value(type),
       title = Value(title),
       date = Value(date),
       createdAt = Value(createdAt);
  static Insertable<ServiceRecordRow> custom({
    Expression<String>? id,
    Expression<String>? vehicleId,
    Expression<String>? type,
    Expression<String>? title,
    Expression<DateTime>? date,
    Expression<double>? odometerKm,
    Expression<double>? cost,
    Expression<String>? currencyCode,
    Expression<String>? vendor,
    Expression<String>? notes,
    Expression<String>? attachmentPathsJson,
    Expression<String>? linkedDtcsJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (date != null) 'date': date,
      if (odometerKm != null) 'odometer_km': odometerKm,
      if (cost != null) 'cost': cost,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (vendor != null) 'vendor': vendor,
      if (notes != null) 'notes': notes,
      if (attachmentPathsJson != null)
        'attachment_paths_json': attachmentPathsJson,
      if (linkedDtcsJson != null) 'linked_dtcs_json': linkedDtcsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ServiceRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? vehicleId,
    Value<ServiceType>? type,
    Value<String>? title,
    Value<DateTime>? date,
    Value<double?>? odometerKm,
    Value<double?>? cost,
    Value<String>? currencyCode,
    Value<String?>? vendor,
    Value<String?>? notes,
    Value<String>? attachmentPathsJson,
    Value<String>? linkedDtcsJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ServiceRecordsCompanion(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      type: type ?? this.type,
      title: title ?? this.title,
      date: date ?? this.date,
      odometerKm: odometerKm ?? this.odometerKm,
      cost: cost ?? this.cost,
      currencyCode: currencyCode ?? this.currencyCode,
      vendor: vendor ?? this.vendor,
      notes: notes ?? this.notes,
      attachmentPathsJson: attachmentPathsJson ?? this.attachmentPathsJson,
      linkedDtcsJson: linkedDtcsJson ?? this.linkedDtcsJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $ServiceRecordsTable.$convertertype.toSql(type.value),
      );
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (odometerKm.present) {
      map['odometer_km'] = Variable<double>(odometerKm.value);
    }
    if (cost.present) {
      map['cost'] = Variable<double>(cost.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (vendor.present) {
      map['vendor'] = Variable<String>(vendor.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (attachmentPathsJson.present) {
      map['attachment_paths_json'] = Variable<String>(
        attachmentPathsJson.value,
      );
    }
    if (linkedDtcsJson.present) {
      map['linked_dtcs_json'] = Variable<String>(linkedDtcsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServiceRecordsCompanion(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('date: $date, ')
          ..write('odometerKm: $odometerKm, ')
          ..write('cost: $cost, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('vendor: $vendor, ')
          ..write('notes: $notes, ')
          ..write('attachmentPathsJson: $attachmentPathsJson, ')
          ..write('linkedDtcsJson: $linkedDtcsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, ReminderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    check: () => ComparableExpr(title.length).isBetweenValues(1, 200),
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueOdometerKmMeta = const VerificationMeta(
    'dueOdometerKm',
  );
  @override
  late final GeneratedColumn<double> dueOdometerKm = GeneratedColumn<double>(
    'due_odometer_km',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repeatEveryDaysMeta = const VerificationMeta(
    'repeatEveryDays',
  );
  @override
  late final GeneratedColumn<int> repeatEveryDays = GeneratedColumn<int>(
    'repeat_every_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repeatEveryKmMeta = const VerificationMeta(
    'repeatEveryKm',
  );
  @override
  late final GeneratedColumn<double> repeatEveryKm = GeneratedColumn<double>(
    'repeat_every_km',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _criticalMeta = const VerificationMeta(
    'critical',
  );
  @override
  late final GeneratedColumn<bool> critical = GeneratedColumn<bool>(
    'critical',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("critical" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _pausedMeta = const VerificationMeta('paused');
  @override
  late final GeneratedColumn<bool> paused = GeneratedColumn<bool>(
    'paused',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("paused" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    vehicleId,
    title,
    detail,
    dueDate,
    dueOdometerKm,
    repeatEveryDays,
    repeatEveryKm,
    critical,
    paused,
    completedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReminderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('due_odometer_km')) {
      context.handle(
        _dueOdometerKmMeta,
        dueOdometerKm.isAcceptableOrUnknown(
          data['due_odometer_km']!,
          _dueOdometerKmMeta,
        ),
      );
    }
    if (data.containsKey('repeat_every_days')) {
      context.handle(
        _repeatEveryDaysMeta,
        repeatEveryDays.isAcceptableOrUnknown(
          data['repeat_every_days']!,
          _repeatEveryDaysMeta,
        ),
      );
    }
    if (data.containsKey('repeat_every_km')) {
      context.handle(
        _repeatEveryKmMeta,
        repeatEveryKm.isAcceptableOrUnknown(
          data['repeat_every_km']!,
          _repeatEveryKmMeta,
        ),
      );
    }
    if (data.containsKey('critical')) {
      context.handle(
        _criticalMeta,
        critical.isAcceptableOrUnknown(data['critical']!, _criticalMeta),
      );
    }
    if (data.containsKey('paused')) {
      context.handle(
        _pausedMeta,
        paused.isAcceptableOrUnknown(data['paused']!, _pausedMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
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
  ReminderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      ),
      dueOdometerKm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}due_odometer_km'],
      ),
      repeatEveryDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repeat_every_days'],
      ),
      repeatEveryKm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}repeat_every_km'],
      ),
      critical: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}critical'],
      )!,
      paused: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}paused'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }
}

class ReminderRow extends DataClass implements Insertable<ReminderRow> {
  final String id;
  final String vehicleId;
  final String title;
  final String? detail;

  /// Due by date, by odometer, or both — whichever comes first.
  final DateTime? dueDate;
  final double? dueOdometerKm;

  /// Recurrence, applied when the reminder is completed.
  final int? repeatEveryDays;
  final double? repeatEveryKm;
  final bool critical;
  final bool paused;
  final DateTime? completedAt;
  final DateTime createdAt;
  const ReminderRow({
    required this.id,
    required this.vehicleId,
    required this.title,
    this.detail,
    this.dueDate,
    this.dueOdometerKm,
    this.repeatEveryDays,
    this.repeatEveryKm,
    required this.critical,
    required this.paused,
    this.completedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    if (!nullToAbsent || dueOdometerKm != null) {
      map['due_odometer_km'] = Variable<double>(dueOdometerKm);
    }
    if (!nullToAbsent || repeatEveryDays != null) {
      map['repeat_every_days'] = Variable<int>(repeatEveryDays);
    }
    if (!nullToAbsent || repeatEveryKm != null) {
      map['repeat_every_km'] = Variable<double>(repeatEveryKm);
    }
    map['critical'] = Variable<bool>(critical);
    map['paused'] = Variable<bool>(paused);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      id: Value(id),
      vehicleId: Value(vehicleId),
      title: Value(title),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      dueOdometerKm: dueOdometerKm == null && nullToAbsent
          ? const Value.absent()
          : Value(dueOdometerKm),
      repeatEveryDays: repeatEveryDays == null && nullToAbsent
          ? const Value.absent()
          : Value(repeatEveryDays),
      repeatEveryKm: repeatEveryKm == null && nullToAbsent
          ? const Value.absent()
          : Value(repeatEveryKm),
      critical: Value(critical),
      paused: Value(paused),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      createdAt: Value(createdAt),
    );
  }

  factory ReminderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderRow(
      id: serializer.fromJson<String>(json['id']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      title: serializer.fromJson<String>(json['title']),
      detail: serializer.fromJson<String?>(json['detail']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      dueOdometerKm: serializer.fromJson<double?>(json['dueOdometerKm']),
      repeatEveryDays: serializer.fromJson<int?>(json['repeatEveryDays']),
      repeatEveryKm: serializer.fromJson<double?>(json['repeatEveryKm']),
      critical: serializer.fromJson<bool>(json['critical']),
      paused: serializer.fromJson<bool>(json['paused']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'title': serializer.toJson<String>(title),
      'detail': serializer.toJson<String?>(detail),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'dueOdometerKm': serializer.toJson<double?>(dueOdometerKm),
      'repeatEveryDays': serializer.toJson<int?>(repeatEveryDays),
      'repeatEveryKm': serializer.toJson<double?>(repeatEveryKm),
      'critical': serializer.toJson<bool>(critical),
      'paused': serializer.toJson<bool>(paused),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ReminderRow copyWith({
    String? id,
    String? vehicleId,
    String? title,
    Value<String?> detail = const Value.absent(),
    Value<DateTime?> dueDate = const Value.absent(),
    Value<double?> dueOdometerKm = const Value.absent(),
    Value<int?> repeatEveryDays = const Value.absent(),
    Value<double?> repeatEveryKm = const Value.absent(),
    bool? critical,
    bool? paused,
    Value<DateTime?> completedAt = const Value.absent(),
    DateTime? createdAt,
  }) => ReminderRow(
    id: id ?? this.id,
    vehicleId: vehicleId ?? this.vehicleId,
    title: title ?? this.title,
    detail: detail.present ? detail.value : this.detail,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    dueOdometerKm: dueOdometerKm.present
        ? dueOdometerKm.value
        : this.dueOdometerKm,
    repeatEveryDays: repeatEveryDays.present
        ? repeatEveryDays.value
        : this.repeatEveryDays,
    repeatEveryKm: repeatEveryKm.present
        ? repeatEveryKm.value
        : this.repeatEveryKm,
    critical: critical ?? this.critical,
    paused: paused ?? this.paused,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  ReminderRow copyWithCompanion(RemindersCompanion data) {
    return ReminderRow(
      id: data.id.present ? data.id.value : this.id,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      title: data.title.present ? data.title.value : this.title,
      detail: data.detail.present ? data.detail.value : this.detail,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      dueOdometerKm: data.dueOdometerKm.present
          ? data.dueOdometerKm.value
          : this.dueOdometerKm,
      repeatEveryDays: data.repeatEveryDays.present
          ? data.repeatEveryDays.value
          : this.repeatEveryDays,
      repeatEveryKm: data.repeatEveryKm.present
          ? data.repeatEveryKm.value
          : this.repeatEveryKm,
      critical: data.critical.present ? data.critical.value : this.critical,
      paused: data.paused.present ? data.paused.value : this.paused,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderRow(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('title: $title, ')
          ..write('detail: $detail, ')
          ..write('dueDate: $dueDate, ')
          ..write('dueOdometerKm: $dueOdometerKm, ')
          ..write('repeatEveryDays: $repeatEveryDays, ')
          ..write('repeatEveryKm: $repeatEveryKm, ')
          ..write('critical: $critical, ')
          ..write('paused: $paused, ')
          ..write('completedAt: $completedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    title,
    detail,
    dueDate,
    dueOdometerKm,
    repeatEveryDays,
    repeatEveryKm,
    critical,
    paused,
    completedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderRow &&
          other.id == this.id &&
          other.vehicleId == this.vehicleId &&
          other.title == this.title &&
          other.detail == this.detail &&
          other.dueDate == this.dueDate &&
          other.dueOdometerKm == this.dueOdometerKm &&
          other.repeatEveryDays == this.repeatEveryDays &&
          other.repeatEveryKm == this.repeatEveryKm &&
          other.critical == this.critical &&
          other.paused == this.paused &&
          other.completedAt == this.completedAt &&
          other.createdAt == this.createdAt);
}

class RemindersCompanion extends UpdateCompanion<ReminderRow> {
  final Value<String> id;
  final Value<String> vehicleId;
  final Value<String> title;
  final Value<String?> detail;
  final Value<DateTime?> dueDate;
  final Value<double?> dueOdometerKm;
  final Value<int?> repeatEveryDays;
  final Value<double?> repeatEveryKm;
  final Value<bool> critical;
  final Value<bool> paused;
  final Value<DateTime?> completedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const RemindersCompanion({
    this.id = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.title = const Value.absent(),
    this.detail = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.dueOdometerKm = const Value.absent(),
    this.repeatEveryDays = const Value.absent(),
    this.repeatEveryKm = const Value.absent(),
    this.critical = const Value.absent(),
    this.paused = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemindersCompanion.insert({
    required String id,
    required String vehicleId,
    required String title,
    this.detail = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.dueOdometerKm = const Value.absent(),
    this.repeatEveryDays = const Value.absent(),
    this.repeatEveryKm = const Value.absent(),
    this.critical = const Value.absent(),
    this.paused = const Value.absent(),
    this.completedAt = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       vehicleId = Value(vehicleId),
       title = Value(title),
       createdAt = Value(createdAt);
  static Insertable<ReminderRow> custom({
    Expression<String>? id,
    Expression<String>? vehicleId,
    Expression<String>? title,
    Expression<String>? detail,
    Expression<DateTime>? dueDate,
    Expression<double>? dueOdometerKm,
    Expression<int>? repeatEveryDays,
    Expression<double>? repeatEveryKm,
    Expression<bool>? critical,
    Expression<bool>? paused,
    Expression<DateTime>? completedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (title != null) 'title': title,
      if (detail != null) 'detail': detail,
      if (dueDate != null) 'due_date': dueDate,
      if (dueOdometerKm != null) 'due_odometer_km': dueOdometerKm,
      if (repeatEveryDays != null) 'repeat_every_days': repeatEveryDays,
      if (repeatEveryKm != null) 'repeat_every_km': repeatEveryKm,
      if (critical != null) 'critical': critical,
      if (paused != null) 'paused': paused,
      if (completedAt != null) 'completed_at': completedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemindersCompanion copyWith({
    Value<String>? id,
    Value<String>? vehicleId,
    Value<String>? title,
    Value<String?>? detail,
    Value<DateTime?>? dueDate,
    Value<double?>? dueOdometerKm,
    Value<int?>? repeatEveryDays,
    Value<double?>? repeatEveryKm,
    Value<bool>? critical,
    Value<bool>? paused,
    Value<DateTime?>? completedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return RemindersCompanion(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      dueDate: dueDate ?? this.dueDate,
      dueOdometerKm: dueOdometerKm ?? this.dueOdometerKm,
      repeatEveryDays: repeatEveryDays ?? this.repeatEveryDays,
      repeatEveryKm: repeatEveryKm ?? this.repeatEveryKm,
      critical: critical ?? this.critical,
      paused: paused ?? this.paused,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (dueOdometerKm.present) {
      map['due_odometer_km'] = Variable<double>(dueOdometerKm.value);
    }
    if (repeatEveryDays.present) {
      map['repeat_every_days'] = Variable<int>(repeatEveryDays.value);
    }
    if (repeatEveryKm.present) {
      map['repeat_every_km'] = Variable<double>(repeatEveryKm.value);
    }
    if (critical.present) {
      map['critical'] = Variable<bool>(critical.value);
    }
    if (paused.present) {
      map['paused'] = Variable<bool>(paused.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('title: $title, ')
          ..write('detail: $detail, ')
          ..write('dueDate: $dueDate, ')
          ..write('dueOdometerKm: $dueOdometerKm, ')
          ..write('repeatEveryDays: $repeatEveryDays, ')
          ..write('repeatEveryKm: $repeatEveryKm, ')
          ..write('critical: $critical, ')
          ..write('paused: $paused, ')
          ..write('completedAt: $completedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FuelEntriesTable extends FuelEntries
    with TableInfo<$FuelEntriesTable, FuelEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FuelEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _odometerKmMeta = const VerificationMeta(
    'odometerKm',
  );
  @override
  late final GeneratedColumn<double> odometerKm = GeneratedColumn<double>(
    'odometer_km',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _litresMeta = const VerificationMeta('litres');
  @override
  late final GeneratedColumn<double> litres = GeneratedColumn<double>(
    'litres',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _costMeta = const VerificationMeta('cost');
  @override
  late final GeneratedColumn<double> cost = GeneratedColumn<double>(
    'cost',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    check: () => currencyCode.length.equals(3),
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 3,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('USD'),
  );
  static const VerificationMeta _partFillMeta = const VerificationMeta(
    'partFill',
  );
  @override
  late final GeneratedColumn<bool> partFill = GeneratedColumn<bool>(
    'part_fill',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("part_fill" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    vehicleId,
    date,
    odometerKm,
    litres,
    cost,
    currencyCode,
    partFill,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fuel_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<FuelEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('odometer_km')) {
      context.handle(
        _odometerKmMeta,
        odometerKm.isAcceptableOrUnknown(data['odometer_km']!, _odometerKmMeta),
      );
    } else if (isInserting) {
      context.missing(_odometerKmMeta);
    }
    if (data.containsKey('litres')) {
      context.handle(
        _litresMeta,
        litres.isAcceptableOrUnknown(data['litres']!, _litresMeta),
      );
    } else if (isInserting) {
      context.missing(_litresMeta);
    }
    if (data.containsKey('cost')) {
      context.handle(
        _costMeta,
        cost.isAcceptableOrUnknown(data['cost']!, _costMeta),
      );
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    }
    if (data.containsKey('part_fill')) {
      context.handle(
        _partFillMeta,
        partFill.isAcceptableOrUnknown(data['part_fill']!, _partFillMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FuelEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FuelEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      odometerKm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}odometer_km'],
      )!,
      litres: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}litres'],
      )!,
      cost: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cost'],
      ),
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      partFill: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}part_fill'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $FuelEntriesTable createAlias(String alias) {
    return $FuelEntriesTable(attachedDatabase, alias);
  }
}

class FuelEntryRow extends DataClass implements Insertable<FuelEntryRow> {
  final String id;
  final String vehicleId;
  final DateTime date;
  final double odometerKm;
  final double litres;
  final double? cost;
  final String currencyCode;

  /// Economy is only computed between full fills. A partial fill is kept
  /// for cost tracking and skipped for consumption.
  final bool partFill;
  final String? notes;
  const FuelEntryRow({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.odometerKm,
    required this.litres,
    this.cost,
    required this.currencyCode,
    required this.partFill,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['date'] = Variable<DateTime>(date);
    map['odometer_km'] = Variable<double>(odometerKm);
    map['litres'] = Variable<double>(litres);
    if (!nullToAbsent || cost != null) {
      map['cost'] = Variable<double>(cost);
    }
    map['currency_code'] = Variable<String>(currencyCode);
    map['part_fill'] = Variable<bool>(partFill);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  FuelEntriesCompanion toCompanion(bool nullToAbsent) {
    return FuelEntriesCompanion(
      id: Value(id),
      vehicleId: Value(vehicleId),
      date: Value(date),
      odometerKm: Value(odometerKm),
      litres: Value(litres),
      cost: cost == null && nullToAbsent ? const Value.absent() : Value(cost),
      currencyCode: Value(currencyCode),
      partFill: Value(partFill),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory FuelEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FuelEntryRow(
      id: serializer.fromJson<String>(json['id']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      date: serializer.fromJson<DateTime>(json['date']),
      odometerKm: serializer.fromJson<double>(json['odometerKm']),
      litres: serializer.fromJson<double>(json['litres']),
      cost: serializer.fromJson<double?>(json['cost']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      partFill: serializer.fromJson<bool>(json['partFill']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'date': serializer.toJson<DateTime>(date),
      'odometerKm': serializer.toJson<double>(odometerKm),
      'litres': serializer.toJson<double>(litres),
      'cost': serializer.toJson<double?>(cost),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'partFill': serializer.toJson<bool>(partFill),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  FuelEntryRow copyWith({
    String? id,
    String? vehicleId,
    DateTime? date,
    double? odometerKm,
    double? litres,
    Value<double?> cost = const Value.absent(),
    String? currencyCode,
    bool? partFill,
    Value<String?> notes = const Value.absent(),
  }) => FuelEntryRow(
    id: id ?? this.id,
    vehicleId: vehicleId ?? this.vehicleId,
    date: date ?? this.date,
    odometerKm: odometerKm ?? this.odometerKm,
    litres: litres ?? this.litres,
    cost: cost.present ? cost.value : this.cost,
    currencyCode: currencyCode ?? this.currencyCode,
    partFill: partFill ?? this.partFill,
    notes: notes.present ? notes.value : this.notes,
  );
  FuelEntryRow copyWithCompanion(FuelEntriesCompanion data) {
    return FuelEntryRow(
      id: data.id.present ? data.id.value : this.id,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      date: data.date.present ? data.date.value : this.date,
      odometerKm: data.odometerKm.present
          ? data.odometerKm.value
          : this.odometerKm,
      litres: data.litres.present ? data.litres.value : this.litres,
      cost: data.cost.present ? data.cost.value : this.cost,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      partFill: data.partFill.present ? data.partFill.value : this.partFill,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FuelEntryRow(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('date: $date, ')
          ..write('odometerKm: $odometerKm, ')
          ..write('litres: $litres, ')
          ..write('cost: $cost, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('partFill: $partFill, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    date,
    odometerKm,
    litres,
    cost,
    currencyCode,
    partFill,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FuelEntryRow &&
          other.id == this.id &&
          other.vehicleId == this.vehicleId &&
          other.date == this.date &&
          other.odometerKm == this.odometerKm &&
          other.litres == this.litres &&
          other.cost == this.cost &&
          other.currencyCode == this.currencyCode &&
          other.partFill == this.partFill &&
          other.notes == this.notes);
}

class FuelEntriesCompanion extends UpdateCompanion<FuelEntryRow> {
  final Value<String> id;
  final Value<String> vehicleId;
  final Value<DateTime> date;
  final Value<double> odometerKm;
  final Value<double> litres;
  final Value<double?> cost;
  final Value<String> currencyCode;
  final Value<bool> partFill;
  final Value<String?> notes;
  final Value<int> rowid;
  const FuelEntriesCompanion({
    this.id = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.date = const Value.absent(),
    this.odometerKm = const Value.absent(),
    this.litres = const Value.absent(),
    this.cost = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.partFill = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FuelEntriesCompanion.insert({
    required String id,
    required String vehicleId,
    required DateTime date,
    required double odometerKm,
    required double litres,
    this.cost = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.partFill = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       vehicleId = Value(vehicleId),
       date = Value(date),
       odometerKm = Value(odometerKm),
       litres = Value(litres);
  static Insertable<FuelEntryRow> custom({
    Expression<String>? id,
    Expression<String>? vehicleId,
    Expression<DateTime>? date,
    Expression<double>? odometerKm,
    Expression<double>? litres,
    Expression<double>? cost,
    Expression<String>? currencyCode,
    Expression<bool>? partFill,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (date != null) 'date': date,
      if (odometerKm != null) 'odometer_km': odometerKm,
      if (litres != null) 'litres': litres,
      if (cost != null) 'cost': cost,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (partFill != null) 'part_fill': partFill,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FuelEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? vehicleId,
    Value<DateTime>? date,
    Value<double>? odometerKm,
    Value<double>? litres,
    Value<double?>? cost,
    Value<String>? currencyCode,
    Value<bool>? partFill,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return FuelEntriesCompanion(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      date: date ?? this.date,
      odometerKm: odometerKm ?? this.odometerKm,
      litres: litres ?? this.litres,
      cost: cost ?? this.cost,
      currencyCode: currencyCode ?? this.currencyCode,
      partFill: partFill ?? this.partFill,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (odometerKm.present) {
      map['odometer_km'] = Variable<double>(odometerKm.value);
    }
    if (litres.present) {
      map['litres'] = Variable<double>(litres.value);
    }
    if (cost.present) {
      map['cost'] = Variable<double>(cost.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (partFill.present) {
      map['part_fill'] = Variable<bool>(partFill.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FuelEntriesCompanion(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('date: $date, ')
          ..write('odometerKm: $odometerKm, ')
          ..write('litres: $litres, ')
          ..write('cost: $cost, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('partFill: $partFill, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DtcSnapshotsTable extends DtcSnapshots
    with TableInfo<$DtcSnapshotsTable, DtcSnapshotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DtcSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _takenAtMeta = const VerificationMeta(
    'takenAt',
  );
  @override
  late final GeneratedColumn<DateTime> takenAt = GeneratedColumn<DateTime>(
    'taken_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<SnapshotPurpose, String> purpose =
      GeneratedColumn<String>(
        'purpose',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SnapshotPurpose>($DtcSnapshotsTable.$converterpurpose);
  static const VerificationMeta _codesJsonMeta = const VerificationMeta(
    'codesJson',
  );
  @override
  late final GeneratedColumn<String> codesJson = GeneratedColumn<String>(
    'codes_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _milOnMeta = const VerificationMeta('milOn');
  @override
  late final GeneratedColumn<bool> milOn = GeneratedColumn<bool>(
    'mil_on',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("mil_on" IN (0, 1))',
    ),
  );
  static const VerificationMeta _dtcCountMeta = const VerificationMeta(
    'dtcCount',
  );
  @override
  late final GeneratedColumn<int> dtcCount = GeneratedColumn<int>(
    'dtc_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _readinessJsonMeta = const VerificationMeta(
    'readinessJson',
  );
  @override
  late final GeneratedColumn<String> readinessJson = GeneratedColumn<String>(
    'readiness_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _protocolMeta = const VerificationMeta(
    'protocol',
  );
  @override
  late final GeneratedColumn<int> protocol = GeneratedColumn<int>(
    'protocol',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ClearOutcome?, String>
  clearOutcome = GeneratedColumn<String>(
    'clear_outcome',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<ClearOutcome?>($DtcSnapshotsTable.$converterclearOutcomen);
  static const VerificationMeta _relatedSnapshotIdMeta = const VerificationMeta(
    'relatedSnapshotId',
  );
  @override
  late final GeneratedColumn<String> relatedSnapshotId =
      GeneratedColumn<String>(
        'related_snapshot_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _freezeFrameJsonMeta = const VerificationMeta(
    'freezeFrameJson',
  );
  @override
  late final GeneratedColumn<String> freezeFrameJson = GeneratedColumn<String>(
    'freeze_frame_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    vehicleId,
    takenAt,
    purpose,
    codesJson,
    milOn,
    dtcCount,
    readinessJson,
    protocol,
    clearOutcome,
    relatedSnapshotId,
    freezeFrameJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dtc_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<DtcSnapshotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('taken_at')) {
      context.handle(
        _takenAtMeta,
        takenAt.isAcceptableOrUnknown(data['taken_at']!, _takenAtMeta),
      );
    } else if (isInserting) {
      context.missing(_takenAtMeta);
    }
    if (data.containsKey('codes_json')) {
      context.handle(
        _codesJsonMeta,
        codesJson.isAcceptableOrUnknown(data['codes_json']!, _codesJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_codesJsonMeta);
    }
    if (data.containsKey('mil_on')) {
      context.handle(
        _milOnMeta,
        milOn.isAcceptableOrUnknown(data['mil_on']!, _milOnMeta),
      );
    }
    if (data.containsKey('dtc_count')) {
      context.handle(
        _dtcCountMeta,
        dtcCount.isAcceptableOrUnknown(data['dtc_count']!, _dtcCountMeta),
      );
    }
    if (data.containsKey('readiness_json')) {
      context.handle(
        _readinessJsonMeta,
        readinessJson.isAcceptableOrUnknown(
          data['readiness_json']!,
          _readinessJsonMeta,
        ),
      );
    }
    if (data.containsKey('protocol')) {
      context.handle(
        _protocolMeta,
        protocol.isAcceptableOrUnknown(data['protocol']!, _protocolMeta),
      );
    }
    if (data.containsKey('related_snapshot_id')) {
      context.handle(
        _relatedSnapshotIdMeta,
        relatedSnapshotId.isAcceptableOrUnknown(
          data['related_snapshot_id']!,
          _relatedSnapshotIdMeta,
        ),
      );
    }
    if (data.containsKey('freeze_frame_json')) {
      context.handle(
        _freezeFrameJsonMeta,
        freezeFrameJson.isAcceptableOrUnknown(
          data['freeze_frame_json']!,
          _freezeFrameJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DtcSnapshotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DtcSnapshotRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      takenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}taken_at'],
      )!,
      purpose: $DtcSnapshotsTable.$converterpurpose.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}purpose'],
        )!,
      ),
      codesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}codes_json'],
      )!,
      milOn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}mil_on'],
      ),
      dtcCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dtc_count'],
      ),
      readinessJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}readiness_json'],
      ),
      protocol: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}protocol'],
      ),
      clearOutcome: $DtcSnapshotsTable.$converterclearOutcomen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}clear_outcome'],
        ),
      ),
      relatedSnapshotId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}related_snapshot_id'],
      ),
      freezeFrameJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}freeze_frame_json'],
      ),
    );
  }

  @override
  $DtcSnapshotsTable createAlias(String alias) {
    return $DtcSnapshotsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SnapshotPurpose, String, String> $converterpurpose =
      const EnumNameConverter<SnapshotPurpose>(SnapshotPurpose.values);
  static JsonTypeConverter2<ClearOutcome, String, String>
  $converterclearOutcome = const EnumNameConverter<ClearOutcome>(
    ClearOutcome.values,
  );
  static JsonTypeConverter2<ClearOutcome?, String?, String?>
  $converterclearOutcomen = JsonTypeConverter2.asNullable(
    $converterclearOutcome,
  );
}

class DtcSnapshotRow extends DataClass implements Insertable<DtcSnapshotRow> {
  final String id;
  final String vehicleId;
  final DateTime takenAt;
  final SnapshotPurpose purpose;

  /// JSON list of `{"code": "P0301", "mode": "stored"}`.
  final String codesJson;
  final bool? milOn;
  final int? dtcCount;

  /// JSON of the readiness report at the time, if one was read.
  final String? readinessJson;
  final int? protocol;
  final ClearOutcome? clearOutcome;

  /// `beforeClear` → its `afterClear` re-read; `afterClear` → its
  /// `beforeClear`.
  final String? relatedSnapshotId;

  /// JSON of the Mode 02 freeze frame — the readings the ECU stored with
  /// its first code (§5.4) — captured on a scan and before a clear erases
  /// it. Null when the car had none or did not answer. Schema v2.
  final String? freezeFrameJson;
  const DtcSnapshotRow({
    required this.id,
    required this.vehicleId,
    required this.takenAt,
    required this.purpose,
    required this.codesJson,
    this.milOn,
    this.dtcCount,
    this.readinessJson,
    this.protocol,
    this.clearOutcome,
    this.relatedSnapshotId,
    this.freezeFrameJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['taken_at'] = Variable<DateTime>(takenAt);
    {
      map['purpose'] = Variable<String>(
        $DtcSnapshotsTable.$converterpurpose.toSql(purpose),
      );
    }
    map['codes_json'] = Variable<String>(codesJson);
    if (!nullToAbsent || milOn != null) {
      map['mil_on'] = Variable<bool>(milOn);
    }
    if (!nullToAbsent || dtcCount != null) {
      map['dtc_count'] = Variable<int>(dtcCount);
    }
    if (!nullToAbsent || readinessJson != null) {
      map['readiness_json'] = Variable<String>(readinessJson);
    }
    if (!nullToAbsent || protocol != null) {
      map['protocol'] = Variable<int>(protocol);
    }
    if (!nullToAbsent || clearOutcome != null) {
      map['clear_outcome'] = Variable<String>(
        $DtcSnapshotsTable.$converterclearOutcomen.toSql(clearOutcome),
      );
    }
    if (!nullToAbsent || relatedSnapshotId != null) {
      map['related_snapshot_id'] = Variable<String>(relatedSnapshotId);
    }
    if (!nullToAbsent || freezeFrameJson != null) {
      map['freeze_frame_json'] = Variable<String>(freezeFrameJson);
    }
    return map;
  }

  DtcSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return DtcSnapshotsCompanion(
      id: Value(id),
      vehicleId: Value(vehicleId),
      takenAt: Value(takenAt),
      purpose: Value(purpose),
      codesJson: Value(codesJson),
      milOn: milOn == null && nullToAbsent
          ? const Value.absent()
          : Value(milOn),
      dtcCount: dtcCount == null && nullToAbsent
          ? const Value.absent()
          : Value(dtcCount),
      readinessJson: readinessJson == null && nullToAbsent
          ? const Value.absent()
          : Value(readinessJson),
      protocol: protocol == null && nullToAbsent
          ? const Value.absent()
          : Value(protocol),
      clearOutcome: clearOutcome == null && nullToAbsent
          ? const Value.absent()
          : Value(clearOutcome),
      relatedSnapshotId: relatedSnapshotId == null && nullToAbsent
          ? const Value.absent()
          : Value(relatedSnapshotId),
      freezeFrameJson: freezeFrameJson == null && nullToAbsent
          ? const Value.absent()
          : Value(freezeFrameJson),
    );
  }

  factory DtcSnapshotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DtcSnapshotRow(
      id: serializer.fromJson<String>(json['id']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      takenAt: serializer.fromJson<DateTime>(json['takenAt']),
      purpose: $DtcSnapshotsTable.$converterpurpose.fromJson(
        serializer.fromJson<String>(json['purpose']),
      ),
      codesJson: serializer.fromJson<String>(json['codesJson']),
      milOn: serializer.fromJson<bool?>(json['milOn']),
      dtcCount: serializer.fromJson<int?>(json['dtcCount']),
      readinessJson: serializer.fromJson<String?>(json['readinessJson']),
      protocol: serializer.fromJson<int?>(json['protocol']),
      clearOutcome: $DtcSnapshotsTable.$converterclearOutcomen.fromJson(
        serializer.fromJson<String?>(json['clearOutcome']),
      ),
      relatedSnapshotId: serializer.fromJson<String?>(
        json['relatedSnapshotId'],
      ),
      freezeFrameJson: serializer.fromJson<String?>(json['freezeFrameJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'takenAt': serializer.toJson<DateTime>(takenAt),
      'purpose': serializer.toJson<String>(
        $DtcSnapshotsTable.$converterpurpose.toJson(purpose),
      ),
      'codesJson': serializer.toJson<String>(codesJson),
      'milOn': serializer.toJson<bool?>(milOn),
      'dtcCount': serializer.toJson<int?>(dtcCount),
      'readinessJson': serializer.toJson<String?>(readinessJson),
      'protocol': serializer.toJson<int?>(protocol),
      'clearOutcome': serializer.toJson<String?>(
        $DtcSnapshotsTable.$converterclearOutcomen.toJson(clearOutcome),
      ),
      'relatedSnapshotId': serializer.toJson<String?>(relatedSnapshotId),
      'freezeFrameJson': serializer.toJson<String?>(freezeFrameJson),
    };
  }

  DtcSnapshotRow copyWith({
    String? id,
    String? vehicleId,
    DateTime? takenAt,
    SnapshotPurpose? purpose,
    String? codesJson,
    Value<bool?> milOn = const Value.absent(),
    Value<int?> dtcCount = const Value.absent(),
    Value<String?> readinessJson = const Value.absent(),
    Value<int?> protocol = const Value.absent(),
    Value<ClearOutcome?> clearOutcome = const Value.absent(),
    Value<String?> relatedSnapshotId = const Value.absent(),
    Value<String?> freezeFrameJson = const Value.absent(),
  }) => DtcSnapshotRow(
    id: id ?? this.id,
    vehicleId: vehicleId ?? this.vehicleId,
    takenAt: takenAt ?? this.takenAt,
    purpose: purpose ?? this.purpose,
    codesJson: codesJson ?? this.codesJson,
    milOn: milOn.present ? milOn.value : this.milOn,
    dtcCount: dtcCount.present ? dtcCount.value : this.dtcCount,
    readinessJson: readinessJson.present
        ? readinessJson.value
        : this.readinessJson,
    protocol: protocol.present ? protocol.value : this.protocol,
    clearOutcome: clearOutcome.present ? clearOutcome.value : this.clearOutcome,
    relatedSnapshotId: relatedSnapshotId.present
        ? relatedSnapshotId.value
        : this.relatedSnapshotId,
    freezeFrameJson: freezeFrameJson.present
        ? freezeFrameJson.value
        : this.freezeFrameJson,
  );
  DtcSnapshotRow copyWithCompanion(DtcSnapshotsCompanion data) {
    return DtcSnapshotRow(
      id: data.id.present ? data.id.value : this.id,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      takenAt: data.takenAt.present ? data.takenAt.value : this.takenAt,
      purpose: data.purpose.present ? data.purpose.value : this.purpose,
      codesJson: data.codesJson.present ? data.codesJson.value : this.codesJson,
      milOn: data.milOn.present ? data.milOn.value : this.milOn,
      dtcCount: data.dtcCount.present ? data.dtcCount.value : this.dtcCount,
      readinessJson: data.readinessJson.present
          ? data.readinessJson.value
          : this.readinessJson,
      protocol: data.protocol.present ? data.protocol.value : this.protocol,
      clearOutcome: data.clearOutcome.present
          ? data.clearOutcome.value
          : this.clearOutcome,
      relatedSnapshotId: data.relatedSnapshotId.present
          ? data.relatedSnapshotId.value
          : this.relatedSnapshotId,
      freezeFrameJson: data.freezeFrameJson.present
          ? data.freezeFrameJson.value
          : this.freezeFrameJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DtcSnapshotRow(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('takenAt: $takenAt, ')
          ..write('purpose: $purpose, ')
          ..write('codesJson: $codesJson, ')
          ..write('milOn: $milOn, ')
          ..write('dtcCount: $dtcCount, ')
          ..write('readinessJson: $readinessJson, ')
          ..write('protocol: $protocol, ')
          ..write('clearOutcome: $clearOutcome, ')
          ..write('relatedSnapshotId: $relatedSnapshotId, ')
          ..write('freezeFrameJson: $freezeFrameJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    takenAt,
    purpose,
    codesJson,
    milOn,
    dtcCount,
    readinessJson,
    protocol,
    clearOutcome,
    relatedSnapshotId,
    freezeFrameJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DtcSnapshotRow &&
          other.id == this.id &&
          other.vehicleId == this.vehicleId &&
          other.takenAt == this.takenAt &&
          other.purpose == this.purpose &&
          other.codesJson == this.codesJson &&
          other.milOn == this.milOn &&
          other.dtcCount == this.dtcCount &&
          other.readinessJson == this.readinessJson &&
          other.protocol == this.protocol &&
          other.clearOutcome == this.clearOutcome &&
          other.relatedSnapshotId == this.relatedSnapshotId &&
          other.freezeFrameJson == this.freezeFrameJson);
}

class DtcSnapshotsCompanion extends UpdateCompanion<DtcSnapshotRow> {
  final Value<String> id;
  final Value<String> vehicleId;
  final Value<DateTime> takenAt;
  final Value<SnapshotPurpose> purpose;
  final Value<String> codesJson;
  final Value<bool?> milOn;
  final Value<int?> dtcCount;
  final Value<String?> readinessJson;
  final Value<int?> protocol;
  final Value<ClearOutcome?> clearOutcome;
  final Value<String?> relatedSnapshotId;
  final Value<String?> freezeFrameJson;
  final Value<int> rowid;
  const DtcSnapshotsCompanion({
    this.id = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.takenAt = const Value.absent(),
    this.purpose = const Value.absent(),
    this.codesJson = const Value.absent(),
    this.milOn = const Value.absent(),
    this.dtcCount = const Value.absent(),
    this.readinessJson = const Value.absent(),
    this.protocol = const Value.absent(),
    this.clearOutcome = const Value.absent(),
    this.relatedSnapshotId = const Value.absent(),
    this.freezeFrameJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DtcSnapshotsCompanion.insert({
    required String id,
    required String vehicleId,
    required DateTime takenAt,
    required SnapshotPurpose purpose,
    required String codesJson,
    this.milOn = const Value.absent(),
    this.dtcCount = const Value.absent(),
    this.readinessJson = const Value.absent(),
    this.protocol = const Value.absent(),
    this.clearOutcome = const Value.absent(),
    this.relatedSnapshotId = const Value.absent(),
    this.freezeFrameJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       vehicleId = Value(vehicleId),
       takenAt = Value(takenAt),
       purpose = Value(purpose),
       codesJson = Value(codesJson);
  static Insertable<DtcSnapshotRow> custom({
    Expression<String>? id,
    Expression<String>? vehicleId,
    Expression<DateTime>? takenAt,
    Expression<String>? purpose,
    Expression<String>? codesJson,
    Expression<bool>? milOn,
    Expression<int>? dtcCount,
    Expression<String>? readinessJson,
    Expression<int>? protocol,
    Expression<String>? clearOutcome,
    Expression<String>? relatedSnapshotId,
    Expression<String>? freezeFrameJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (takenAt != null) 'taken_at': takenAt,
      if (purpose != null) 'purpose': purpose,
      if (codesJson != null) 'codes_json': codesJson,
      if (milOn != null) 'mil_on': milOn,
      if (dtcCount != null) 'dtc_count': dtcCount,
      if (readinessJson != null) 'readiness_json': readinessJson,
      if (protocol != null) 'protocol': protocol,
      if (clearOutcome != null) 'clear_outcome': clearOutcome,
      if (relatedSnapshotId != null) 'related_snapshot_id': relatedSnapshotId,
      if (freezeFrameJson != null) 'freeze_frame_json': freezeFrameJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DtcSnapshotsCompanion copyWith({
    Value<String>? id,
    Value<String>? vehicleId,
    Value<DateTime>? takenAt,
    Value<SnapshotPurpose>? purpose,
    Value<String>? codesJson,
    Value<bool?>? milOn,
    Value<int?>? dtcCount,
    Value<String?>? readinessJson,
    Value<int?>? protocol,
    Value<ClearOutcome?>? clearOutcome,
    Value<String?>? relatedSnapshotId,
    Value<String?>? freezeFrameJson,
    Value<int>? rowid,
  }) {
    return DtcSnapshotsCompanion(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      takenAt: takenAt ?? this.takenAt,
      purpose: purpose ?? this.purpose,
      codesJson: codesJson ?? this.codesJson,
      milOn: milOn ?? this.milOn,
      dtcCount: dtcCount ?? this.dtcCount,
      readinessJson: readinessJson ?? this.readinessJson,
      protocol: protocol ?? this.protocol,
      clearOutcome: clearOutcome ?? this.clearOutcome,
      relatedSnapshotId: relatedSnapshotId ?? this.relatedSnapshotId,
      freezeFrameJson: freezeFrameJson ?? this.freezeFrameJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (takenAt.present) {
      map['taken_at'] = Variable<DateTime>(takenAt.value);
    }
    if (purpose.present) {
      map['purpose'] = Variable<String>(
        $DtcSnapshotsTable.$converterpurpose.toSql(purpose.value),
      );
    }
    if (codesJson.present) {
      map['codes_json'] = Variable<String>(codesJson.value);
    }
    if (milOn.present) {
      map['mil_on'] = Variable<bool>(milOn.value);
    }
    if (dtcCount.present) {
      map['dtc_count'] = Variable<int>(dtcCount.value);
    }
    if (readinessJson.present) {
      map['readiness_json'] = Variable<String>(readinessJson.value);
    }
    if (protocol.present) {
      map['protocol'] = Variable<int>(protocol.value);
    }
    if (clearOutcome.present) {
      map['clear_outcome'] = Variable<String>(
        $DtcSnapshotsTable.$converterclearOutcomen.toSql(clearOutcome.value),
      );
    }
    if (relatedSnapshotId.present) {
      map['related_snapshot_id'] = Variable<String>(relatedSnapshotId.value);
    }
    if (freezeFrameJson.present) {
      map['freeze_frame_json'] = Variable<String>(freezeFrameJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DtcSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('takenAt: $takenAt, ')
          ..write('purpose: $purpose, ')
          ..write('codesJson: $codesJson, ')
          ..write('milOn: $milOn, ')
          ..write('dtcCount: $dtcCount, ')
          ..write('readinessJson: $readinessJson, ')
          ..write('protocol: $protocol, ')
          ..write('clearOutcome: $clearOutcome, ')
          ..write('relatedSnapshotId: $relatedSnapshotId, ')
          ..write('freezeFrameJson: $freezeFrameJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TripSessionsTable extends TripSessions
    with TableInfo<$TripSessionsTable, TripSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastOpenedAt = GeneratedColumn<DateTime>(
    'last_opened_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _distanceKmMeta = const VerificationMeta(
    'distanceKm',
  );
  @override
  late final GeneratedColumn<double> distanceKm = GeneratedColumn<double>(
    'distance_km',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avgSpeedKphMeta = const VerificationMeta(
    'avgSpeedKph',
  );
  @override
  late final GeneratedColumn<double> avgSpeedKph = GeneratedColumn<double>(
    'avg_speed_kph',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxSpeedKphMeta = const VerificationMeta(
    'maxSpeedKph',
  );
  @override
  late final GeneratedColumn<double> maxSpeedKph = GeneratedColumn<double>(
    'max_speed_kph',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sampleCountMeta = const VerificationMeta(
    'sampleCount',
  );
  @override
  late final GeneratedColumn<int> sampleCount = GeneratedColumn<int>(
    'sample_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _samplesFilePathMeta = const VerificationMeta(
    'samplesFilePath',
  );
  @override
  late final GeneratedColumn<String> samplesFilePath = GeneratedColumn<String>(
    'samples_file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileBytesMeta = const VerificationMeta(
    'fileBytes',
  );
  @override
  late final GeneratedColumn<int> fileBytes = GeneratedColumn<int>(
    'file_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _interruptedMeta = const VerificationMeta(
    'interrupted',
  );
  @override
  late final GeneratedColumn<bool> interrupted = GeneratedColumn<bool>(
    'interrupted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("interrupted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _fuelUsedLMeta = const VerificationMeta(
    'fuelUsedL',
  );
  @override
  late final GeneratedColumn<double> fuelUsedL = GeneratedColumn<double>(
    'fuel_used_l',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordedMsMeta = const VerificationMeta(
    'recordedMs',
  );
  @override
  late final GeneratedColumn<int> recordedMs = GeneratedColumn<int>(
    'recorded_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TripEnd?, String> endReason =
      GeneratedColumn<String>(
        'end_reason',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<TripEnd?>($TripSessionsTable.$converterendReasonn);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    vehicleId,
    name,
    startedAt,
    endedAt,
    lastOpenedAt,
    distanceKm,
    avgSpeedKph,
    maxSpeedKph,
    sampleCount,
    samplesFilePath,
    fileBytes,
    interrupted,
    fuelUsedL,
    recordedMs,
    endReason,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trip_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<TripSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastOpenedAtMeta);
    }
    if (data.containsKey('distance_km')) {
      context.handle(
        _distanceKmMeta,
        distanceKm.isAcceptableOrUnknown(data['distance_km']!, _distanceKmMeta),
      );
    }
    if (data.containsKey('avg_speed_kph')) {
      context.handle(
        _avgSpeedKphMeta,
        avgSpeedKph.isAcceptableOrUnknown(
          data['avg_speed_kph']!,
          _avgSpeedKphMeta,
        ),
      );
    }
    if (data.containsKey('max_speed_kph')) {
      context.handle(
        _maxSpeedKphMeta,
        maxSpeedKph.isAcceptableOrUnknown(
          data['max_speed_kph']!,
          _maxSpeedKphMeta,
        ),
      );
    }
    if (data.containsKey('sample_count')) {
      context.handle(
        _sampleCountMeta,
        sampleCount.isAcceptableOrUnknown(
          data['sample_count']!,
          _sampleCountMeta,
        ),
      );
    }
    if (data.containsKey('samples_file_path')) {
      context.handle(
        _samplesFilePathMeta,
        samplesFilePath.isAcceptableOrUnknown(
          data['samples_file_path']!,
          _samplesFilePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_samplesFilePathMeta);
    }
    if (data.containsKey('file_bytes')) {
      context.handle(
        _fileBytesMeta,
        fileBytes.isAcceptableOrUnknown(data['file_bytes']!, _fileBytesMeta),
      );
    }
    if (data.containsKey('interrupted')) {
      context.handle(
        _interruptedMeta,
        interrupted.isAcceptableOrUnknown(
          data['interrupted']!,
          _interruptedMeta,
        ),
      );
    }
    if (data.containsKey('fuel_used_l')) {
      context.handle(
        _fuelUsedLMeta,
        fuelUsedL.isAcceptableOrUnknown(data['fuel_used_l']!, _fuelUsedLMeta),
      );
    }
    if (data.containsKey('recorded_ms')) {
      context.handle(
        _recordedMsMeta,
        recordedMs.isAcceptableOrUnknown(data['recorded_ms']!, _recordedMsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TripSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TripSessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_opened_at'],
      )!,
      distanceKm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance_km'],
      ),
      avgSpeedKph: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}avg_speed_kph'],
      ),
      maxSpeedKph: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_speed_kph'],
      ),
      sampleCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sample_count'],
      )!,
      samplesFilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}samples_file_path'],
      )!,
      fileBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_bytes'],
      )!,
      interrupted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}interrupted'],
      )!,
      fuelUsedL: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fuel_used_l'],
      ),
      recordedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recorded_ms'],
      ),
      endReason: $TripSessionsTable.$converterendReasonn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}end_reason'],
        ),
      ),
    );
  }

  @override
  $TripSessionsTable createAlias(String alias) {
    return $TripSessionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TripEnd, String, String> $converterendReason =
      const EnumNameConverter<TripEnd>(TripEnd.values);
  static JsonTypeConverter2<TripEnd?, String?, String?> $converterendReasonn =
      JsonTypeConverter2.asNullable($converterendReason);
}

class TripSessionRow extends DataClass implements Insertable<TripSessionRow> {
  final String id;
  final String vehicleId;
  final String? name;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// LRU key for retention (SPEC Part 6: 30 days / 200 MB, least recently
  /// used first). Bumped whenever the trip is opened.
  final DateTime lastOpenedAt;
  final double? distanceKm;
  final double? avgSpeedKph;
  final double? maxSpeedKph;
  final int sampleCount;

  /// The samples CSV, relative to the documents directory — always exactly
  /// `trips/<id>.csv`. Never in the DB.
  final String samplesFilePath;
  final int fileBytes;

  /// The app died (or the link dropped) before the trip was ended cleanly.
  final bool interrupted;

  /// ∫ fuel rate (015E) dt, in litres — an estimate, and shown as one. Null
  /// when the car sent no fuel rate, never 0 (hard rule 5).
  final double? fuelUsedL;

  /// Recorded time: the file's end `t`, on the monotonic clock. It holds
  /// inside a segment; the gap before a Resume does not count. A trip's
  /// length is this, never `endedAt − startedAt`, except on pre-v4 rows.
  final int? recordedMs;

  /// Null while recording and on pre-v4 rows. [interrupted] is always
  /// written as `endReason.interrupted`.
  final TripEnd? endReason;
  const TripSessionRow({
    required this.id,
    required this.vehicleId,
    this.name,
    required this.startedAt,
    this.endedAt,
    required this.lastOpenedAt,
    this.distanceKm,
    this.avgSpeedKph,
    this.maxSpeedKph,
    required this.sampleCount,
    required this.samplesFilePath,
    required this.fileBytes,
    required this.interrupted,
    this.fuelUsedL,
    this.recordedMs,
    this.endReason,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['vehicle_id'] = Variable<String>(vehicleId);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['last_opened_at'] = Variable<DateTime>(lastOpenedAt);
    if (!nullToAbsent || distanceKm != null) {
      map['distance_km'] = Variable<double>(distanceKm);
    }
    if (!nullToAbsent || avgSpeedKph != null) {
      map['avg_speed_kph'] = Variable<double>(avgSpeedKph);
    }
    if (!nullToAbsent || maxSpeedKph != null) {
      map['max_speed_kph'] = Variable<double>(maxSpeedKph);
    }
    map['sample_count'] = Variable<int>(sampleCount);
    map['samples_file_path'] = Variable<String>(samplesFilePath);
    map['file_bytes'] = Variable<int>(fileBytes);
    map['interrupted'] = Variable<bool>(interrupted);
    if (!nullToAbsent || fuelUsedL != null) {
      map['fuel_used_l'] = Variable<double>(fuelUsedL);
    }
    if (!nullToAbsent || recordedMs != null) {
      map['recorded_ms'] = Variable<int>(recordedMs);
    }
    if (!nullToAbsent || endReason != null) {
      map['end_reason'] = Variable<String>(
        $TripSessionsTable.$converterendReasonn.toSql(endReason),
      );
    }
    return map;
  }

  TripSessionsCompanion toCompanion(bool nullToAbsent) {
    return TripSessionsCompanion(
      id: Value(id),
      vehicleId: Value(vehicleId),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      lastOpenedAt: Value(lastOpenedAt),
      distanceKm: distanceKm == null && nullToAbsent
          ? const Value.absent()
          : Value(distanceKm),
      avgSpeedKph: avgSpeedKph == null && nullToAbsent
          ? const Value.absent()
          : Value(avgSpeedKph),
      maxSpeedKph: maxSpeedKph == null && nullToAbsent
          ? const Value.absent()
          : Value(maxSpeedKph),
      sampleCount: Value(sampleCount),
      samplesFilePath: Value(samplesFilePath),
      fileBytes: Value(fileBytes),
      interrupted: Value(interrupted),
      fuelUsedL: fuelUsedL == null && nullToAbsent
          ? const Value.absent()
          : Value(fuelUsedL),
      recordedMs: recordedMs == null && nullToAbsent
          ? const Value.absent()
          : Value(recordedMs),
      endReason: endReason == null && nullToAbsent
          ? const Value.absent()
          : Value(endReason),
    );
  }

  factory TripSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TripSessionRow(
      id: serializer.fromJson<String>(json['id']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      name: serializer.fromJson<String?>(json['name']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      lastOpenedAt: serializer.fromJson<DateTime>(json['lastOpenedAt']),
      distanceKm: serializer.fromJson<double?>(json['distanceKm']),
      avgSpeedKph: serializer.fromJson<double?>(json['avgSpeedKph']),
      maxSpeedKph: serializer.fromJson<double?>(json['maxSpeedKph']),
      sampleCount: serializer.fromJson<int>(json['sampleCount']),
      samplesFilePath: serializer.fromJson<String>(json['samplesFilePath']),
      fileBytes: serializer.fromJson<int>(json['fileBytes']),
      interrupted: serializer.fromJson<bool>(json['interrupted']),
      fuelUsedL: serializer.fromJson<double?>(json['fuelUsedL']),
      recordedMs: serializer.fromJson<int?>(json['recordedMs']),
      endReason: $TripSessionsTable.$converterendReasonn.fromJson(
        serializer.fromJson<String?>(json['endReason']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'name': serializer.toJson<String?>(name),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'lastOpenedAt': serializer.toJson<DateTime>(lastOpenedAt),
      'distanceKm': serializer.toJson<double?>(distanceKm),
      'avgSpeedKph': serializer.toJson<double?>(avgSpeedKph),
      'maxSpeedKph': serializer.toJson<double?>(maxSpeedKph),
      'sampleCount': serializer.toJson<int>(sampleCount),
      'samplesFilePath': serializer.toJson<String>(samplesFilePath),
      'fileBytes': serializer.toJson<int>(fileBytes),
      'interrupted': serializer.toJson<bool>(interrupted),
      'fuelUsedL': serializer.toJson<double?>(fuelUsedL),
      'recordedMs': serializer.toJson<int?>(recordedMs),
      'endReason': serializer.toJson<String?>(
        $TripSessionsTable.$converterendReasonn.toJson(endReason),
      ),
    };
  }

  TripSessionRow copyWith({
    String? id,
    String? vehicleId,
    Value<String?> name = const Value.absent(),
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    DateTime? lastOpenedAt,
    Value<double?> distanceKm = const Value.absent(),
    Value<double?> avgSpeedKph = const Value.absent(),
    Value<double?> maxSpeedKph = const Value.absent(),
    int? sampleCount,
    String? samplesFilePath,
    int? fileBytes,
    bool? interrupted,
    Value<double?> fuelUsedL = const Value.absent(),
    Value<int?> recordedMs = const Value.absent(),
    Value<TripEnd?> endReason = const Value.absent(),
  }) => TripSessionRow(
    id: id ?? this.id,
    vehicleId: vehicleId ?? this.vehicleId,
    name: name.present ? name.value : this.name,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    distanceKm: distanceKm.present ? distanceKm.value : this.distanceKm,
    avgSpeedKph: avgSpeedKph.present ? avgSpeedKph.value : this.avgSpeedKph,
    maxSpeedKph: maxSpeedKph.present ? maxSpeedKph.value : this.maxSpeedKph,
    sampleCount: sampleCount ?? this.sampleCount,
    samplesFilePath: samplesFilePath ?? this.samplesFilePath,
    fileBytes: fileBytes ?? this.fileBytes,
    interrupted: interrupted ?? this.interrupted,
    fuelUsedL: fuelUsedL.present ? fuelUsedL.value : this.fuelUsedL,
    recordedMs: recordedMs.present ? recordedMs.value : this.recordedMs,
    endReason: endReason.present ? endReason.value : this.endReason,
  );
  TripSessionRow copyWithCompanion(TripSessionsCompanion data) {
    return TripSessionRow(
      id: data.id.present ? data.id.value : this.id,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      name: data.name.present ? data.name.value : this.name,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
      distanceKm: data.distanceKm.present
          ? data.distanceKm.value
          : this.distanceKm,
      avgSpeedKph: data.avgSpeedKph.present
          ? data.avgSpeedKph.value
          : this.avgSpeedKph,
      maxSpeedKph: data.maxSpeedKph.present
          ? data.maxSpeedKph.value
          : this.maxSpeedKph,
      sampleCount: data.sampleCount.present
          ? data.sampleCount.value
          : this.sampleCount,
      samplesFilePath: data.samplesFilePath.present
          ? data.samplesFilePath.value
          : this.samplesFilePath,
      fileBytes: data.fileBytes.present ? data.fileBytes.value : this.fileBytes,
      interrupted: data.interrupted.present
          ? data.interrupted.value
          : this.interrupted,
      fuelUsedL: data.fuelUsedL.present ? data.fuelUsedL.value : this.fuelUsedL,
      recordedMs: data.recordedMs.present
          ? data.recordedMs.value
          : this.recordedMs,
      endReason: data.endReason.present ? data.endReason.value : this.endReason,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TripSessionRow(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('name: $name, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('distanceKm: $distanceKm, ')
          ..write('avgSpeedKph: $avgSpeedKph, ')
          ..write('maxSpeedKph: $maxSpeedKph, ')
          ..write('sampleCount: $sampleCount, ')
          ..write('samplesFilePath: $samplesFilePath, ')
          ..write('fileBytes: $fileBytes, ')
          ..write('interrupted: $interrupted, ')
          ..write('fuelUsedL: $fuelUsedL, ')
          ..write('recordedMs: $recordedMs, ')
          ..write('endReason: $endReason')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    name,
    startedAt,
    endedAt,
    lastOpenedAt,
    distanceKm,
    avgSpeedKph,
    maxSpeedKph,
    sampleCount,
    samplesFilePath,
    fileBytes,
    interrupted,
    fuelUsedL,
    recordedMs,
    endReason,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TripSessionRow &&
          other.id == this.id &&
          other.vehicleId == this.vehicleId &&
          other.name == this.name &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.lastOpenedAt == this.lastOpenedAt &&
          other.distanceKm == this.distanceKm &&
          other.avgSpeedKph == this.avgSpeedKph &&
          other.maxSpeedKph == this.maxSpeedKph &&
          other.sampleCount == this.sampleCount &&
          other.samplesFilePath == this.samplesFilePath &&
          other.fileBytes == this.fileBytes &&
          other.interrupted == this.interrupted &&
          other.fuelUsedL == this.fuelUsedL &&
          other.recordedMs == this.recordedMs &&
          other.endReason == this.endReason);
}

class TripSessionsCompanion extends UpdateCompanion<TripSessionRow> {
  final Value<String> id;
  final Value<String> vehicleId;
  final Value<String?> name;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<DateTime> lastOpenedAt;
  final Value<double?> distanceKm;
  final Value<double?> avgSpeedKph;
  final Value<double?> maxSpeedKph;
  final Value<int> sampleCount;
  final Value<String> samplesFilePath;
  final Value<int> fileBytes;
  final Value<bool> interrupted;
  final Value<double?> fuelUsedL;
  final Value<int?> recordedMs;
  final Value<TripEnd?> endReason;
  final Value<int> rowid;
  const TripSessionsCompanion({
    this.id = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.name = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.distanceKm = const Value.absent(),
    this.avgSpeedKph = const Value.absent(),
    this.maxSpeedKph = const Value.absent(),
    this.sampleCount = const Value.absent(),
    this.samplesFilePath = const Value.absent(),
    this.fileBytes = const Value.absent(),
    this.interrupted = const Value.absent(),
    this.fuelUsedL = const Value.absent(),
    this.recordedMs = const Value.absent(),
    this.endReason = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripSessionsCompanion.insert({
    required String id,
    required String vehicleId,
    this.name = const Value.absent(),
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    required DateTime lastOpenedAt,
    this.distanceKm = const Value.absent(),
    this.avgSpeedKph = const Value.absent(),
    this.maxSpeedKph = const Value.absent(),
    this.sampleCount = const Value.absent(),
    required String samplesFilePath,
    this.fileBytes = const Value.absent(),
    this.interrupted = const Value.absent(),
    this.fuelUsedL = const Value.absent(),
    this.recordedMs = const Value.absent(),
    this.endReason = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       vehicleId = Value(vehicleId),
       startedAt = Value(startedAt),
       lastOpenedAt = Value(lastOpenedAt),
       samplesFilePath = Value(samplesFilePath);
  static Insertable<TripSessionRow> custom({
    Expression<String>? id,
    Expression<String>? vehicleId,
    Expression<String>? name,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<DateTime>? lastOpenedAt,
    Expression<double>? distanceKm,
    Expression<double>? avgSpeedKph,
    Expression<double>? maxSpeedKph,
    Expression<int>? sampleCount,
    Expression<String>? samplesFilePath,
    Expression<int>? fileBytes,
    Expression<bool>? interrupted,
    Expression<double>? fuelUsedL,
    Expression<int>? recordedMs,
    Expression<String>? endReason,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (name != null) 'name': name,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (avgSpeedKph != null) 'avg_speed_kph': avgSpeedKph,
      if (maxSpeedKph != null) 'max_speed_kph': maxSpeedKph,
      if (sampleCount != null) 'sample_count': sampleCount,
      if (samplesFilePath != null) 'samples_file_path': samplesFilePath,
      if (fileBytes != null) 'file_bytes': fileBytes,
      if (interrupted != null) 'interrupted': interrupted,
      if (fuelUsedL != null) 'fuel_used_l': fuelUsedL,
      if (recordedMs != null) 'recorded_ms': recordedMs,
      if (endReason != null) 'end_reason': endReason,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? vehicleId,
    Value<String?>? name,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<DateTime>? lastOpenedAt,
    Value<double?>? distanceKm,
    Value<double?>? avgSpeedKph,
    Value<double?>? maxSpeedKph,
    Value<int>? sampleCount,
    Value<String>? samplesFilePath,
    Value<int>? fileBytes,
    Value<bool>? interrupted,
    Value<double?>? fuelUsedL,
    Value<int?>? recordedMs,
    Value<TripEnd?>? endReason,
    Value<int>? rowid,
  }) {
    return TripSessionsCompanion(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      name: name ?? this.name,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      distanceKm: distanceKm ?? this.distanceKm,
      avgSpeedKph: avgSpeedKph ?? this.avgSpeedKph,
      maxSpeedKph: maxSpeedKph ?? this.maxSpeedKph,
      sampleCount: sampleCount ?? this.sampleCount,
      samplesFilePath: samplesFilePath ?? this.samplesFilePath,
      fileBytes: fileBytes ?? this.fileBytes,
      interrupted: interrupted ?? this.interrupted,
      fuelUsedL: fuelUsedL ?? this.fuelUsedL,
      recordedMs: recordedMs ?? this.recordedMs,
      endReason: endReason ?? this.endReason,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt.value);
    }
    if (distanceKm.present) {
      map['distance_km'] = Variable<double>(distanceKm.value);
    }
    if (avgSpeedKph.present) {
      map['avg_speed_kph'] = Variable<double>(avgSpeedKph.value);
    }
    if (maxSpeedKph.present) {
      map['max_speed_kph'] = Variable<double>(maxSpeedKph.value);
    }
    if (sampleCount.present) {
      map['sample_count'] = Variable<int>(sampleCount.value);
    }
    if (samplesFilePath.present) {
      map['samples_file_path'] = Variable<String>(samplesFilePath.value);
    }
    if (fileBytes.present) {
      map['file_bytes'] = Variable<int>(fileBytes.value);
    }
    if (interrupted.present) {
      map['interrupted'] = Variable<bool>(interrupted.value);
    }
    if (fuelUsedL.present) {
      map['fuel_used_l'] = Variable<double>(fuelUsedL.value);
    }
    if (recordedMs.present) {
      map['recorded_ms'] = Variable<int>(recordedMs.value);
    }
    if (endReason.present) {
      map['end_reason'] = Variable<String>(
        $TripSessionsTable.$converterendReasonn.toSql(endReason.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripSessionsCompanion(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('name: $name, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('distanceKm: $distanceKm, ')
          ..write('avgSpeedKph: $avgSpeedKph, ')
          ..write('maxSpeedKph: $maxSpeedKph, ')
          ..write('sampleCount: $sampleCount, ')
          ..write('samplesFilePath: $samplesFilePath, ')
          ..write('fileBytes: $fileBytes, ')
          ..write('interrupted: $interrupted, ')
          ..write('fuelUsedL: $fuelUsedL, ')
          ..write('recordedMs: $recordedMs, ')
          ..write('endReason: $endReason, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DashboardLayoutsTable extends DashboardLayouts
    with TableInfo<$DashboardLayoutsTable, DashboardLayoutRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DashboardLayoutsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta(
    'vehicleId',
  );
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES vehicles (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    check: () => ComparableExpr(name.length).isBetweenValues(1, 40),
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 40,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tilesJsonMeta = const VerificationMeta(
    'tilesJson',
  );
  @override
  late final GeneratedColumn<String> tilesJson = GeneratedColumn<String>(
    'tiles_json',
    aliasedName,
    false,
    check: () => const CustomExpression<bool>(
      "CASE WHEN json_valid(tiles_json) "
      "THEN json_type(tiles_json) = 'array' "
      "AND json_array_length(tiles_json) BETWEEN 1 AND 64 ELSE 0 END",
    ),
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
  static const VerificationMeta _selectedAtMeta = const VerificationMeta(
    'selectedAt',
  );
  @override
  late final GeneratedColumn<DateTime> selectedAt = GeneratedColumn<DateTime>(
    'selected_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    vehicleId,
    name,
    tilesJson,
    createdAt,
    selectedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dashboard_layouts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DashboardLayoutRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('vehicle_id')) {
      context.handle(
        _vehicleIdMeta,
        vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('tiles_json')) {
      context.handle(
        _tilesJsonMeta,
        tilesJson.isAcceptableOrUnknown(data['tiles_json']!, _tilesJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_tilesJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('selected_at')) {
      context.handle(
        _selectedAtMeta,
        selectedAt.isAcceptableOrUnknown(data['selected_at']!, _selectedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_selectedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DashboardLayoutRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DashboardLayoutRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      tilesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tiles_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      selectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}selected_at'],
      )!,
    );
  }

  @override
  $DashboardLayoutsTable createAlias(String alias) {
    return $DashboardLayoutsTable(attachedDatabase, alias);
  }
}

class DashboardLayoutRow extends DataClass
    implements Insertable<DashboardLayoutRow> {
  final String id;
  final String vehicleId;
  final String name;
  final String tilesJson;
  final DateTime createdAt;
  final DateTime selectedAt;
  const DashboardLayoutRow({
    required this.id,
    required this.vehicleId,
    required this.name,
    required this.tilesJson,
    required this.createdAt,
    required this.selectedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['name'] = Variable<String>(name);
    map['tiles_json'] = Variable<String>(tilesJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['selected_at'] = Variable<DateTime>(selectedAt);
    return map;
  }

  DashboardLayoutsCompanion toCompanion(bool nullToAbsent) {
    return DashboardLayoutsCompanion(
      id: Value(id),
      vehicleId: Value(vehicleId),
      name: Value(name),
      tilesJson: Value(tilesJson),
      createdAt: Value(createdAt),
      selectedAt: Value(selectedAt),
    );
  }

  factory DashboardLayoutRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DashboardLayoutRow(
      id: serializer.fromJson<String>(json['id']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      name: serializer.fromJson<String>(json['name']),
      tilesJson: serializer.fromJson<String>(json['tilesJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      selectedAt: serializer.fromJson<DateTime>(json['selectedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'vehicleId': serializer.toJson<String>(vehicleId),
      'name': serializer.toJson<String>(name),
      'tilesJson': serializer.toJson<String>(tilesJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'selectedAt': serializer.toJson<DateTime>(selectedAt),
    };
  }

  DashboardLayoutRow copyWith({
    String? id,
    String? vehicleId,
    String? name,
    String? tilesJson,
    DateTime? createdAt,
    DateTime? selectedAt,
  }) => DashboardLayoutRow(
    id: id ?? this.id,
    vehicleId: vehicleId ?? this.vehicleId,
    name: name ?? this.name,
    tilesJson: tilesJson ?? this.tilesJson,
    createdAt: createdAt ?? this.createdAt,
    selectedAt: selectedAt ?? this.selectedAt,
  );
  DashboardLayoutRow copyWithCompanion(DashboardLayoutsCompanion data) {
    return DashboardLayoutRow(
      id: data.id.present ? data.id.value : this.id,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      name: data.name.present ? data.name.value : this.name,
      tilesJson: data.tilesJson.present ? data.tilesJson.value : this.tilesJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      selectedAt: data.selectedAt.present
          ? data.selectedAt.value
          : this.selectedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DashboardLayoutRow(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('name: $name, ')
          ..write('tilesJson: $tilesJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('selectedAt: $selectedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, vehicleId, name, tilesJson, createdAt, selectedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DashboardLayoutRow &&
          other.id == this.id &&
          other.vehicleId == this.vehicleId &&
          other.name == this.name &&
          other.tilesJson == this.tilesJson &&
          other.createdAt == this.createdAt &&
          other.selectedAt == this.selectedAt);
}

class DashboardLayoutsCompanion extends UpdateCompanion<DashboardLayoutRow> {
  final Value<String> id;
  final Value<String> vehicleId;
  final Value<String> name;
  final Value<String> tilesJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> selectedAt;
  final Value<int> rowid;
  const DashboardLayoutsCompanion({
    this.id = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.name = const Value.absent(),
    this.tilesJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.selectedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DashboardLayoutsCompanion.insert({
    required String id,
    required String vehicleId,
    required String name,
    required String tilesJson,
    required DateTime createdAt,
    required DateTime selectedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       vehicleId = Value(vehicleId),
       name = Value(name),
       tilesJson = Value(tilesJson),
       createdAt = Value(createdAt),
       selectedAt = Value(selectedAt);
  static Insertable<DashboardLayoutRow> custom({
    Expression<String>? id,
    Expression<String>? vehicleId,
    Expression<String>? name,
    Expression<String>? tilesJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? selectedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (name != null) 'name': name,
      if (tilesJson != null) 'tiles_json': tilesJson,
      if (createdAt != null) 'created_at': createdAt,
      if (selectedAt != null) 'selected_at': selectedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DashboardLayoutsCompanion copyWith({
    Value<String>? id,
    Value<String>? vehicleId,
    Value<String>? name,
    Value<String>? tilesJson,
    Value<DateTime>? createdAt,
    Value<DateTime>? selectedAt,
    Value<int>? rowid,
  }) {
    return DashboardLayoutsCompanion(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      name: name ?? this.name,
      tilesJson: tilesJson ?? this.tilesJson,
      createdAt: createdAt ?? this.createdAt,
      selectedAt: selectedAt ?? this.selectedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (tilesJson.present) {
      map['tiles_json'] = Variable<String>(tilesJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (selectedAt.present) {
      map['selected_at'] = Variable<DateTime>(selectedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DashboardLayoutsCompanion(')
          ..write('id: $id, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('name: $name, ')
          ..write('tilesJson: $tilesJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('selectedAt: $selectedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $VehiclesTable vehicles = $VehiclesTable(this);
  late final $ServiceRecordsTable serviceRecords = $ServiceRecordsTable(this);
  late final $RemindersTable reminders = $RemindersTable(this);
  late final $FuelEntriesTable fuelEntries = $FuelEntriesTable(this);
  late final $DtcSnapshotsTable dtcSnapshots = $DtcSnapshotsTable(this);
  late final $TripSessionsTable tripSessions = $TripSessionsTable(this);
  late final $DashboardLayoutsTable dashboardLayouts = $DashboardLayoutsTable(
    this,
  );
  late final Index idxServiceVehicleDate = Index(
    'idx_service_vehicle_date',
    'CREATE INDEX idx_service_vehicle_date ON service_records (vehicle_id, date)',
  );
  late final Index idxReminderVehicle = Index(
    'idx_reminder_vehicle',
    'CREATE INDEX idx_reminder_vehicle ON reminders (vehicle_id)',
  );
  late final Index idxFuelVehicleDate = Index(
    'idx_fuel_vehicle_date',
    'CREATE INDEX idx_fuel_vehicle_date ON fuel_entries (vehicle_id, date)',
  );
  late final Index idxSnapshotVehicleTaken = Index(
    'idx_snapshot_vehicle_taken',
    'CREATE INDEX idx_snapshot_vehicle_taken ON dtc_snapshots (vehicle_id, taken_at)',
  );
  late final Index idxTripVehicleStarted = Index(
    'idx_trip_vehicle_started',
    'CREATE INDEX idx_trip_vehicle_started ON trip_sessions (vehicle_id, started_at)',
  );
  late final Index idxTripOneOpen = Index(
    'idx_trip_one_open',
    'CREATE UNIQUE INDEX idx_trip_one_open ON trip_sessions ((ended_at IS NULL)) WHERE ended_at IS NULL',
  );
  late final Index idxLayoutVehicle = Index(
    'idx_layout_vehicle',
    'CREATE INDEX idx_layout_vehicle ON dashboard_layouts (vehicle_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    vehicles,
    serviceRecords,
    reminders,
    fuelEntries,
    dtcSnapshots,
    tripSessions,
    dashboardLayouts,
    idxServiceVehicleDate,
    idxReminderVehicle,
    idxFuelVehicleDate,
    idxSnapshotVehicleTaken,
    idxTripVehicleStarted,
    idxTripOneOpen,
    idxLayoutVehicle,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'vehicles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('service_records', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'vehicles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reminders', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'vehicles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('fuel_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'vehicles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('dtc_snapshots', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'vehicles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('trip_sessions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'vehicles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('dashboard_layouts', kind: UpdateKind.delete)],
    ),
  ]);
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$VehiclesTableCreateCompanionBuilder = VehiclesCompanion Function({
  required String id,
  required String nickname,
  Value<String?> vin,
  Value<bool> vinUnverified,
  Value<String> make,
  Value<String> model,
  Value<String> trim,
  Value<int?> year,
  required VehicleFuel fuelType,
  Value<double?> odometerKm,
  Value<DateTime?> odometerUpdatedAt,
  Value<String?> plate,
  Value<String?> photoPath,
  Value<int?> cachedProtocol,
  Value<String?> supportedPidsJson,
  Value<bool> supportsBatching,
  Value<bool> isPrimary,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$VehiclesTableUpdateCompanionBuilder = VehiclesCompanion Function({
  Value<String> id,
  Value<String> nickname,
  Value<String?> vin,
  Value<bool> vinUnverified,
  Value<String> make,
  Value<String> model,
  Value<String> trim,
  Value<int?> year,
  Value<VehicleFuel> fuelType,
  Value<double?> odometerKm,
  Value<DateTime?> odometerUpdatedAt,
  Value<String?> plate,
  Value<String?> photoPath,
  Value<int?> cachedProtocol,
  Value<String?> supportedPidsJson,
  Value<bool> supportsBatching,
  Value<bool> isPrimary,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$VehiclesTableReferences
    extends BaseReferences<_$AppDatabase, $VehiclesTable, VehicleRow> {
  $$VehiclesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ServiceRecordsTable, List<ServiceRecordRow>>
  _serviceRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.serviceRecords,
    aliasName: 'vehicles__id__service_records__vehicle_id',
  );

  $$ServiceRecordsTableProcessedTableManager get serviceRecordsRefs {
    final manager = $$ServiceRecordsTableTableManager(
      $_db,
      $_db.serviceRecords,
    ).filter((f) => f.vehicleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_serviceRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RemindersTable, List<ReminderRow>>
  _remindersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.reminders,
    aliasName: 'vehicles__id__reminders__vehicle_id',
  );

  $$RemindersTableProcessedTableManager get remindersRefs {
    final manager = $$RemindersTableTableManager(
      $_db,
      $_db.reminders,
    ).filter((f) => f.vehicleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_remindersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FuelEntriesTable, List<FuelEntryRow>>
  _fuelEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.fuelEntries,
    aliasName: 'vehicles__id__fuel_entries__vehicle_id',
  );

  $$FuelEntriesTableProcessedTableManager get fuelEntriesRefs {
    final manager = $$FuelEntriesTableTableManager(
      $_db,
      $_db.fuelEntries,
    ).filter((f) => f.vehicleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_fuelEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DtcSnapshotsTable, List<DtcSnapshotRow>>
  _dtcSnapshotsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dtcSnapshots,
    aliasName: 'vehicles__id__dtc_snapshots__vehicle_id',
  );

  $$DtcSnapshotsTableProcessedTableManager get dtcSnapshotsRefs {
    final manager = $$DtcSnapshotsTableTableManager(
      $_db,
      $_db.dtcSnapshots,
    ).filter((f) => f.vehicleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_dtcSnapshotsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TripSessionsTable, List<TripSessionRow>>
  _tripSessionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.tripSessions,
    aliasName: 'vehicles__id__trip_sessions__vehicle_id',
  );

  $$TripSessionsTableProcessedTableManager get tripSessionsRefs {
    final manager = $$TripSessionsTableTableManager(
      $_db,
      $_db.tripSessions,
    ).filter((f) => f.vehicleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tripSessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DashboardLayoutsTable, List<DashboardLayoutRow>>
  _dashboardLayoutsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dashboardLayouts,
    aliasName: 'vehicles__id__dashboard_layouts__vehicle_id',
  );

  $$DashboardLayoutsTableProcessedTableManager get dashboardLayoutsRefs {
    final manager = $$DashboardLayoutsTableTableManager(
      $_db,
      $_db.dashboardLayouts,
    ).filter((f) => f.vehicleId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _dashboardLayoutsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$VehiclesTableFilterComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vin => $composableBuilder(
    column: $table.vin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get vinUnverified => $composableBuilder(
    column: $table.vinUnverified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get make => $composableBuilder(
    column: $table.make,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trim => $composableBuilder(
    column: $table.trim,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<VehicleFuel, VehicleFuel, String>
  get fuelType => $composableBuilder(
    column: $table.fuelType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get odometerKm => $composableBuilder(
    column: $table.odometerKm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get odometerUpdatedAt => $composableBuilder(
    column: $table.odometerUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get plate => $composableBuilder(
    column: $table.plate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedProtocol => $composableBuilder(
    column: $table.cachedProtocol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supportedPidsJson => $composableBuilder(
    column: $table.supportedPidsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get supportsBatching => $composableBuilder(
    column: $table.supportsBatching,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> serviceRecordsRefs(
    Expression<bool> Function($$ServiceRecordsTableFilterComposer f) f,
  ) {
    final $$ServiceRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.serviceRecords,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServiceRecordsTableFilterComposer(
            $db: $db,
            $table: $db.serviceRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> remindersRefs(
    Expression<bool> Function($$RemindersTableFilterComposer f) f,
  ) {
    final $$RemindersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableFilterComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> fuelEntriesRefs(
    Expression<bool> Function($$FuelEntriesTableFilterComposer f) f,
  ) {
    final $$FuelEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.fuelEntries,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FuelEntriesTableFilterComposer(
            $db: $db,
            $table: $db.fuelEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dtcSnapshotsRefs(
    Expression<bool> Function($$DtcSnapshotsTableFilterComposer f) f,
  ) {
    final $$DtcSnapshotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dtcSnapshots,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DtcSnapshotsTableFilterComposer(
            $db: $db,
            $table: $db.dtcSnapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> tripSessionsRefs(
    Expression<bool> Function($$TripSessionsTableFilterComposer f) f,
  ) {
    final $$TripSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripSessions,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripSessionsTableFilterComposer(
            $db: $db,
            $table: $db.tripSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dashboardLayoutsRefs(
    Expression<bool> Function($$DashboardLayoutsTableFilterComposer f) f,
  ) {
    final $$DashboardLayoutsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dashboardLayouts,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DashboardLayoutsTableFilterComposer(
            $db: $db,
            $table: $db.dashboardLayouts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VehiclesTableOrderingComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vin => $composableBuilder(
    column: $table.vin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get vinUnverified => $composableBuilder(
    column: $table.vinUnverified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get make => $composableBuilder(
    column: $table.make,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trim => $composableBuilder(
    column: $table.trim,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fuelType => $composableBuilder(
    column: $table.fuelType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get odometerKm => $composableBuilder(
    column: $table.odometerKm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get odometerUpdatedAt => $composableBuilder(
    column: $table.odometerUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plate => $composableBuilder(
    column: $table.plate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedProtocol => $composableBuilder(
    column: $table.cachedProtocol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supportedPidsJson => $composableBuilder(
    column: $table.supportedPidsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get supportsBatching => $composableBuilder(
    column: $table.supportsBatching,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VehiclesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nickname =>
      $composableBuilder(column: $table.nickname, builder: (column) => column);

  GeneratedColumn<String> get vin =>
      $composableBuilder(column: $table.vin, builder: (column) => column);

  GeneratedColumn<bool> get vinUnverified => $composableBuilder(
    column: $table.vinUnverified,
    builder: (column) => column,
  );

  GeneratedColumn<String> get make =>
      $composableBuilder(column: $table.make, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get trim =>
      $composableBuilder(column: $table.trim, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumnWithTypeConverter<VehicleFuel, String> get fuelType =>
      $composableBuilder(column: $table.fuelType, builder: (column) => column);

  GeneratedColumn<double> get odometerKm => $composableBuilder(
    column: $table.odometerKm,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get odometerUpdatedAt => $composableBuilder(
    column: $table.odometerUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get plate =>
      $composableBuilder(column: $table.plate, builder: (column) => column);

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  GeneratedColumn<int> get cachedProtocol => $composableBuilder(
    column: $table.cachedProtocol,
    builder: (column) => column,
  );

  GeneratedColumn<String> get supportedPidsJson => $composableBuilder(
    column: $table.supportedPidsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get supportsBatching => $composableBuilder(
    column: $table.supportsBatching,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPrimary =>
      $composableBuilder(column: $table.isPrimary, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> serviceRecordsRefs<T extends Object>(
    Expression<T> Function($$ServiceRecordsTableAnnotationComposer a) f,
  ) {
    final $$ServiceRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.serviceRecords,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ServiceRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.serviceRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> remindersRefs<T extends Object>(
    Expression<T> Function($$RemindersTableAnnotationComposer a) f,
  ) {
    final $$RemindersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableAnnotationComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> fuelEntriesRefs<T extends Object>(
    Expression<T> Function($$FuelEntriesTableAnnotationComposer a) f,
  ) {
    final $$FuelEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.fuelEntries,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FuelEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.fuelEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> dtcSnapshotsRefs<T extends Object>(
    Expression<T> Function($$DtcSnapshotsTableAnnotationComposer a) f,
  ) {
    final $$DtcSnapshotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dtcSnapshots,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DtcSnapshotsTableAnnotationComposer(
            $db: $db,
            $table: $db.dtcSnapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> tripSessionsRefs<T extends Object>(
    Expression<T> Function($$TripSessionsTableAnnotationComposer a) f,
  ) {
    final $$TripSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tripSessions,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TripSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.tripSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> dashboardLayoutsRefs<T extends Object>(
    Expression<T> Function($$DashboardLayoutsTableAnnotationComposer a) f,
  ) {
    final $$DashboardLayoutsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dashboardLayouts,
      getReferencedColumn: (t) => t.vehicleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DashboardLayoutsTableAnnotationComposer(
            $db: $db,
            $table: $db.dashboardLayouts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$VehiclesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VehiclesTable,
          VehicleRow,
          $$VehiclesTableFilterComposer,
          $$VehiclesTableOrderingComposer,
          $$VehiclesTableAnnotationComposer,
          $$VehiclesTableCreateCompanionBuilder,
          $$VehiclesTableUpdateCompanionBuilder,
          (VehicleRow, $$VehiclesTableReferences),
          VehicleRow,
          PrefetchHooks Function({
            bool serviceRecordsRefs,
            bool remindersRefs,
            bool fuelEntriesRefs,
            bool dtcSnapshotsRefs,
            bool tripSessionsRefs,
            bool dashboardLayoutsRefs,
          })
        > {
  $$VehiclesTableTableManager(_$AppDatabase db, $VehiclesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VehiclesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VehiclesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VehiclesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nickname = const Value.absent(),
                Value<String?> vin = const Value.absent(),
                Value<bool> vinUnverified = const Value.absent(),
                Value<String> make = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<String> trim = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<VehicleFuel> fuelType = const Value.absent(),
                Value<double?> odometerKm = const Value.absent(),
                Value<DateTime?> odometerUpdatedAt = const Value.absent(),
                Value<String?> plate = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<int?> cachedProtocol = const Value.absent(),
                Value<String?> supportedPidsJson = const Value.absent(),
                Value<bool> supportsBatching = const Value.absent(),
                Value<bool> isPrimary = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VehiclesCompanion(
                id: id,
                nickname: nickname,
                vin: vin,
                vinUnverified: vinUnverified,
                make: make,
                model: model,
                trim: trim,
                year: year,
                fuelType: fuelType,
                odometerKm: odometerKm,
                odometerUpdatedAt: odometerUpdatedAt,
                plate: plate,
                photoPath: photoPath,
                cachedProtocol: cachedProtocol,
                supportedPidsJson: supportedPidsJson,
                supportsBatching: supportsBatching,
                isPrimary: isPrimary,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nickname,
                Value<String?> vin = const Value.absent(),
                Value<bool> vinUnverified = const Value.absent(),
                Value<String> make = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<String> trim = const Value.absent(),
                Value<int?> year = const Value.absent(),
                required VehicleFuel fuelType,
                Value<double?> odometerKm = const Value.absent(),
                Value<DateTime?> odometerUpdatedAt = const Value.absent(),
                Value<String?> plate = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<int?> cachedProtocol = const Value.absent(),
                Value<String?> supportedPidsJson = const Value.absent(),
                Value<bool> supportsBatching = const Value.absent(),
                Value<bool> isPrimary = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => VehiclesCompanion.insert(
                id: id,
                nickname: nickname,
                vin: vin,
                vinUnverified: vinUnverified,
                make: make,
                model: model,
                trim: trim,
                year: year,
                fuelType: fuelType,
                odometerKm: odometerKm,
                odometerUpdatedAt: odometerUpdatedAt,
                plate: plate,
                photoPath: photoPath,
                cachedProtocol: cachedProtocol,
                supportedPidsJson: supportedPidsJson,
                supportsBatching: supportsBatching,
                isPrimary: isPrimary,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VehiclesTable, VehicleRow>(table),
                  $$VehiclesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                serviceRecordsRefs = false,
                remindersRefs = false,
                fuelEntriesRefs = false,
                dtcSnapshotsRefs = false,
                tripSessionsRefs = false,
                dashboardLayoutsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (serviceRecordsRefs) db.serviceRecords,
                    if (remindersRefs) db.reminders,
                    if (fuelEntriesRefs) db.fuelEntries,
                    if (dtcSnapshotsRefs) db.dtcSnapshots,
                    if (tripSessionsRefs) db.tripSessions,
                    if (dashboardLayoutsRefs) db.dashboardLayouts,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (serviceRecordsRefs)
                        await $_getPrefetchedData<
                          VehicleRow,
                          $VehiclesTable,
                          ServiceRecordRow
                        >(
                          currentTable: table,
                          referencedTable: $$VehiclesTableReferences
                              ._serviceRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VehiclesTableReferences(
                                db,
                                table,
                                p0,
                              ).serviceRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.vehicleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (remindersRefs)
                        await $_getPrefetchedData<
                          VehicleRow,
                          $VehiclesTable,
                          ReminderRow
                        >(
                          currentTable: table,
                          referencedTable: $$VehiclesTableReferences
                              ._remindersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VehiclesTableReferences(
                                db,
                                table,
                                p0,
                              ).remindersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.vehicleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (fuelEntriesRefs)
                        await $_getPrefetchedData<
                          VehicleRow,
                          $VehiclesTable,
                          FuelEntryRow
                        >(
                          currentTable: table,
                          referencedTable: $$VehiclesTableReferences
                              ._fuelEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VehiclesTableReferences(
                                db,
                                table,
                                p0,
                              ).fuelEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.vehicleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (dtcSnapshotsRefs)
                        await $_getPrefetchedData<
                          VehicleRow,
                          $VehiclesTable,
                          DtcSnapshotRow
                        >(
                          currentTable: table,
                          referencedTable: $$VehiclesTableReferences
                              ._dtcSnapshotsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VehiclesTableReferences(
                                db,
                                table,
                                p0,
                              ).dtcSnapshotsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.vehicleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (tripSessionsRefs)
                        await $_getPrefetchedData<
                          VehicleRow,
                          $VehiclesTable,
                          TripSessionRow
                        >(
                          currentTable: table,
                          referencedTable: $$VehiclesTableReferences
                              ._tripSessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VehiclesTableReferences(
                                db,
                                table,
                                p0,
                              ).tripSessionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.vehicleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (dashboardLayoutsRefs)
                        await $_getPrefetchedData<
                          VehicleRow,
                          $VehiclesTable,
                          DashboardLayoutRow
                        >(
                          currentTable: table,
                          referencedTable: $$VehiclesTableReferences
                              ._dashboardLayoutsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$VehiclesTableReferences(
                                db,
                                table,
                                p0,
                              ).dashboardLayoutsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.vehicleId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$VehiclesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VehiclesTable,
      VehicleRow,
      $$VehiclesTableFilterComposer,
      $$VehiclesTableOrderingComposer,
      $$VehiclesTableAnnotationComposer,
      $$VehiclesTableCreateCompanionBuilder,
      $$VehiclesTableUpdateCompanionBuilder,
      (VehicleRow, $$VehiclesTableReferences),
      VehicleRow,
      PrefetchHooks Function({
        bool serviceRecordsRefs,
        bool remindersRefs,
        bool fuelEntriesRefs,
        bool dtcSnapshotsRefs,
        bool tripSessionsRefs,
        bool dashboardLayoutsRefs,
      })
    >;
typedef $$ServiceRecordsTableCreateCompanionBuilder =
    ServiceRecordsCompanion Function({
      required String id,
      required String vehicleId,
      required ServiceType type,
      required String title,
      required DateTime date,
      Value<double?> odometerKm,
      Value<double?> cost,
      Value<String> currencyCode,
      Value<String?> vendor,
      Value<String?> notes,
      Value<String> attachmentPathsJson,
      Value<String> linkedDtcsJson,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ServiceRecordsTableUpdateCompanionBuilder =
    ServiceRecordsCompanion Function({
      Value<String> id,
      Value<String> vehicleId,
      Value<ServiceType> type,
      Value<String> title,
      Value<DateTime> date,
      Value<double?> odometerKm,
      Value<double?> cost,
      Value<String> currencyCode,
      Value<String?> vendor,
      Value<String?> notes,
      Value<String> attachmentPathsJson,
      Value<String> linkedDtcsJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$ServiceRecordsTableReferences
    extends
        BaseReferences<_$AppDatabase, $ServiceRecordsTable, ServiceRecordRow> {
  $$ServiceRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $VehiclesTable _vehicleIdTable(_$AppDatabase db) =>
      db.vehicles.createAlias('service_records__vehicle_id__vehicles__id');

  $$VehiclesTableProcessedTableManager get vehicleId {
    final $_column = $_itemColumn<String>('vehicle_id')!;

    final manager = $$VehiclesTableTableManager(
      $_db,
      $_db.vehicles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vehicleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ServiceRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $ServiceRecordsTable> {
  $$ServiceRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ServiceType, ServiceType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get odometerKm => $composableBuilder(
    column: $table.odometerKm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cost => $composableBuilder(
    column: $table.cost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vendor => $composableBuilder(
    column: $table.vendor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentPathsJson => $composableBuilder(
    column: $table.attachmentPathsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedDtcsJson => $composableBuilder(
    column: $table.linkedDtcsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$VehiclesTableFilterComposer get vehicleId {
    final $$VehiclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableFilterComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ServiceRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $ServiceRecordsTable> {
  $$ServiceRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get odometerKm => $composableBuilder(
    column: $table.odometerKm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cost => $composableBuilder(
    column: $table.cost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vendor => $composableBuilder(
    column: $table.vendor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentPathsJson => $composableBuilder(
    column: $table.attachmentPathsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedDtcsJson => $composableBuilder(
    column: $table.linkedDtcsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$VehiclesTableOrderingComposer get vehicleId {
    final $$VehiclesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableOrderingComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ServiceRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServiceRecordsTable> {
  $$ServiceRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ServiceType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get odometerKm => $composableBuilder(
    column: $table.odometerKm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get cost =>
      $composableBuilder(column: $table.cost, builder: (column) => column);

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vendor =>
      $composableBuilder(column: $table.vendor, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get attachmentPathsJson => $composableBuilder(
    column: $table.attachmentPathsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get linkedDtcsJson => $composableBuilder(
    column: $table.linkedDtcsJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$VehiclesTableAnnotationComposer get vehicleId {
    final $$VehiclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableAnnotationComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ServiceRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ServiceRecordsTable,
          ServiceRecordRow,
          $$ServiceRecordsTableFilterComposer,
          $$ServiceRecordsTableOrderingComposer,
          $$ServiceRecordsTableAnnotationComposer,
          $$ServiceRecordsTableCreateCompanionBuilder,
          $$ServiceRecordsTableUpdateCompanionBuilder,
          (ServiceRecordRow, $$ServiceRecordsTableReferences),
          ServiceRecordRow,
          PrefetchHooks Function({bool vehicleId})
        > {
  $$ServiceRecordsTableTableManager(
    _$AppDatabase db,
    $ServiceRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServiceRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServiceRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServiceRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<ServiceType> type = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double?> odometerKm = const Value.absent(),
                Value<double?> cost = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<String?> vendor = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> attachmentPathsJson = const Value.absent(),
                Value<String> linkedDtcsJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ServiceRecordsCompanion(
                id: id,
                vehicleId: vehicleId,
                type: type,
                title: title,
                date: date,
                odometerKm: odometerKm,
                cost: cost,
                currencyCode: currencyCode,
                vendor: vendor,
                notes: notes,
                attachmentPathsJson: attachmentPathsJson,
                linkedDtcsJson: linkedDtcsJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String vehicleId,
                required ServiceType type,
                required String title,
                required DateTime date,
                Value<double?> odometerKm = const Value.absent(),
                Value<double?> cost = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<String?> vendor = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> attachmentPathsJson = const Value.absent(),
                Value<String> linkedDtcsJson = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ServiceRecordsCompanion.insert(
                id: id,
                vehicleId: vehicleId,
                type: type,
                title: title,
                date: date,
                odometerKm: odometerKm,
                cost: cost,
                currencyCode: currencyCode,
                vendor: vendor,
                notes: notes,
                attachmentPathsJson: attachmentPathsJson,
                linkedDtcsJson: linkedDtcsJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ServiceRecordsTable, ServiceRecordRow>(table),
                  $$ServiceRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({vehicleId = false}) {
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
                    if (vehicleId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.vehicleId,
                        referencedTable: $$ServiceRecordsTableReferences
                            ._vehicleIdTable(db),
                        referencedColumn: $$ServiceRecordsTableReferences
                            ._vehicleIdTable(db)
                            .id,
                      ) as T;
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

typedef $$ServiceRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ServiceRecordsTable,
      ServiceRecordRow,
      $$ServiceRecordsTableFilterComposer,
      $$ServiceRecordsTableOrderingComposer,
      $$ServiceRecordsTableAnnotationComposer,
      $$ServiceRecordsTableCreateCompanionBuilder,
      $$ServiceRecordsTableUpdateCompanionBuilder,
      (ServiceRecordRow, $$ServiceRecordsTableReferences),
      ServiceRecordRow,
      PrefetchHooks Function({bool vehicleId})
    >;
typedef $$RemindersTableCreateCompanionBuilder = RemindersCompanion Function({
  required String id,
  required String vehicleId,
  required String title,
  Value<String?> detail,
  Value<DateTime?> dueDate,
  Value<double?> dueOdometerKm,
  Value<int?> repeatEveryDays,
  Value<double?> repeatEveryKm,
  Value<bool> critical,
  Value<bool> paused,
  Value<DateTime?> completedAt,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$RemindersTableUpdateCompanionBuilder = RemindersCompanion Function({
  Value<String> id,
  Value<String> vehicleId,
  Value<String> title,
  Value<String?> detail,
  Value<DateTime?> dueDate,
  Value<double?> dueOdometerKm,
  Value<int?> repeatEveryDays,
  Value<double?> repeatEveryKm,
  Value<bool> critical,
  Value<bool> paused,
  Value<DateTime?> completedAt,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$RemindersTableReferences
    extends BaseReferences<_$AppDatabase, $RemindersTable, ReminderRow> {
  $$RemindersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $VehiclesTable _vehicleIdTable(_$AppDatabase db) =>
      db.vehicles.createAlias('reminders__vehicle_id__vehicles__id');

  $$VehiclesTableProcessedTableManager get vehicleId {
    final $_column = $_itemColumn<String>('vehicle_id')!;

    final manager = $$VehiclesTableTableManager(
      $_db,
      $_db.vehicles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vehicleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RemindersTableFilterComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get dueOdometerKm => $composableBuilder(
    column: $table.dueOdometerKm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repeatEveryDays => $composableBuilder(
    column: $table.repeatEveryDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get repeatEveryKm => $composableBuilder(
    column: $table.repeatEveryKm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get critical => $composableBuilder(
    column: $table.critical,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get paused => $composableBuilder(
    column: $table.paused,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$VehiclesTableFilterComposer get vehicleId {
    final $$VehiclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableFilterComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get dueOdometerKm => $composableBuilder(
    column: $table.dueOdometerKm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repeatEveryDays => $composableBuilder(
    column: $table.repeatEveryDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get repeatEveryKm => $composableBuilder(
    column: $table.repeatEveryKm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get critical => $composableBuilder(
    column: $table.critical,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get paused => $composableBuilder(
    column: $table.paused,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$VehiclesTableOrderingComposer get vehicleId {
    final $$VehiclesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableOrderingComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<double> get dueOdometerKm => $composableBuilder(
    column: $table.dueOdometerKm,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repeatEveryDays => $composableBuilder(
    column: $table.repeatEveryDays,
    builder: (column) => column,
  );

  GeneratedColumn<double> get repeatEveryKm => $composableBuilder(
    column: $table.repeatEveryKm,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get critical =>
      $composableBuilder(column: $table.critical, builder: (column) => column);

  GeneratedColumn<bool> get paused =>
      $composableBuilder(column: $table.paused, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$VehiclesTableAnnotationComposer get vehicleId {
    final $$VehiclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableAnnotationComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RemindersTable,
          ReminderRow,
          $$RemindersTableFilterComposer,
          $$RemindersTableOrderingComposer,
          $$RemindersTableAnnotationComposer,
          $$RemindersTableCreateCompanionBuilder,
          $$RemindersTableUpdateCompanionBuilder,
          (ReminderRow, $$RemindersTableReferences),
          ReminderRow,
          PrefetchHooks Function({bool vehicleId})
        > {
  $$RemindersTableTableManager(_$AppDatabase db, $RemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<double?> dueOdometerKm = const Value.absent(),
                Value<int?> repeatEveryDays = const Value.absent(),
                Value<double?> repeatEveryKm = const Value.absent(),
                Value<bool> critical = const Value.absent(),
                Value<bool> paused = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion(
                id: id,
                vehicleId: vehicleId,
                title: title,
                detail: detail,
                dueDate: dueDate,
                dueOdometerKm: dueOdometerKm,
                repeatEveryDays: repeatEveryDays,
                repeatEveryKm: repeatEveryKm,
                critical: critical,
                paused: paused,
                completedAt: completedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String vehicleId,
                required String title,
                Value<String?> detail = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<double?> dueOdometerKm = const Value.absent(),
                Value<int?> repeatEveryDays = const Value.absent(),
                Value<double?> repeatEveryKm = const Value.absent(),
                Value<bool> critical = const Value.absent(),
                Value<bool> paused = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion.insert(
                id: id,
                vehicleId: vehicleId,
                title: title,
                detail: detail,
                dueDate: dueDate,
                dueOdometerKm: dueOdometerKm,
                repeatEveryDays: repeatEveryDays,
                repeatEveryKm: repeatEveryKm,
                critical: critical,
                paused: paused,
                completedAt: completedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RemindersTable, ReminderRow>(table),
                  $$RemindersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({vehicleId = false}) {
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
                    if (vehicleId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.vehicleId,
                        referencedTable: $$RemindersTableReferences
                            ._vehicleIdTable(db),
                        referencedColumn: $$RemindersTableReferences
                            ._vehicleIdTable(db)
                            .id,
                      ) as T;
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

typedef $$RemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RemindersTable,
      ReminderRow,
      $$RemindersTableFilterComposer,
      $$RemindersTableOrderingComposer,
      $$RemindersTableAnnotationComposer,
      $$RemindersTableCreateCompanionBuilder,
      $$RemindersTableUpdateCompanionBuilder,
      (ReminderRow, $$RemindersTableReferences),
      ReminderRow,
      PrefetchHooks Function({bool vehicleId})
    >;
typedef $$FuelEntriesTableCreateCompanionBuilder =
    FuelEntriesCompanion Function({
      required String id,
      required String vehicleId,
      required DateTime date,
      required double odometerKm,
      required double litres,
      Value<double?> cost,
      Value<String> currencyCode,
      Value<bool> partFill,
      Value<String?> notes,
      Value<int> rowid,
    });
typedef $$FuelEntriesTableUpdateCompanionBuilder =
    FuelEntriesCompanion Function({
      Value<String> id,
      Value<String> vehicleId,
      Value<DateTime> date,
      Value<double> odometerKm,
      Value<double> litres,
      Value<double?> cost,
      Value<String> currencyCode,
      Value<bool> partFill,
      Value<String?> notes,
      Value<int> rowid,
    });

final class $$FuelEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $FuelEntriesTable, FuelEntryRow> {
  $$FuelEntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $VehiclesTable _vehicleIdTable(_$AppDatabase db) =>
      db.vehicles.createAlias('fuel_entries__vehicle_id__vehicles__id');

  $$VehiclesTableProcessedTableManager get vehicleId {
    final $_column = $_itemColumn<String>('vehicle_id')!;

    final manager = $$VehiclesTableTableManager(
      $_db,
      $_db.vehicles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vehicleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FuelEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $FuelEntriesTable> {
  $$FuelEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get odometerKm => $composableBuilder(
    column: $table.odometerKm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get litres => $composableBuilder(
    column: $table.litres,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cost => $composableBuilder(
    column: $table.cost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get partFill => $composableBuilder(
    column: $table.partFill,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$VehiclesTableFilterComposer get vehicleId {
    final $$VehiclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableFilterComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FuelEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $FuelEntriesTable> {
  $$FuelEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get odometerKm => $composableBuilder(
    column: $table.odometerKm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get litres => $composableBuilder(
    column: $table.litres,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cost => $composableBuilder(
    column: $table.cost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get partFill => $composableBuilder(
    column: $table.partFill,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$VehiclesTableOrderingComposer get vehicleId {
    final $$VehiclesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableOrderingComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FuelEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FuelEntriesTable> {
  $$FuelEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get odometerKm => $composableBuilder(
    column: $table.odometerKm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get litres =>
      $composableBuilder(column: $table.litres, builder: (column) => column);

  GeneratedColumn<double> get cost =>
      $composableBuilder(column: $table.cost, builder: (column) => column);

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get partFill =>
      $composableBuilder(column: $table.partFill, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$VehiclesTableAnnotationComposer get vehicleId {
    final $$VehiclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableAnnotationComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FuelEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FuelEntriesTable,
          FuelEntryRow,
          $$FuelEntriesTableFilterComposer,
          $$FuelEntriesTableOrderingComposer,
          $$FuelEntriesTableAnnotationComposer,
          $$FuelEntriesTableCreateCompanionBuilder,
          $$FuelEntriesTableUpdateCompanionBuilder,
          (FuelEntryRow, $$FuelEntriesTableReferences),
          FuelEntryRow,
          PrefetchHooks Function({bool vehicleId})
        > {
  $$FuelEntriesTableTableManager(_$AppDatabase db, $FuelEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FuelEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FuelEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FuelEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double> odometerKm = const Value.absent(),
                Value<double> litres = const Value.absent(),
                Value<double?> cost = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<bool> partFill = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FuelEntriesCompanion(
                id: id,
                vehicleId: vehicleId,
                date: date,
                odometerKm: odometerKm,
                litres: litres,
                cost: cost,
                currencyCode: currencyCode,
                partFill: partFill,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String vehicleId,
                required DateTime date,
                required double odometerKm,
                required double litres,
                Value<double?> cost = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<bool> partFill = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FuelEntriesCompanion.insert(
                id: id,
                vehicleId: vehicleId,
                date: date,
                odometerKm: odometerKm,
                litres: litres,
                cost: cost,
                currencyCode: currencyCode,
                partFill: partFill,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FuelEntriesTable, FuelEntryRow>(table),
                  $$FuelEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({vehicleId = false}) {
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
                    if (vehicleId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.vehicleId,
                        referencedTable: $$FuelEntriesTableReferences
                            ._vehicleIdTable(db),
                        referencedColumn: $$FuelEntriesTableReferences
                            ._vehicleIdTable(db)
                            .id,
                      ) as T;
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

typedef $$FuelEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FuelEntriesTable,
      FuelEntryRow,
      $$FuelEntriesTableFilterComposer,
      $$FuelEntriesTableOrderingComposer,
      $$FuelEntriesTableAnnotationComposer,
      $$FuelEntriesTableCreateCompanionBuilder,
      $$FuelEntriesTableUpdateCompanionBuilder,
      (FuelEntryRow, $$FuelEntriesTableReferences),
      FuelEntryRow,
      PrefetchHooks Function({bool vehicleId})
    >;
typedef $$DtcSnapshotsTableCreateCompanionBuilder =
    DtcSnapshotsCompanion Function({
      required String id,
      required String vehicleId,
      required DateTime takenAt,
      required SnapshotPurpose purpose,
      required String codesJson,
      Value<bool?> milOn,
      Value<int?> dtcCount,
      Value<String?> readinessJson,
      Value<int?> protocol,
      Value<ClearOutcome?> clearOutcome,
      Value<String?> relatedSnapshotId,
      Value<String?> freezeFrameJson,
      Value<int> rowid,
    });
typedef $$DtcSnapshotsTableUpdateCompanionBuilder =
    DtcSnapshotsCompanion Function({
      Value<String> id,
      Value<String> vehicleId,
      Value<DateTime> takenAt,
      Value<SnapshotPurpose> purpose,
      Value<String> codesJson,
      Value<bool?> milOn,
      Value<int?> dtcCount,
      Value<String?> readinessJson,
      Value<int?> protocol,
      Value<ClearOutcome?> clearOutcome,
      Value<String?> relatedSnapshotId,
      Value<String?> freezeFrameJson,
      Value<int> rowid,
    });

final class $$DtcSnapshotsTableReferences
    extends BaseReferences<_$AppDatabase, $DtcSnapshotsTable, DtcSnapshotRow> {
  $$DtcSnapshotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $VehiclesTable _vehicleIdTable(_$AppDatabase db) =>
      db.vehicles.createAlias('dtc_snapshots__vehicle_id__vehicles__id');

  $$VehiclesTableProcessedTableManager get vehicleId {
    final $_column = $_itemColumn<String>('vehicle_id')!;

    final manager = $$VehiclesTableTableManager(
      $_db,
      $_db.vehicles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vehicleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DtcSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $DtcSnapshotsTable> {
  $$DtcSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SnapshotPurpose, SnapshotPurpose, String>
  get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get codesJson => $composableBuilder(
    column: $table.codesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get milOn => $composableBuilder(
    column: $table.milOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dtcCount => $composableBuilder(
    column: $table.dtcCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get readinessJson => $composableBuilder(
    column: $table.readinessJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get protocol => $composableBuilder(
    column: $table.protocol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ClearOutcome?, ClearOutcome, String>
  get clearOutcome => $composableBuilder(
    column: $table.clearOutcome,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get relatedSnapshotId => $composableBuilder(
    column: $table.relatedSnapshotId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get freezeFrameJson => $composableBuilder(
    column: $table.freezeFrameJson,
    builder: (column) => ColumnFilters(column),
  );

  $$VehiclesTableFilterComposer get vehicleId {
    final $$VehiclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableFilterComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DtcSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $DtcSnapshotsTable> {
  $$DtcSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get purpose => $composableBuilder(
    column: $table.purpose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get codesJson => $composableBuilder(
    column: $table.codesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get milOn => $composableBuilder(
    column: $table.milOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dtcCount => $composableBuilder(
    column: $table.dtcCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readinessJson => $composableBuilder(
    column: $table.readinessJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get protocol => $composableBuilder(
    column: $table.protocol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clearOutcome => $composableBuilder(
    column: $table.clearOutcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relatedSnapshotId => $composableBuilder(
    column: $table.relatedSnapshotId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get freezeFrameJson => $composableBuilder(
    column: $table.freezeFrameJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$VehiclesTableOrderingComposer get vehicleId {
    final $$VehiclesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableOrderingComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DtcSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DtcSnapshotsTable> {
  $$DtcSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get takenAt =>
      $composableBuilder(column: $table.takenAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SnapshotPurpose, String> get purpose =>
      $composableBuilder(column: $table.purpose, builder: (column) => column);

  GeneratedColumn<String> get codesJson =>
      $composableBuilder(column: $table.codesJson, builder: (column) => column);

  GeneratedColumn<bool> get milOn =>
      $composableBuilder(column: $table.milOn, builder: (column) => column);

  GeneratedColumn<int> get dtcCount =>
      $composableBuilder(column: $table.dtcCount, builder: (column) => column);

  GeneratedColumn<String> get readinessJson => $composableBuilder(
    column: $table.readinessJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get protocol =>
      $composableBuilder(column: $table.protocol, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ClearOutcome?, String> get clearOutcome =>
      $composableBuilder(
        column: $table.clearOutcome,
        builder: (column) => column,
      );

  GeneratedColumn<String> get relatedSnapshotId => $composableBuilder(
    column: $table.relatedSnapshotId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get freezeFrameJson => $composableBuilder(
    column: $table.freezeFrameJson,
    builder: (column) => column,
  );

  $$VehiclesTableAnnotationComposer get vehicleId {
    final $$VehiclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableAnnotationComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DtcSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DtcSnapshotsTable,
          DtcSnapshotRow,
          $$DtcSnapshotsTableFilterComposer,
          $$DtcSnapshotsTableOrderingComposer,
          $$DtcSnapshotsTableAnnotationComposer,
          $$DtcSnapshotsTableCreateCompanionBuilder,
          $$DtcSnapshotsTableUpdateCompanionBuilder,
          (DtcSnapshotRow, $$DtcSnapshotsTableReferences),
          DtcSnapshotRow,
          PrefetchHooks Function({bool vehicleId})
        > {
  $$DtcSnapshotsTableTableManager(_$AppDatabase db, $DtcSnapshotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DtcSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DtcSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DtcSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<DateTime> takenAt = const Value.absent(),
                Value<SnapshotPurpose> purpose = const Value.absent(),
                Value<String> codesJson = const Value.absent(),
                Value<bool?> milOn = const Value.absent(),
                Value<int?> dtcCount = const Value.absent(),
                Value<String?> readinessJson = const Value.absent(),
                Value<int?> protocol = const Value.absent(),
                Value<ClearOutcome?> clearOutcome = const Value.absent(),
                Value<String?> relatedSnapshotId = const Value.absent(),
                Value<String?> freezeFrameJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DtcSnapshotsCompanion(
                id: id,
                vehicleId: vehicleId,
                takenAt: takenAt,
                purpose: purpose,
                codesJson: codesJson,
                milOn: milOn,
                dtcCount: dtcCount,
                readinessJson: readinessJson,
                protocol: protocol,
                clearOutcome: clearOutcome,
                relatedSnapshotId: relatedSnapshotId,
                freezeFrameJson: freezeFrameJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String vehicleId,
                required DateTime takenAt,
                required SnapshotPurpose purpose,
                required String codesJson,
                Value<bool?> milOn = const Value.absent(),
                Value<int?> dtcCount = const Value.absent(),
                Value<String?> readinessJson = const Value.absent(),
                Value<int?> protocol = const Value.absent(),
                Value<ClearOutcome?> clearOutcome = const Value.absent(),
                Value<String?> relatedSnapshotId = const Value.absent(),
                Value<String?> freezeFrameJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DtcSnapshotsCompanion.insert(
                id: id,
                vehicleId: vehicleId,
                takenAt: takenAt,
                purpose: purpose,
                codesJson: codesJson,
                milOn: milOn,
                dtcCount: dtcCount,
                readinessJson: readinessJson,
                protocol: protocol,
                clearOutcome: clearOutcome,
                relatedSnapshotId: relatedSnapshotId,
                freezeFrameJson: freezeFrameJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DtcSnapshotsTable, DtcSnapshotRow>(table),
                  $$DtcSnapshotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({vehicleId = false}) {
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
                    if (vehicleId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.vehicleId,
                        referencedTable: $$DtcSnapshotsTableReferences
                            ._vehicleIdTable(db),
                        referencedColumn: $$DtcSnapshotsTableReferences
                            ._vehicleIdTable(db)
                            .id,
                      ) as T;
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

typedef $$DtcSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DtcSnapshotsTable,
      DtcSnapshotRow,
      $$DtcSnapshotsTableFilterComposer,
      $$DtcSnapshotsTableOrderingComposer,
      $$DtcSnapshotsTableAnnotationComposer,
      $$DtcSnapshotsTableCreateCompanionBuilder,
      $$DtcSnapshotsTableUpdateCompanionBuilder,
      (DtcSnapshotRow, $$DtcSnapshotsTableReferences),
      DtcSnapshotRow,
      PrefetchHooks Function({bool vehicleId})
    >;
typedef $$TripSessionsTableCreateCompanionBuilder =
    TripSessionsCompanion Function({
      required String id,
      required String vehicleId,
      Value<String?> name,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      required DateTime lastOpenedAt,
      Value<double?> distanceKm,
      Value<double?> avgSpeedKph,
      Value<double?> maxSpeedKph,
      Value<int> sampleCount,
      required String samplesFilePath,
      Value<int> fileBytes,
      Value<bool> interrupted,
      Value<double?> fuelUsedL,
      Value<int?> recordedMs,
      Value<TripEnd?> endReason,
      Value<int> rowid,
    });
typedef $$TripSessionsTableUpdateCompanionBuilder =
    TripSessionsCompanion Function({
      Value<String> id,
      Value<String> vehicleId,
      Value<String?> name,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<DateTime> lastOpenedAt,
      Value<double?> distanceKm,
      Value<double?> avgSpeedKph,
      Value<double?> maxSpeedKph,
      Value<int> sampleCount,
      Value<String> samplesFilePath,
      Value<int> fileBytes,
      Value<bool> interrupted,
      Value<double?> fuelUsedL,
      Value<int?> recordedMs,
      Value<TripEnd?> endReason,
      Value<int> rowid,
    });

final class $$TripSessionsTableReferences
    extends BaseReferences<_$AppDatabase, $TripSessionsTable, TripSessionRow> {
  $$TripSessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $VehiclesTable _vehicleIdTable(_$AppDatabase db) =>
      db.vehicles.createAlias('trip_sessions__vehicle_id__vehicles__id');

  $$VehiclesTableProcessedTableManager get vehicleId {
    final $_column = $_itemColumn<String>('vehicle_id')!;

    final manager = $$VehiclesTableTableManager(
      $_db,
      $_db.vehicles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vehicleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TripSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $TripSessionsTable> {
  $$TripSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distanceKm => $composableBuilder(
    column: $table.distanceKm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get avgSpeedKph => $composableBuilder(
    column: $table.avgSpeedKph,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxSpeedKph => $composableBuilder(
    column: $table.maxSpeedKph,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sampleCount => $composableBuilder(
    column: $table.sampleCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get samplesFilePath => $composableBuilder(
    column: $table.samplesFilePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileBytes => $composableBuilder(
    column: $table.fileBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get interrupted => $composableBuilder(
    column: $table.interrupted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fuelUsedL => $composableBuilder(
    column: $table.fuelUsedL,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recordedMs => $composableBuilder(
    column: $table.recordedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TripEnd?, TripEnd, String> get endReason =>
      $composableBuilder(
        column: $table.endReason,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$VehiclesTableFilterComposer get vehicleId {
    final $$VehiclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableFilterComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TripSessionsTable> {
  $$TripSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanceKm => $composableBuilder(
    column: $table.distanceKm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get avgSpeedKph => $composableBuilder(
    column: $table.avgSpeedKph,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxSpeedKph => $composableBuilder(
    column: $table.maxSpeedKph,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sampleCount => $composableBuilder(
    column: $table.sampleCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get samplesFilePath => $composableBuilder(
    column: $table.samplesFilePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileBytes => $composableBuilder(
    column: $table.fileBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get interrupted => $composableBuilder(
    column: $table.interrupted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fuelUsedL => $composableBuilder(
    column: $table.fuelUsedL,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recordedMs => $composableBuilder(
    column: $table.recordedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endReason => $composableBuilder(
    column: $table.endReason,
    builder: (column) => ColumnOrderings(column),
  );

  $$VehiclesTableOrderingComposer get vehicleId {
    final $$VehiclesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableOrderingComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TripSessionsTable> {
  $$TripSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get distanceKm => $composableBuilder(
    column: $table.distanceKm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get avgSpeedKph => $composableBuilder(
    column: $table.avgSpeedKph,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxSpeedKph => $composableBuilder(
    column: $table.maxSpeedKph,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sampleCount => $composableBuilder(
    column: $table.sampleCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get samplesFilePath => $composableBuilder(
    column: $table.samplesFilePath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fileBytes =>
      $composableBuilder(column: $table.fileBytes, builder: (column) => column);

  GeneratedColumn<bool> get interrupted => $composableBuilder(
    column: $table.interrupted,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fuelUsedL =>
      $composableBuilder(column: $table.fuelUsedL, builder: (column) => column);

  GeneratedColumn<int> get recordedMs => $composableBuilder(
    column: $table.recordedMs,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<TripEnd?, String> get endReason =>
      $composableBuilder(column: $table.endReason, builder: (column) => column);

  $$VehiclesTableAnnotationComposer get vehicleId {
    final $$VehiclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableAnnotationComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TripSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TripSessionsTable,
          TripSessionRow,
          $$TripSessionsTableFilterComposer,
          $$TripSessionsTableOrderingComposer,
          $$TripSessionsTableAnnotationComposer,
          $$TripSessionsTableCreateCompanionBuilder,
          $$TripSessionsTableUpdateCompanionBuilder,
          (TripSessionRow, $$TripSessionsTableReferences),
          TripSessionRow,
          PrefetchHooks Function({bool vehicleId})
        > {
  $$TripSessionsTableTableManager(_$AppDatabase db, $TripSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<DateTime> lastOpenedAt = const Value.absent(),
                Value<double?> distanceKm = const Value.absent(),
                Value<double?> avgSpeedKph = const Value.absent(),
                Value<double?> maxSpeedKph = const Value.absent(),
                Value<int> sampleCount = const Value.absent(),
                Value<String> samplesFilePath = const Value.absent(),
                Value<int> fileBytes = const Value.absent(),
                Value<bool> interrupted = const Value.absent(),
                Value<double?> fuelUsedL = const Value.absent(),
                Value<int?> recordedMs = const Value.absent(),
                Value<TripEnd?> endReason = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripSessionsCompanion(
                id: id,
                vehicleId: vehicleId,
                name: name,
                startedAt: startedAt,
                endedAt: endedAt,
                lastOpenedAt: lastOpenedAt,
                distanceKm: distanceKm,
                avgSpeedKph: avgSpeedKph,
                maxSpeedKph: maxSpeedKph,
                sampleCount: sampleCount,
                samplesFilePath: samplesFilePath,
                fileBytes: fileBytes,
                interrupted: interrupted,
                fuelUsedL: fuelUsedL,
                recordedMs: recordedMs,
                endReason: endReason,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String vehicleId,
                Value<String?> name = const Value.absent(),
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                required DateTime lastOpenedAt,
                Value<double?> distanceKm = const Value.absent(),
                Value<double?> avgSpeedKph = const Value.absent(),
                Value<double?> maxSpeedKph = const Value.absent(),
                Value<int> sampleCount = const Value.absent(),
                required String samplesFilePath,
                Value<int> fileBytes = const Value.absent(),
                Value<bool> interrupted = const Value.absent(),
                Value<double?> fuelUsedL = const Value.absent(),
                Value<int?> recordedMs = const Value.absent(),
                Value<TripEnd?> endReason = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripSessionsCompanion.insert(
                id: id,
                vehicleId: vehicleId,
                name: name,
                startedAt: startedAt,
                endedAt: endedAt,
                lastOpenedAt: lastOpenedAt,
                distanceKm: distanceKm,
                avgSpeedKph: avgSpeedKph,
                maxSpeedKph: maxSpeedKph,
                sampleCount: sampleCount,
                samplesFilePath: samplesFilePath,
                fileBytes: fileBytes,
                interrupted: interrupted,
                fuelUsedL: fuelUsedL,
                recordedMs: recordedMs,
                endReason: endReason,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TripSessionsTable, TripSessionRow>(table),
                  $$TripSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({vehicleId = false}) {
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
                    if (vehicleId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.vehicleId,
                        referencedTable: $$TripSessionsTableReferences
                            ._vehicleIdTable(db),
                        referencedColumn: $$TripSessionsTableReferences
                            ._vehicleIdTable(db)
                            .id,
                      ) as T;
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

typedef $$TripSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TripSessionsTable,
      TripSessionRow,
      $$TripSessionsTableFilterComposer,
      $$TripSessionsTableOrderingComposer,
      $$TripSessionsTableAnnotationComposer,
      $$TripSessionsTableCreateCompanionBuilder,
      $$TripSessionsTableUpdateCompanionBuilder,
      (TripSessionRow, $$TripSessionsTableReferences),
      TripSessionRow,
      PrefetchHooks Function({bool vehicleId})
    >;
typedef $$DashboardLayoutsTableCreateCompanionBuilder =
    DashboardLayoutsCompanion Function({
      required String id,
      required String vehicleId,
      required String name,
      required String tilesJson,
      required DateTime createdAt,
      required DateTime selectedAt,
      Value<int> rowid,
    });
typedef $$DashboardLayoutsTableUpdateCompanionBuilder =
    DashboardLayoutsCompanion Function({
      Value<String> id,
      Value<String> vehicleId,
      Value<String> name,
      Value<String> tilesJson,
      Value<DateTime> createdAt,
      Value<DateTime> selectedAt,
      Value<int> rowid,
    });

final class $$DashboardLayoutsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DashboardLayoutsTable,
          DashboardLayoutRow
        > {
  $$DashboardLayoutsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $VehiclesTable _vehicleIdTable(_$AppDatabase db) =>
      db.vehicles.createAlias('dashboard_layouts__vehicle_id__vehicles__id');

  $$VehiclesTableProcessedTableManager get vehicleId {
    final $_column = $_itemColumn<String>('vehicle_id')!;

    final manager = $$VehiclesTableTableManager(
      $_db,
      $_db.vehicles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_vehicleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DashboardLayoutsTableFilterComposer
    extends Composer<_$AppDatabase, $DashboardLayoutsTable> {
  $$DashboardLayoutsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tilesJson => $composableBuilder(
    column: $table.tilesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get selectedAt => $composableBuilder(
    column: $table.selectedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$VehiclesTableFilterComposer get vehicleId {
    final $$VehiclesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableFilterComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DashboardLayoutsTableOrderingComposer
    extends Composer<_$AppDatabase, $DashboardLayoutsTable> {
  $$DashboardLayoutsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tilesJson => $composableBuilder(
    column: $table.tilesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get selectedAt => $composableBuilder(
    column: $table.selectedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$VehiclesTableOrderingComposer get vehicleId {
    final $$VehiclesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableOrderingComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DashboardLayoutsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DashboardLayoutsTable> {
  $$DashboardLayoutsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get tilesJson =>
      $composableBuilder(column: $table.tilesJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get selectedAt => $composableBuilder(
    column: $table.selectedAt,
    builder: (column) => column,
  );

  $$VehiclesTableAnnotationComposer get vehicleId {
    final $$VehiclesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.vehicleId,
      referencedTable: $db.vehicles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$VehiclesTableAnnotationComposer(
            $db: $db,
            $table: $db.vehicles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DashboardLayoutsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DashboardLayoutsTable,
          DashboardLayoutRow,
          $$DashboardLayoutsTableFilterComposer,
          $$DashboardLayoutsTableOrderingComposer,
          $$DashboardLayoutsTableAnnotationComposer,
          $$DashboardLayoutsTableCreateCompanionBuilder,
          $$DashboardLayoutsTableUpdateCompanionBuilder,
          (DashboardLayoutRow, $$DashboardLayoutsTableReferences),
          DashboardLayoutRow,
          PrefetchHooks Function({bool vehicleId})
        > {
  $$DashboardLayoutsTableTableManager(
    _$AppDatabase db,
    $DashboardLayoutsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DashboardLayoutsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DashboardLayoutsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DashboardLayoutsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> tilesJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> selectedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DashboardLayoutsCompanion(
                id: id,
                vehicleId: vehicleId,
                name: name,
                tilesJson: tilesJson,
                createdAt: createdAt,
                selectedAt: selectedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String vehicleId,
                required String name,
                required String tilesJson,
                required DateTime createdAt,
                required DateTime selectedAt,
                Value<int> rowid = const Value.absent(),
              }) => DashboardLayoutsCompanion.insert(
                id: id,
                vehicleId: vehicleId,
                name: name,
                tilesJson: tilesJson,
                createdAt: createdAt,
                selectedAt: selectedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DashboardLayoutsTable, DashboardLayoutRow>(
                    table,
                  ),
                  $$DashboardLayoutsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({vehicleId = false}) {
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
                    if (vehicleId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.vehicleId,
                        referencedTable: $$DashboardLayoutsTableReferences
                            ._vehicleIdTable(db),
                        referencedColumn: $$DashboardLayoutsTableReferences
                            ._vehicleIdTable(db)
                            .id,
                      ) as T;
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

typedef $$DashboardLayoutsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DashboardLayoutsTable,
      DashboardLayoutRow,
      $$DashboardLayoutsTableFilterComposer,
      $$DashboardLayoutsTableOrderingComposer,
      $$DashboardLayoutsTableAnnotationComposer,
      $$DashboardLayoutsTableCreateCompanionBuilder,
      $$DashboardLayoutsTableUpdateCompanionBuilder,
      (DashboardLayoutRow, $$DashboardLayoutsTableReferences),
      DashboardLayoutRow,
      PrefetchHooks Function({bool vehicleId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$VehiclesTableTableManager get vehicles =>
      $$VehiclesTableTableManager(_db, _db.vehicles);
  $$ServiceRecordsTableTableManager get serviceRecords =>
      $$ServiceRecordsTableTableManager(_db, _db.serviceRecords);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db, _db.reminders);
  $$FuelEntriesTableTableManager get fuelEntries =>
      $$FuelEntriesTableTableManager(_db, _db.fuelEntries);
  $$DtcSnapshotsTableTableManager get dtcSnapshots =>
      $$DtcSnapshotsTableTableManager(_db, _db.dtcSnapshots);
  $$TripSessionsTableTableManager get tripSessions =>
      $$TripSessionsTableTableManager(_db, _db.tripSessions);
  $$DashboardLayoutsTableTableManager get dashboardLayouts =>
      $$DashboardLayoutsTableTableManager(_db, _db.dashboardLayouts);
}
