import 'package:cloud_firestore/cloud_firestore.dart';

class DtroCollections {
  const DtroCollections._();

  static const rawOrders = 'parkpal_dtro_raw_orders';
  static const legalRecords = 'parkpal_dtro_legal_records';
}

enum DtroRegulationType {
  kerbsideNoWaiting,
  kerbsideResidentParkingPlace,
  kerbsideLoadingBay,
  kerbsideDisabledParkingPlace,
  kerbsidePaidParkingPlace,
  kerbsidePermitParkingPlace,
  kerbsideSchoolKeepClear,
  kerbsideBusStopClearway,
  kerbsideTaxiRank,
  movingBusLane,
  movingOneWay,
  movingNoEntry,
  movingNoMotorVehicles,
  speedLimit,
  other,
}

enum DtroVerificationStatus { pending, imported, verified, disputed, rejected }

enum DtroSourceStatus { draft, active, superseded, revoked, unknown }

class DtroAuthority {
  const DtroAuthority({
    required this.authorityId,
    required this.name,
    this.organisation,
    this.reference,
  });

  factory DtroAuthority.fromMap(Map<String, Object?> data) {
    return DtroAuthority(
      authorityId: _string(data['authorityId']) ?? _string(data['id']) ?? '',
      name: _string(data['name']) ?? 'Unknown authority',
      organisation: _string(data['organisation']),
      reference: _string(data['reference']),
    );
  }

  final String authorityId;
  final String name;
  final String? organisation;
  final String? reference;

  Map<String, Object?> toMap() => {
        'authorityId': authorityId,
        'name': name,
        'organisation': organisation,
        'reference': reference,
      };
}

class DtroSource {
  const DtroSource({
    required this.sourceId,
    required this.sourceUrl,
    required this.name,
    required this.status,
    this.publisher,
    this.version,
  });

  factory DtroSource.fromMap(Map<String, Object?> data) {
    return DtroSource(
      sourceId: _string(data['sourceId']) ?? _string(data['id']) ?? '',
      sourceUrl: _string(data['sourceUrl']) ?? _string(data['url']) ?? '',
      name: _string(data['name']) ?? 'D-TRO source',
      publisher: _string(data['publisher']),
      version: _string(data['version']),
      status: DtroSourceStatus.values.firstWhere(
        (value) => value.name == data['status'],
        orElse: () => DtroSourceStatus.unknown,
      ),
    );
  }

  final String sourceId;
  final String sourceUrl;
  final String name;
  final String? publisher;
  final String? version;
  final DtroSourceStatus status;

  Map<String, Object?> toMap() => {
        'sourceId': sourceId,
        'sourceUrl': sourceUrl,
        'name': name,
        'publisher': publisher,
        'version': version,
        'status': status.name,
      };
}

class DtroGeometry {
  const DtroGeometry({required this.type, required this.coordinates});

  factory DtroGeometry.fromMap(Map<String, Object?> data) {
    return DtroGeometry(
      type: _string(data['type']) ?? 'Geometry',
      coordinates: data['coordinates'],
    );
  }

  final String type;
  final Object? coordinates;

  Map<String, Object?> toMap() => {
        'type': type,
        'coordinates': coordinates,
      };
}

class DtroTimeValidity {
  const DtroTimeValidity({
    this.days,
    this.startTime,
    this.endTime,
    this.dateFrom,
    this.dateTo,
  });

  factory DtroTimeValidity.fromMap(Map<String, Object?> data) {
    return DtroTimeValidity(
      days: (data['days'] as List?)?.map((value) => value.toString()).toList(),
      startTime: _string(data['startTime']),
      endTime: _string(data['endTime']),
      dateFrom: _timestampDate(data['dateFrom']),
      dateTo: _timestampDate(data['dateTo']),
    );
  }

  final List<String>? days;
  final String? startTime;
  final String? endTime;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  Map<String, Object?> toMap() => {
        'days': days,
        'startTime': startTime,
        'endTime': endTime,
        'dateFrom': dateFrom == null ? null : Timestamp.fromDate(dateFrom!),
        'dateTo': dateTo == null ? null : Timestamp.fromDate(dateTo!),
      };
}

class DtroVehicleCharacteristics {
  const DtroVehicleCharacteristics({
    this.vehicleType,
    this.permitType,
    this.maxWeightKg,
    this.disabledBadgeRequired,
  });

  factory DtroVehicleCharacteristics.fromMap(Map<String, Object?> data) {
    return DtroVehicleCharacteristics(
      vehicleType: _string(data['vehicleType']),
      permitType: _string(data['permitType']),
      maxWeightKg: (data['maxWeightKg'] as num?)?.toDouble(),
      disabledBadgeRequired: data['disabledBadgeRequired'] as bool?,
    );
  }

  final String? vehicleType;
  final String? permitType;
  final double? maxWeightKg;
  final bool? disabledBadgeRequired;

  Map<String, Object?> toMap() => {
        'vehicleType': vehicleType,
        'permitType': permitType,
        'maxWeightKg': maxWeightKg,
        'disabledBadgeRequired': disabledBadgeRequired,
      };
}

class DtroRate {
  const DtroRate({
    this.amount,
    this.currency,
    this.duration,
    this.description,
  });

  factory DtroRate.fromMap(Map<String, Object?> data) {
    return DtroRate(
      amount: (data['amount'] as num?)?.toDouble(),
      currency: _string(data['currency']),
      duration: _string(data['duration']),
      description: _string(data['description']),
    );
  }

  final double? amount;
  final String? currency;
  final String? duration;
  final String? description;

  Map<String, Object?> toMap() => {
        'amount': amount,
        'currency': currency,
        'duration': duration,
        'description': description,
      };
}

class DtroCondition {
  const DtroCondition({
    this.timeValidity,
    this.vehicleCharacteristics,
    this.rate,
    this.text,
  });

  factory DtroCondition.fromMap(Map<String, Object?> data) {
    return DtroCondition(
      timeValidity: data['timeValidity'] is Map
          ? DtroTimeValidity.fromMap(
              (data['timeValidity'] as Map).cast<String, Object?>(),
            )
          : null,
      vehicleCharacteristics: data['vehicleCharacteristics'] is Map
          ? DtroVehicleCharacteristics.fromMap(
              (data['vehicleCharacteristics'] as Map).cast<String, Object?>(),
            )
          : null,
      rate: data['rate'] is Map
          ? DtroRate.fromMap((data['rate'] as Map).cast<String, Object?>())
          : null,
      text: _string(data['text']),
    );
  }

  final DtroTimeValidity? timeValidity;
  final DtroVehicleCharacteristics? vehicleCharacteristics;
  final DtroRate? rate;
  final String? text;

  Map<String, Object?> toMap() => {
        'timeValidity': timeValidity?.toMap(),
        'vehicleCharacteristics': vehicleCharacteristics?.toMap(),
        'rate': rate?.toMap(),
        'text': text,
      };
}

class DtroProvision {
  const DtroProvision({
    required this.provisionId,
    required this.regulationType,
    this.conditions = const [],
    this.geometry,
    this.description,
  });

  factory DtroProvision.fromMap(Map<String, Object?> data) {
    return DtroProvision(
      provisionId: _string(data['provisionId']) ?? _string(data['id']) ?? '',
      regulationType: dtroRegulationTypeFromCode(
        _string(data['regulationType']) ?? _string(data['type']) ?? '',
      ),
      conditions: (data['conditions'] as List?)
              ?.whereType<Map>()
              .map((value) => DtroCondition.fromMap(
                    value.cast<String, Object?>(),
                  ))
              .toList() ??
          const [],
      geometry: data['geometry'] is Map
          ? DtroGeometry.fromMap((data['geometry'] as Map).cast())
          : null,
      description: _string(data['description']),
    );
  }

  final String provisionId;
  final DtroRegulationType regulationType;
  final List<DtroCondition> conditions;
  final DtroGeometry? geometry;
  final String? description;

  Map<String, Object?> toMap() => {
        'provisionId': provisionId,
        'regulationType': dtroRegulationTypeCode(regulationType),
        'conditions': conditions.map((condition) => condition.toMap()).toList(),
        'geometry': geometry?.toMap(),
        'description': description,
      };
}

class DtroVersionHistory {
  const DtroVersionHistory({
    required this.version,
    required this.updatedAt,
    this.reason,
    this.previousVersion,
  });

  factory DtroVersionHistory.fromMap(Map<String, Object?> data) {
    return DtroVersionHistory(
      version: _string(data['version']) ?? 'unknown',
      updatedAt: _timestampDate(data['updatedAt']) ?? DateTime.now().toUtc(),
      reason: _string(data['reason']),
      previousVersion: _string(data['previousVersion']),
    );
  }

  final String version;
  final DateTime updatedAt;
  final String? reason;
  final String? previousVersion;

  Map<String, Object?> toMap() => {
        'version': version,
        'updatedAt': Timestamp.fromDate(updatedAt),
        'reason': reason,
        'previousVersion': previousVersion,
      };
}

class TrafficRegulationOrder {
  const TrafficRegulationOrder({
    required this.troId,
    required this.authority,
    required this.source,
    required this.provisions,
    required this.rawDtroJson,
    required this.versionHistory,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String troId;
  final DtroAuthority authority;
  final DtroSource source;
  final List<DtroProvision> provisions;
  final Map<String, Object?> rawDtroJson;
  final List<DtroVersionHistory> versionHistory;
  final DtroSourceStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, Object?> toRawOrderMap() => {
        'troId': troId,
        'authority': authority.toMap(),
        'source': source.toMap(),
        'rawDtroJson': rawDtroJson,
        'versionHistory':
            versionHistory.map((history) => history.toMap()).toList(),
        'status': status.name,
        'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
        'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      };
}

class DtroLegalRecord {
  const DtroLegalRecord({
    required this.id,
    required this.troId,
    required this.provisionId,
    required this.authority,
    required this.source,
    required this.regulationType,
    required this.irisLabel,
    required this.irisExplanation,
    required this.conditions,
    required this.geometry,
    required this.confidence,
    required this.verificationStatus,
    required this.status,
    this.version,
    this.lastUpdatedAt,
    this.rawProvision,
  });

  factory DtroLegalRecord.fromMap(String id, Map<String, Object?> data) {
    return DtroLegalRecord(
      id: id,
      troId: _string(data['troId']) ?? '',
      provisionId: _string(data['provisionId']) ?? '',
      authority: data['authority'] is Map
          ? DtroAuthority.fromMap((data['authority'] as Map).cast())
          : const DtroAuthority(authorityId: '', name: 'Unknown authority'),
      source: data['source'] is Map
          ? DtroSource.fromMap((data['source'] as Map).cast())
          : const DtroSource(
              sourceId: '',
              sourceUrl: '',
              name: 'D-TRO source',
              status: DtroSourceStatus.unknown,
            ),
      regulationType:
          dtroRegulationTypeFromCode(_string(data['regulationType']) ?? ''),
      irisLabel: _string(data['irisLabel']) ?? 'Parking rule',
      irisExplanation: _string(data['irisExplanation']) ??
          'IRIS has not generated a plain English explanation yet.',
      conditions: (data['conditions'] as List?)
              ?.whereType<Map>()
              .map((value) => DtroCondition.fromMap(value.cast()))
              .toList() ??
          const [],
      geometry: data['geometry'] is Map
          ? DtroGeometry.fromMap((data['geometry'] as Map).cast())
          : null,
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
      verificationStatus: DtroVerificationStatus.values.firstWhere(
        (value) => value.name == data['verificationStatus'],
        orElse: () => DtroVerificationStatus.pending,
      ),
      status: DtroSourceStatus.values.firstWhere(
        (value) => value.name == data['status'],
        orElse: () => DtroSourceStatus.unknown,
      ),
      version: _string(data['version']),
      lastUpdatedAt: _timestampDate(data['lastUpdatedAt']),
      rawProvision:
          (data['rawProvision'] as Map?)?.cast<String, Object?>() ?? const {},
    );
  }

  final String id;
  final String troId;
  final String provisionId;
  final DtroAuthority authority;
  final DtroSource source;
  final DtroRegulationType regulationType;
  final String irisLabel;
  final String irisExplanation;
  final List<DtroCondition> conditions;
  final DtroGeometry? geometry;
  final double confidence;
  final DtroVerificationStatus verificationStatus;
  final DtroSourceStatus status;
  final String? version;
  final DateTime? lastUpdatedAt;
  final Map<String, Object?>? rawProvision;

  Map<String, Object?> toMap() => {
        'id': id,
        'troId': troId,
        'provisionId': provisionId,
        'authority': authority.toMap(),
        'source': source.toMap(),
        'regulationType': dtroRegulationTypeCode(regulationType),
        'irisLabel': irisLabel,
        'irisExplanation': irisExplanation,
        'conditions': conditions.map((condition) => condition.toMap()).toList(),
        'geometry': geometry?.toMap(),
        'confidence': confidence,
        'verificationStatus': verificationStatus.name,
        'status': status.name,
        'version': version,
        'lastUpdatedAt':
            lastUpdatedAt == null ? null : Timestamp.fromDate(lastUpdatedAt!),
        'rawProvision': rawProvision,
      };
}

DtroRegulationType dtroRegulationTypeFromCode(String code) {
  final normalized = code.trim();
  return DtroRegulationType.values.firstWhere(
    (value) => dtroRegulationTypeCode(value) == normalized,
    orElse: () => DtroRegulationType.other,
  );
}

String dtroRegulationTypeCode(DtroRegulationType type) {
  return switch (type) {
    DtroRegulationType.kerbsideNoWaiting => 'kerbsideNoWaiting',
    DtroRegulationType.kerbsideResidentParkingPlace =>
      'kerbsideResidentParkingPlace',
    DtroRegulationType.kerbsideLoadingBay => 'kerbsideLoadingBay',
    DtroRegulationType.kerbsideDisabledParkingPlace =>
      'kerbsideDisabledParkingPlace',
    DtroRegulationType.kerbsidePaidParkingPlace => 'kerbsidePaidParkingPlace',
    DtroRegulationType.kerbsidePermitParkingPlace =>
      'kerbsidePermitParkingPlace',
    DtroRegulationType.kerbsideSchoolKeepClear => 'kerbsideSchoolKeepClear',
    DtroRegulationType.kerbsideBusStopClearway => 'kerbsideBusStopClearway',
    DtroRegulationType.kerbsideTaxiRank => 'kerbsideTaxiRank',
    DtroRegulationType.movingBusLane => 'movingBusLane',
    DtroRegulationType.movingOneWay => 'movingOneWay',
    DtroRegulationType.movingNoEntry => 'movingNoEntry',
    DtroRegulationType.movingNoMotorVehicles => 'movingNoMotorVehicles',
    DtroRegulationType.speedLimit => 'speedLimit',
    DtroRegulationType.other => 'other',
  };
}

String dtroIrisLabel(DtroRegulationType type) {
  return switch (type) {
    DtroRegulationType.kerbsideNoWaiting => 'No waiting',
    DtroRegulationType.kerbsideResidentParkingPlace =>
      'Resident permit holders only',
    DtroRegulationType.kerbsideLoadingBay => 'Loading bay',
    DtroRegulationType.kerbsideDisabledParkingPlace =>
      'Disabled badge parking bay',
    DtroRegulationType.kerbsidePaidParkingPlace => 'Paid parking place',
    DtroRegulationType.kerbsidePermitParkingPlace => 'Permit parking place',
    DtroRegulationType.kerbsideSchoolKeepClear => 'School keep clear',
    DtroRegulationType.kerbsideBusStopClearway => 'Bus stop clearway',
    DtroRegulationType.kerbsideTaxiRank => 'Taxi rank',
    DtroRegulationType.movingBusLane => 'Bus lane restriction',
    DtroRegulationType.movingOneWay => 'One-way restriction',
    DtroRegulationType.movingNoEntry => 'No entry',
    DtroRegulationType.movingNoMotorVehicles => 'No motor vehicles',
    DtroRegulationType.speedLimit => 'Speed limit',
    DtroRegulationType.other => 'Legal traffic restriction',
  };
}

String dtroIrisExplanation(DtroRegulationType type) {
  return switch (type) {
    DtroRegulationType.kerbsideNoWaiting => 'No waiting is allowed here.',
    DtroRegulationType.kerbsideResidentParkingPlace =>
      'Resident permit holders only.',
    DtroRegulationType.kerbsideLoadingBay =>
      'This is a loading bay; check loading times and vehicle rules.',
    DtroRegulationType.kerbsideDisabledParkingPlace =>
      'This bay is reserved for disabled badge holders.',
    DtroRegulationType.kerbsidePaidParkingPlace =>
      'Parking is paid during the stated operating times.',
    DtroRegulationType.kerbsidePermitParkingPlace =>
      'A valid permit is required during the stated times.',
    DtroRegulationType.kerbsideSchoolKeepClear =>
      'School keep clear restrictions apply here.',
    DtroRegulationType.kerbsideBusStopClearway =>
      'Stopping is restricted at this bus stop clearway.',
    DtroRegulationType.kerbsideTaxiRank =>
      'This location is reserved as a taxi rank.',
    DtroRegulationType.movingBusLane => 'Bus lane rules apply here.',
    DtroRegulationType.movingOneWay =>
      'Traffic is restricted to one direction.',
    DtroRegulationType.movingNoEntry => 'Vehicles must not enter here.',
    DtroRegulationType.movingNoMotorVehicles =>
      'Motor vehicles are not permitted here.',
    DtroRegulationType.speedLimit => 'A speed limit applies here.',
    DtroRegulationType.other =>
      'A legal traffic restriction applies. Check the source order.',
  };
}

String? _string(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? _timestampDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
