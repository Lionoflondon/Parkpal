import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import '../../data/firestore_collections.dart';
import '../../firebase/parkpal_firebase_options.dart';
import 'aie_models.dart';
import 'aie_parser_engine.dart';

class AieImportEngine {
  AieImportEngine({
    FirebaseFirestore? firestore,
    AieParserEngine parser = const AieParserEngine(),
    AieFetchClient? fetchClient,
  })  : _firestore = firestore,
        _parser = parser,
        _fetchClient = fetchClient ?? const HttpAieFetchClient();

  final FirebaseFirestore? _firestore;
  final AieParserEngine _parser;
  final AieFetchClient _fetchClient;

  Future<AieImportResult> importOfficialSource({
    required AieSource source,
    required String rawData,
    String requestedBy = 'ParkPal Admin',
  }) async {
    final batchId = 'aie_${DateTime.now().toUtc().millisecondsSinceEpoch}';
    var resolved = await _resolveImportInputSafely(
      source: source,
      input: rawData,
    );
    final checksum = resolved.checksum;
    final messages = <String>[];
    var imported = 0;
    var changed = 0;
    var skipped = 0;
    var failed = 0;
    var conflicts = 0;
    var missions = 0;

    try {
      final firestore = await _safeFirestore();
      if (firestore == null) {
        return AieImportResult(
          batchId: batchId,
          imported: 0,
          changed: 0,
          skipped: 0,
          failed: 1,
          conflicts: 0,
          missionsCreated: 0,
          status: AieImportStatus.failed,
          messages: const ['Firestore unavailable.'],
        );
      }
      final sourceRef =
          firestore.collection(AieCollections.sources).doc(source.sourceId);
      messages.addAll(resolved.messages);
      if (!resolved.success) {
        failed++;
        await sourceRef.set({
          ...source.toMap(),
          'fetchUrl': resolved.fetchUrl,
          'canonicalSourceUrl': source.sourceUrl,
          'importStatus': AieImportStatus.failed.name,
          'lastFailedImport': FieldValue.serverTimestamp(),
          'nextScheduledCheck': Timestamp.fromDate(_nextCheck(source)),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await _deadLetter(
          firestore,
          batchId,
          source,
          resolved.messages.join(' '),
        );
        await _writeImportLog(
          firestore,
          batchId: batchId,
          source: source,
          status: AieImportStatus.failed,
          checksum: checksum,
          imported: imported,
          changed: changed,
          skipped: skipped,
          failed: failed,
          conflicts: conflicts,
          missions: missions,
          messages: messages,
          fetchUrl: resolved.fetchUrl,
          contentType: resolved.contentType,
          fetchedAt: resolved.fetchedAt,
          diagnostics: resolved.diagnostics,
        );
        return AieImportResult(
          batchId: batchId,
          imported: imported,
          changed: changed,
          skipped: skipped,
          failed: failed,
          conflicts: conflicts,
          missionsCreated: missions,
          status: AieImportStatus.failed,
          messages: messages,
        );
      }

      DocumentSnapshot<Map<String, dynamic>> existingSource;
      try {
        existingSource = await sourceRef.get();
      } catch (error, stackTrace) {
        failed++;
        final diagnostics = {
          ...resolved.diagnostics,
          ..._exceptionDiagnostics(
            source: source,
            input: rawData,
            failureStage: 'source_lookup',
            error: error,
            stackTrace: stackTrace,
            constructedUrl: resolved.fetchUrl,
          ),
        };
        messages.add('Source lookup failed: $error');
        await _writeImportLogSafely(
          firestore,
          batchId: batchId,
          source: source,
          status: AieImportStatus.failed,
          checksum: checksum,
          imported: imported,
          changed: changed,
          skipped: skipped,
          failed: failed,
          conflicts: conflicts,
          missions: missions,
          messages: messages,
          fetchUrl: resolved.fetchUrl,
          contentType: resolved.contentType,
          fetchedAt: resolved.fetchedAt,
          diagnostics: diagnostics,
        );
        return AieImportResult(
          batchId: batchId,
          imported: imported,
          changed: changed,
          skipped: skipped,
          failed: failed,
          conflicts: conflicts,
          missionsCreated: missions,
          status: AieImportStatus.failed,
          messages: messages,
        );
      }
      final previousChecksum = existingSource.data()?['checksum'] as String?;

      await _audit(firestore, 'import_started', {
        'batchId': batchId,
        'sourceId': source.sourceId,
        'requestedBy': requestedBy,
      });

      if (!source.enabled) {
        skipped++;
        await _writeImportLog(
          firestore,
          batchId: batchId,
          source: source,
          status: AieImportStatus.unchanged,
          checksum: checksum,
          imported: imported,
          changed: changed,
          skipped: skipped,
          failed: failed,
          conflicts: conflicts,
          missions: missions,
          messages: const ['Source disabled.'],
          fetchUrl: resolved.fetchUrl,
          contentType: resolved.contentType,
          fetchedAt: resolved.fetchedAt,
          diagnostics: resolved.diagnostics,
        );
        return AieImportResult(
          batchId: batchId,
          imported: imported,
          changed: changed,
          skipped: skipped,
          failed: failed,
          conflicts: conflicts,
          missionsCreated: missions,
          status: AieImportStatus.unchanged,
          messages: const ['Source disabled.'],
        );
      }

      if (isDuplicateChecksum(previousChecksum, checksum)) {
        skipped++;
        await sourceRef.set({
          ...source.toMap(),
          'checksum': checksum,
          'fetchUrl': resolved.fetchUrl,
          'canonicalSourceUrl': source.sourceUrl,
          'contentType': resolved.contentType,
          'fetchedAt': resolved.fetchedAt == null
              ? null
              : Timestamp.fromDate(resolved.fetchedAt!),
          'importStatus': AieImportStatus.unchanged.name,
          'nextScheduledCheck': Timestamp.fromDate(_nextCheck(source)),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await _writeImportLog(
          firestore,
          batchId: batchId,
          source: source,
          status: AieImportStatus.unchanged,
          checksum: checksum,
          imported: imported,
          changed: changed,
          skipped: skipped,
          failed: failed,
          conflicts: conflicts,
          missions: missions,
          messages: [
            ...messages,
            'Checksum unchanged. No records processed.',
          ],
          fetchUrl: resolved.fetchUrl,
          contentType: resolved.contentType,
          fetchedAt: resolved.fetchedAt,
          diagnostics: {
            ...resolved.diagnostics,
            'parserError': 'Duplicate checksum skipped.',
          },
        );
        return AieImportResult(
          batchId: batchId,
          imported: imported,
          changed: changed,
          skipped: skipped,
          failed: failed,
          conflicts: conflicts,
          missionsCreated: missions,
          status: AieImportStatus.unchanged,
          messages: [
            ...messages,
            'Checksum unchanged. No records processed.',
          ],
        );
      }

      final parserSource = _sourceWithDocumentType(
        source,
        resolved.documentType,
        resolved.fetchUrl ?? source.sourceUrl,
      );
      List<AieStructuredRestriction> restrictions;
      try {
        restrictions = _parser.parse(
          source: parserSource,
          rawData: resolved.body,
        );
      } catch (error, stackTrace) {
        failed++;
        final diagnostics = {
          ...resolved.diagnostics,
          ..._exceptionDiagnostics(
            source: source,
            input: rawData,
            failureStage: 'parser_execution',
            error: error,
            stackTrace: stackTrace,
            constructedUrl: resolved.fetchUrl,
          ),
          'failureLabel': 'Parser failed',
          'parserError': error.toString(),
        };
        messages.add('Parser failed: $error');
        await _deadLetter(firestore, batchId, source, error.toString());
        await _writeImportLogSafely(
          firestore,
          batchId: batchId,
          source: source,
          status: AieImportStatus.failed,
          checksum: checksum,
          imported: imported,
          changed: changed,
          skipped: skipped,
          failed: failed,
          conflicts: conflicts,
          missions: missions,
          messages: messages,
          fetchUrl: resolved.fetchUrl,
          contentType: resolved.contentType,
          fetchedAt: resolved.fetchedAt,
          diagnostics: diagnostics,
        );
        return AieImportResult(
          batchId: batchId,
          imported: imported,
          changed: changed,
          skipped: skipped,
          failed: failed,
          conflicts: conflicts,
          missionsCreated: missions,
          status: AieImportStatus.failed,
          messages: messages,
        );
      }
      if (restrictions.isEmpty) {
        failed++;
        final reason = _parserFailureMessage(resolved.documentType);
        messages.add(reason);
        resolved.diagnostics['parserError'] = reason;
        resolved.diagnostics['failureLabel'] = _failureLabelForReason(reason);
        resolved.diagnostics['failureStage'] = 'parser_execution';
        await _deadLetter(firestore, batchId, source, reason);
      }

      for (final restriction in restrictions) {
        try {
          final roadId = _roadId(restriction.council, restriction.roadName);
          final roadRef =
              firestore.collection(AieCollections.atlasRoads).doc(roadId);
          final roadSnapshot = await roadRef.get();
          final existingRules =
              (roadSnapshot.data()?['currentParkingRules'] as List?)
                      ?.whereType<Map>()
                      .map((value) => AieStructuredRestriction.fromMap(
                          value.cast<String, dynamic>()))
                      .toList(growable: false) ??
                  const <AieStructuredRestriction>[];
          final existingRule = existingRules
              .where((rule) => rule.ruleId == restriction.ruleId)
              .firstOrNull;

          final changeType = _changeType(existingRule, restriction);
          if (changeType == AieChangeType.unchanged) {
            skipped++;
            continue;
          }

          final conflictId = await _detectAndWriteConflict(
            firestore,
            roadId: roadId,
            batchId: batchId,
            incoming: restriction,
            existingRule: existingRule,
          );
          if (conflictId != null) {
            conflicts++;
            missions += await _createMission(
              firestore,
              roadId: roadId,
              restriction: restriction,
              reason: 'Conflict detected from official council import.',
              missionType: 'resolve_official_source_conflict',
            );
          }

          final nextRules = [
            ...existingRules.where((rule) => rule.ruleId != restriction.ruleId),
            restriction,
          ];
          final previousVersion =
              (roadSnapshot.data()?['version'] as num?)?.toInt() ?? 0;
          final version = previousVersion + 1;

          if (roadSnapshot.exists) {
            await roadRef.collection('versions').doc('$previousVersion').set({
              'version': previousVersion,
              'snapshot': roadSnapshot.data(),
              'timestamp': FieldValue.serverTimestamp(),
              'source': restriction.sourceUrl,
              'importReason': changeType.name,
              'changeSummary': _changeSummary(changeType, restriction),
            });
          }

          await roadRef.set({
            'roadId': roadId,
            'roadName': restriction.roadName,
            'council': restriction.council,
            'borough': restriction.borough,
            'country': 'UK',
            'currentParkingRules':
                nextRules.map((rule) => rule.toMap()).toList(growable: false),
            'previousVersion': previousVersion,
            'version': version,
            'confidence': conflictId == null
                ? AieConfidence.official.name
                : AieConfidence.conflict.name,
            'confidencePercent': conflictId == null ? 100 : 45,
            'councilSource': restriction.sourceUrl,
            'lastImported': FieldValue.serverTimestamp(),
            'lastCouncilUpdate': FieldValue.serverTimestamp(),
            'lastVerified': roadSnapshot.data()?['lastVerified'],
            'roadHealth': _roadHealth(conflictId == null, nextRules.length),
            'coverageScore': nextRules.isEmpty ? 0 : 100,
            'relatedEvidence': FieldValue.arrayUnion([batchId]),
            'activeConflicts':
                conflictId == null ? [] : FieldValue.arrayUnion([conflictId]),
            'nearbyRestrictions':
                nextRules.map((rule) => rule.restrictionType).toSet().toList(),
            'stalenessScore': 0,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          await _writeChangeRecord(
            firestore,
            batchId: batchId,
            source: source,
            roadId: roadId,
            restriction: restriction,
            changeType: changeType,
            conflictId: conflictId,
          );
          await _writeEvidenceRecord(
            firestore,
            batchId: batchId,
            roadId: roadId,
            restriction: restriction,
            changeType: changeType,
          );

          changed++;
          imported++;
          if (_needsVerification(changeType, conflictId)) {
            missions += await _createMission(
              firestore,
              roadId: roadId,
              restriction: restriction,
              reason: _changeSummary(changeType, restriction),
              missionType: _missionFor(changeType),
            );
          }
        } catch (error, stackTrace) {
          failed++;
          messages.add('Failed ${restriction.ruleId}: $error');
          resolved.diagnostics.addAll(_exceptionDiagnostics(
            source: source,
            input: rawData,
            failureStage: 'persistence',
            error: error,
            stackTrace: stackTrace,
            constructedUrl: resolved.fetchUrl,
          ));
          await _deadLetter(firestore, batchId, source, error.toString());
        }
      }

      final status = failed > 0 && imported == 0
          ? AieImportStatus.failed
          : imported == 0
              ? AieImportStatus.unchanged
              : AieImportStatus.imported;
      await sourceRef.set({
        ...source.toMap(),
        'checksum': checksum,
        'fetchUrl': resolved.fetchUrl,
        'canonicalSourceUrl': source.sourceUrl,
        'contentType': resolved.contentType,
        'fetchedAt': resolved.fetchedAt == null
            ? null
            : Timestamp.fromDate(resolved.fetchedAt!),
        'version': (source.version + (imported > 0 ? 1 : 0)),
        'confidence': imported > 0 ? 1.0 : source.confidence,
        'importStatus': status.name,
        'lastSuccessfulImport': status == AieImportStatus.failed
            ? null
            : FieldValue.serverTimestamp(),
        'lastFailedImport': status == AieImportStatus.failed
            ? FieldValue.serverTimestamp()
            : null,
        'nextScheduledCheck': Timestamp.fromDate(_nextCheck(source)),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _writeImportLog(
        firestore,
        batchId: batchId,
        source: source,
        status: status,
        checksum: checksum,
        imported: imported,
        changed: changed,
        skipped: skipped,
        failed: failed,
        conflicts: conflicts,
        missions: missions,
        messages: messages,
        fetchUrl: resolved.fetchUrl,
        contentType: resolved.contentType,
        fetchedAt: resolved.fetchedAt,
        diagnostics: resolved.diagnostics,
      );
      await _audit(firestore, 'import_finished', {
        'batchId': batchId,
        'sourceId': source.sourceId,
        'imported': imported,
        'changed': changed,
        'failed': failed,
        'conflicts': conflicts,
        'missionsCreated': missions,
      });
      return AieImportResult(
        batchId: batchId,
        imported: imported,
        changed: changed,
        skipped: skipped,
        failed: failed,
        conflicts: conflicts,
        missionsCreated: missions,
        status: status,
        messages: messages,
      );
    } catch (error, stackTrace) {
      final firestore = await _safeFirestore();
      final diagnostics = {
        ...resolved.diagnostics,
        ..._exceptionDiagnostics(
          source: source,
          input: rawData,
          failureStage: 'unknown',
          error: error,
          stackTrace: stackTrace,
          constructedUrl: resolved.fetchUrl,
        ),
      };
      if (firestore != null) {
        await _writeImportLogSafely(
          firestore,
          batchId: batchId,
          source: source,
          status: AieImportStatus.failed,
          checksum: checksum,
          imported: imported,
          changed: changed,
          skipped: skipped,
          failed: failed + 1,
          conflicts: conflicts,
          missions: missions,
          messages: [...messages, 'Import failed: $error'],
          fetchUrl: resolved.fetchUrl,
          contentType: resolved.contentType,
          fetchedAt: resolved.fetchedAt,
          diagnostics: diagnostics,
        );
      }
      return AieImportResult(
        batchId: batchId,
        imported: imported,
        changed: changed,
        skipped: skipped,
        failed: failed + 1,
        conflicts: conflicts,
        missionsCreated: missions,
        status: AieImportStatus.failed,
        messages: [...messages, 'Import failed: $error'],
      );
    }
  }

  Future<AieResolvedImportInput> _resolveImportInputSafely({
    required AieSource source,
    required String input,
  }) async {
    try {
      return await resolveImportInput(source: source, input: input);
    } catch (error, stackTrace) {
      return AieResolvedImportInput.failure(
        checksum: _checksum(input),
        messages: ['Import validation failed before fetch: $error'],
        documentType: source.documentType,
        diagnostics: _exceptionDiagnostics(
          source: source,
          input: input,
          failureStage: 'validation',
          error: error,
          stackTrace: stackTrace,
          constructedUrl: input.trim().startsWith('http')
              ? input.trim()
              : source.sourceUrl.trim(),
        ),
      );
    }
  }

  Future<AieResolvedImportInput> resolveImportInput({
    required AieSource source,
    required String input,
  }) async {
    final trimmed = input.trim();
    final sourceUrl = source.sourceUrl.trim();
    final baseDiagnostics = _baseDiagnostics(
      source: source,
      input: input,
      constructedUrl: trimmed.startsWith('http') ? trimmed : sourceUrl,
    );
    if (sourceUrl.isEmpty && trimmed.isEmpty) {
      return AieResolvedImportInput.failure(
        checksum: _checksum(''),
        messages: const ['Missing source URL.'],
        documentType: source.documentType,
        diagnostics: {
          ...baseDiagnostics,
          'failureStage': 'url_build',
          'failureLabel': 'Missing source URL',
          'selectedParser': source.documentType.name,
          'responseSize': 0,
        },
      );
    }
    if (trimmed.isEmpty) {
      return AieResolvedImportInput.failure(
        checksum: _checksum(''),
        messages: const ['Empty response: paste data or a download URL.'],
        documentType: source.documentType,
        diagnostics: {
          ...baseDiagnostics,
          'failureStage': 'validation',
          'failureLabel': 'Empty response',
          'selectedParser': source.documentType.name,
          'responseSize': 0,
        },
      );
    }

    final inputUri = Uri.tryParse(trimmed);
    final isUrl = inputUri != null &&
        (inputUri.scheme == 'http' || inputUri.scheme == 'https') &&
        inputUri.host.isNotEmpty;

    if (!isUrl) {
      final warnings = _councilWarnings(source, trimmed, null);
      return AieResolvedImportInput.success(
        body: trimmed,
        checksum: _checksum(trimmed),
        messages: warnings,
        documentType: source.documentType,
        diagnostics: {
          ...baseDiagnostics,
          'inputMode': 'raw',
          'selectedParser': source.documentType.name,
          'responseSize': trimmed.length,
          'responsePreview': _preview(trimmed),
        },
      );
    }

    try {
      final preflight = await _preflightSource(source, inputUri);
      var preflightDiagnostics = {
        ...baseDiagnostics,
        ...preflight.diagnostics,
      };
      if (!preflight.valid) {
        return AieResolvedImportInput.failure(
          checksum: _checksum(trimmed),
          fetchUrl: preflight.fetchUri.toString(),
          messages: preflight.messages,
          documentType: preflight.selectedDocumentType,
          diagnostics: {
            ...preflightDiagnostics,
            'failureStage': 'validation',
            'failureLabel': 'Configuration error',
          },
        );
      }
      var response = await _fetchClient.get(preflight.fetchUri);
      var selectedDocumentType = preflight.selectedDocumentType;
      var selectedFormat = _exportFormatForDocumentType(selectedDocumentType);
      if (response.statusCode != 200 &&
          _isUnavailableExportResponse(response)) {
        final fallback = _nextFallbackPreflight(preflight);
        if (fallback != null) {
          response = await _fetchClient.get(fallback.fetchUri);
          selectedDocumentType = fallback.selectedDocumentType;
          selectedFormat = _exportFormatForDocumentType(selectedDocumentType);
          preflight.messages.add(
            'Selected export format was unavailable; retried as $selectedFormat.',
          );
          preflight.diagnostics.addAll(fallback.diagnostics);
          preflightDiagnostics = {
            ...baseDiagnostics,
            ...preflight.diagnostics,
          };
        }
      }
      if (response.unreachable) {
        return AieResolvedImportInput.failure(
          checksum: _checksum(trimmed),
          fetchUrl: preflight.fetchUri.toString(),
          messages: const ['URL unreachable.'],
          documentType: selectedDocumentType,
          diagnostics: {
            ...preflightDiagnostics,
            'failureStage': 'http_fetch',
            'failureLabel': 'URL unreachable',
            'fetchUrl': preflight.fetchUri.toString(),
            'constructedUrl': preflight.fetchUri.toString(),
            'selectedParser': selectedDocumentType.name,
            'responseSize': 0,
          },
        );
      }
      if (response.statusCode != 200) {
        return AieResolvedImportInput.failure(
          checksum: _checksum(trimmed),
          fetchUrl: response.finalUrl ?? preflight.fetchUri.toString(),
          contentType: response.contentType,
          messages: ['HTTP ${response.statusCode}.'],
          documentType: selectedDocumentType,
          diagnostics: {
            ...preflightDiagnostics,
            'failureStage': 'http_fetch',
            'failureLabel': 'HTTP ${response.statusCode}',
            'fetchUrl': preflight.fetchUri.toString(),
            'constructedUrl': preflight.fetchUri.toString(),
            'finalUrl': response.finalUrl ?? preflight.fetchUri.toString(),
            'httpStatus': response.statusCode,
            'contentType': response.contentType,
            'selectedParser': selectedDocumentType.name,
            'responseSize': response.body.length,
            'responsePreview': _preview(response.body),
          },
        );
      }
      if (response.body.trim().isEmpty) {
        return AieResolvedImportInput.failure(
          checksum: _checksum(''),
          fetchUrl: response.finalUrl ?? preflight.fetchUri.toString(),
          contentType: response.contentType,
          messages: const ['Empty response.'],
          documentType: selectedDocumentType,
          diagnostics: {
            ...preflightDiagnostics,
            'failureStage': 'validation',
            'failureLabel': 'Empty response',
            'fetchUrl': preflight.fetchUri.toString(),
            'constructedUrl': preflight.fetchUri.toString(),
            'finalUrl': response.finalUrl ?? preflight.fetchUri.toString(),
            'httpStatus': response.statusCode,
            'contentType': response.contentType,
            'selectedParser': selectedDocumentType.name,
            'responseSize': 0,
          },
        );
      }

      final contentType = response.contentType;
      final messages = [
        ...preflight.messages,
        'Fetched official download URL.',
        ..._hardContentTypeFailures(selectedDocumentType, contentType),
        ..._contentTypeWarnings(selectedDocumentType, contentType),
        ..._councilWarnings(
          source,
          response.body,
          response.finalUrl ?? preflight.fetchUri.toString(),
        ),
      ];
      final htmlCsvMismatch = selectedDocumentType == AieDocumentType.csv &&
          _looksHtml(contentType);
      return AieResolvedImportInput.success(
        body: response.body,
        checksum: _checksum(response.body),
        fetchUrl: response.finalUrl ?? preflight.fetchUri.toString(),
        contentType: contentType,
        fetchedAt: DateTime.now().toUtc(),
        messages: messages,
        documentType: selectedDocumentType,
        diagnostics: {
          ...preflightDiagnostics,
          'inputMode': 'url',
          'fetchUrl': preflight.fetchUri.toString(),
          'constructedUrl': preflight.fetchUri.toString(),
          'finalUrl': response.finalUrl ?? preflight.fetchUri.toString(),
          'httpStatus': response.statusCode,
          'contentType': contentType,
          'selectedParser': selectedDocumentType.name,
          'selectedExportFormat': selectedFormat,
          'responseSize': response.body.length,
          'responsePreview': _preview(response.body),
          if (htmlCsvMismatch) 'failureStage': 'parser_selection',
          if (htmlCsvMismatch) 'failureLabel': 'Returned HTML not CSV',
          if (htmlCsvMismatch) 'parserError': 'Returned HTML not CSV.',
        },
      );
    } catch (error, stackTrace) {
      return AieResolvedImportInput.failure(
        checksum: _checksum(trimmed),
        fetchUrl: inputUri.toString(),
        messages: ['URL unreachable: $error'],
        documentType: source.documentType,
        diagnostics: {
          ...baseDiagnostics,
          ..._exceptionDiagnostics(
            source: source,
            input: input,
            failureStage: 'http_fetch',
            error: error,
            stackTrace: stackTrace,
            constructedUrl: inputUri.toString(),
          ),
          'failureLabel': 'URL unreachable',
          'fetchUrl': inputUri.toString(),
          'constructedUrl': inputUri.toString(),
          'selectedParser': source.documentType.name,
          'parserError': error.toString(),
          'responseSize': 0,
        },
      );
    }
  }

  bool isDuplicateChecksum(String? previousChecksum, String checksum) {
    return previousChecksum != null && previousChecksum == checksum;
  }

  Future<List<AieSource>> fetchSources({int limit = 50}) async {
    try {
      final firestore = await _safeFirestore();
      if (firestore == null) return const [];
      final snapshot = await firestore
          .collection(AieCollections.sources)
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((doc) => AieSource.fromMap(doc.id, doc.data()))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<AieDashboardSummary> fetchDashboardSummary() async {
    try {
      final firestore = await _safeFirestore();
      if (firestore == null) return AieDashboardSummary.empty;
      final counts = await Future.wait<int>([
        _count(firestore, AieCollections.sources),
        _count(
          firestore,
          AieCollections.sources,
          field: 'importStatus',
          value: AieImportStatus.queued.name,
        ),
        _count(
          firestore,
          AieCollections.sources,
          field: 'importStatus',
          value: AieImportStatus.failed.name,
        ),
        _count(firestore, AieCollections.importLogs),
        _count(
          firestore,
          AieCollections.conflicts,
          field: 'state',
          values: [
            AieConflictState.pending.name,
            AieConflictState.needsReview.name
          ],
        ),
        _count(
          firestore,
          AieCollections.atlasRoads,
          field: 'confidence',
          value: AieConfidence.limited.name,
        ),
        _count(firestore, AieCollections.atlasRoads,
            field: 'stale', value: true),
        _count(
          firestore,
          'parkpal_pioneer_missions',
          field: 'status',
          value: 'open',
        ),
      ]);

      final logs = await firestore
          .collection(AieCollections.importLogs)
          .orderBy('createdAt', descending: true)
          .limit(8)
          .get();
      final changes = await firestore
          .collection(AieCollections.changeRecords)
          .orderBy('createdAt', descending: true)
          .limit(8)
          .get();

      return AieDashboardSummary(
        connectedCouncils: counts[0],
        importQueue: counts[1],
        failedImports: counts[2],
        importLogs: counts[3],
        pendingConflicts: counts[4],
        pendingVerification: counts[5],
        staleRoads: counts[6],
        missionQueue: counts[7],
        councilStatus:
            counts[2] == 0 ? 'Official sources healthy' : 'Sources need review',
        recentLogs: logs.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList(growable: false),
        recentChanges: changes.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList(growable: false),
      );
    } catch (_) {
      return AieDashboardSummary.empty;
    }
  }

  Future<FirebaseFirestore?> _safeFirestore() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: ParkPalFirebaseOptions.web);
      }
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  AieChangeType _changeType(
    AieStructuredRestriction? previous,
    AieStructuredRestriction incoming,
  ) {
    if (previous == null) return AieChangeType.newRestriction;
    if (previous.activeHours != incoming.activeHours) {
      return AieChangeType.changedHours;
    }
    if (previous.permitRequired != incoming.permitRequired) {
      return AieChangeType.permitChange;
    }
    if (incoming.temporaryRestriction == true) {
      return AieChangeType.temporarySuspension;
    }
    if (incoming.restrictionType.toLowerCase().contains('bay') &&
        previous.restrictionType != incoming.restrictionType) {
      return AieChangeType.newParkingBay;
    }
    if (previous.toMap().toString() == incoming.toMap().toString()) {
      return AieChangeType.unchanged;
    }
    return AieChangeType.cpzAmendment;
  }

  Future<String?> _detectAndWriteConflict(
    FirebaseFirestore firestore, {
    required String roadId,
    required String batchId,
    required AieStructuredRestriction incoming,
    required AieStructuredRestriction? existingRule,
  }) async {
    final existingConflict = existingRule != null &&
        existingRule.parkingAllowed != null &&
        incoming.parkingAllowed != null &&
        existingRule.parkingAllowed != incoming.parkingAllowed;

    final signs = await firestore
        .collection(ParkPalCollections.signs)
        .where('streetName', isEqualTo: incoming.roadName)
        .where('verificationStatus', isEqualTo: 'verified')
        .limit(10)
        .get();
    final signConflict = signs.docs.any((doc) {
      final data = doc.data();
      final signParkingAllowed = data['parkingAllowed'] as bool?;
      return signParkingAllowed != null &&
          incoming.parkingAllowed != null &&
          signParkingAllowed != incoming.parkingAllowed;
    });

    if (!existingConflict && !signConflict) return null;
    final conflictId = '${roadId}_${incoming.ruleId}_$batchId';
    await firestore.collection(AieCollections.conflicts).doc(conflictId).set({
      'conflictId': conflictId,
      'roadId': roadId,
      'roadName': incoming.roadName,
      'state': AieConflictState.pending.name,
      'sourceId': incoming.sourceId,
      'sourceUrl': incoming.sourceUrl,
      'incomingRule': incoming.toMap(),
      'existingRule': existingRule?.toMap(),
      'verifiedSignIds': signs.docs.map((doc) => doc.id).toList(),
      'conflictNotes':
          'Official source conflicts with existing Atlas intelligence or verified field evidence. Verified data was not overwritten silently.',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return conflictId;
  }

  Future<int> _createMission(
    FirebaseFirestore firestore, {
    required String roadId,
    required AieStructuredRestriction restriction,
    required String reason,
    required String missionType,
  }) async {
    final missionId = '${roadId}_${missionType}_${restriction.ruleId}';
    await firestore.collection('parkpal_pioneer_missions').doc(missionId).set({
      'missionId': missionId,
      'roadId': roadId,
      'roadName': restriction.roadName,
      'borough': restriction.borough,
      'council': restriction.council,
      'missionType': missionType,
      'title': _missionTitle(missionType, restriction.roadName),
      'description': reason,
      'status': 'open',
      'priority': missionType.contains('conflict') ? 'critical' : 'high',
      'source': 'atlas_intelligence_engine',
      'rewardRoth': 1,
      'subscriptionCreditGbp': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return 1;
  }

  Future<void> _writeChangeRecord(
    FirebaseFirestore firestore, {
    required String batchId,
    required AieSource source,
    required String roadId,
    required AieStructuredRestriction restriction,
    required AieChangeType changeType,
    required String? conflictId,
  }) async {
    final changeId = '${batchId}_${restriction.ruleId}';
    await firestore.collection(AieCollections.changeRecords).doc(changeId).set({
      'changeId': changeId,
      'batchId': batchId,
      'sourceId': source.sourceId,
      'sourceUrl': source.sourceUrl,
      'council': source.council,
      'roadId': roadId,
      'roadName': restriction.roadName,
      'changeType': changeType.name,
      'changeSummary': _changeSummary(changeType, restriction),
      'structuredRule': restriction.toMap(),
      'conflictId': conflictId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _writeEvidenceRecord(
    FirebaseFirestore firestore, {
    required String batchId,
    required String roadId,
    required AieStructuredRestriction restriction,
    required AieChangeType changeType,
  }) async {
    await firestore
        .collection('parkpalEvidenceRecords')
        .doc(
          '${batchId}_${restriction.ruleId}',
        )
        .set({
      'recordId': '${batchId}_${restriction.ruleId}',
      'roadId': roadId,
      'roadName': restriction.roadName,
      'source': 'official_council_import',
      'sourceId': restriction.sourceId,
      'sourceUrl': restriction.sourceUrl,
      'changeType': changeType.name,
      'summary': _changeSummary(changeType, restriction),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _writeImportLog(
    FirebaseFirestore firestore, {
    required String batchId,
    required AieSource source,
    required AieImportStatus status,
    required String checksum,
    required int imported,
    required int changed,
    required int skipped,
    required int failed,
    required int conflicts,
    required int missions,
    required List<String> messages,
    String? fetchUrl,
    String? contentType,
    DateTime? fetchedAt,
    Map<String, Object?> diagnostics = const {},
  }) async {
    await firestore.collection(AieCollections.importLogs).doc(batchId).set({
      'batchId': batchId,
      'sourceId': source.sourceId,
      'sourceUrl': source.sourceUrl,
      'council': source.council,
      'status': status.name,
      'checksum': checksum,
      'canonicalSourceUrl': source.sourceUrl,
      'fetchUrl': fetchUrl,
      'contentType': contentType,
      'fetchedAt': fetchedAt == null ? null : Timestamp.fromDate(fetchedAt),
      'imported': imported,
      'changed': changed,
      'skipped': skipped,
      'failed': failed,
      'conflicts': conflicts,
      'missionsCreated': missions,
      'messages': messages,
      'diagnostics': {
        ...diagnostics,
        'timestamp': FieldValue.serverTimestamp(),
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _writeImportLogSafely(
    FirebaseFirestore firestore, {
    required String batchId,
    required AieSource source,
    required AieImportStatus status,
    required String checksum,
    required int imported,
    required int changed,
    required int skipped,
    required int failed,
    required int conflicts,
    required int missions,
    required List<String> messages,
    String? fetchUrl,
    String? contentType,
    DateTime? fetchedAt,
    Map<String, Object?> diagnostics = const {},
  }) async {
    try {
      await _writeImportLog(
        firestore,
        batchId: batchId,
        source: source,
        status: status,
        checksum: checksum,
        imported: imported,
        changed: changed,
        skipped: skipped,
        failed: failed,
        conflicts: conflicts,
        missions: missions,
        messages: messages,
        fetchUrl: fetchUrl,
        contentType: contentType,
        fetchedAt: fetchedAt,
        diagnostics: diagnostics,
      );
    } catch (_) {
      // Diagnostics must never crash the Admin import flow.
    }
  }

  Future<void> _deadLetter(
    FirebaseFirestore firestore,
    String batchId,
    AieSource source,
    String reason,
  ) async {
    await firestore.collection(AieCollections.deadLetters).doc().set({
      'batchId': batchId,
      'sourceId': source.sourceId,
      'sourceUrl': source.sourceUrl,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _audit(
    FirebaseFirestore firestore,
    String action,
    Map<String, Object?> data,
  ) async {
    await firestore.collection(AieCollections.auditLogs).doc().set({
      'action': action,
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<int> _count(
    FirebaseFirestore firestore,
    String collection, {
    String? field,
    Object? value,
    List<Object?>? values,
  }) async {
    Query<Map<String, dynamic>> query = firestore.collection(collection);
    if (field != null && values != null) {
      query = query.where(field, whereIn: values);
    } else if (field != null) {
      query = query.where(field, isEqualTo: value);
    }
    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
  }

  bool _needsVerification(AieChangeType changeType, String? conflictId) {
    return conflictId != null ||
        {
          AieChangeType.newRestriction,
          AieChangeType.changedHours,
          AieChangeType.newParkingBay,
          AieChangeType.removedBay,
          AieChangeType.permitChange,
          AieChangeType.temporarySuspension,
          AieChangeType.roadClosure,
          AieChangeType.cpzAmendment,
        }.contains(changeType);
  }

  String _missionFor(AieChangeType changeType) {
    return switch (changeType) {
      AieChangeType.changedHours => 'verify_changed_hours',
      AieChangeType.temporarySuspension => 'confirm_suspension',
      AieChangeType.roadClosure => 'confirm_road_closure',
      AieChangeType.permitChange => 'confirm_permit_change',
      AieChangeType.newParkingBay => 'photograph_new_bay',
      AieChangeType.removedBay => 'confirm_removed_bay',
      _ => 'verify_official_restriction',
    };
  }

  String _missionTitle(String missionType, String roadName) {
    if (missionType.contains('conflict')) {
      return 'Resolve conflict on $roadName';
    }
    if (missionType.contains('suspension')) {
      return 'Confirm suspension on $roadName';
    }
    if (missionType.contains('bay')) {
      return 'Photograph parking bay on $roadName';
    }
    return 'Verify $roadName';
  }

  String _parserFailureMessage(AieDocumentType documentType) {
    return switch (documentType) {
      AieDocumentType.csv =>
        'Invalid CSV headers: no valid rows found. Check headers such as roadName/streetName and restrictionType.',
      AieDocumentType.json => 'Invalid JSON: parser found no valid records.',
      AieDocumentType.geojson =>
        'Invalid GeoJSON: parser found no valid features.',
      AieDocumentType.xml ||
      AieDocumentType.rss =>
        'Invalid XML/RSS: parser found no parking restrictions.',
      AieDocumentType.html =>
        'Parser failed: HTML did not contain recognisable parking restrictions.',
      AieDocumentType.pdf ||
      AieDocumentType.docx =>
        'Unsupported document type for direct URL parsing: extract text first or connect a document parser.',
    };
  }

  String _failureLabelForReason(String reason) {
    final lower = reason.toLowerCase();
    if (lower.contains('invalid csv')) return 'Invalid CSV headers';
    if (lower.contains('invalid json')) return 'Invalid JSON';
    if (lower.contains('invalid geojson')) return 'Invalid GeoJSON';
    if (lower.contains('invalid xml') || lower.contains('rss')) {
      return 'Invalid XML';
    }
    if (lower.contains('html')) return 'Returned HTML not CSV';
    if (lower.contains('duplicate')) return 'Duplicate checksum skipped';
    return 'Parser failed';
  }

  List<String> _hardContentTypeFailures(
    AieDocumentType selected,
    String? contentType,
  ) {
    if (contentType == null) return const [];
    if (selected == AieDocumentType.csv && _looksHtml(contentType)) {
      return const ['Returned HTML not CSV.'];
    }
    return const [];
  }

  List<String> _contentTypeWarnings(
    AieDocumentType selected,
    String? contentType,
  ) {
    if (contentType == null || contentType.isEmpty) return const [];
    final lower = contentType.toLowerCase();
    final looksCsv = lower.contains('csv') || lower.contains('text/plain');
    final looksJson = lower.contains('json');
    final looksXml = lower.contains('xml') || lower.contains('rss');
    final looksHtml = lower.contains('html');
    final matches = switch (selected) {
      AieDocumentType.csv => looksCsv,
      AieDocumentType.json || AieDocumentType.geojson => looksJson,
      AieDocumentType.xml || AieDocumentType.rss => looksXml,
      AieDocumentType.html => looksHtml,
      AieDocumentType.pdf => lower.contains('pdf'),
      AieDocumentType.docx =>
        lower.contains('word') || lower.contains('officedocument'),
    };
    if (matches) return const [];
    return [
      'Unsupported document type warning: response content-type "$contentType" may not match selected ${selected.name.toUpperCase()}.',
    ];
  }

  bool _looksHtml(String? contentType) {
    return contentType?.toLowerCase().contains('html') ?? false;
  }

  List<String> _councilWarnings(
    AieSource source,
    String body,
    String? url,
  ) {
    final selected = source.council.toLowerCase();
    final previewLength = body.length > 5000 ? 5000 : body.length;
    final haystack =
        '${url ?? ''}\n${body.substring(0, previewLength)}'.toLowerCase();
    const councils = {
      'westminster': 'Westminster',
      'camden': 'Camden',
      'kensington': 'Kensington and Chelsea',
      'chelsea': 'Kensington and Chelsea',
      'islington': 'Islington',
      'lambeth': 'Lambeth',
    };
    final selectedKey =
        councils.keys.where((key) => selected.contains(key)).firstOrNull;
    final indicated = councils.keys.where((key) => haystack.contains(key));
    final mismatch = indicated
        .where((key) => selectedKey == null || key != selectedKey)
        .toList(growable: false);
    if (mismatch.isEmpty) return const [];
    return const ['Selected council may not match source dataset.'];
  }

  String _changeSummary(
    AieChangeType changeType,
    AieStructuredRestriction restriction,
  ) {
    return '${changeType.name}: ${restriction.restrictionType} on ${restriction.roadName} (${restriction.activeHours}).';
  }

  int _roadHealth(bool conflictFree, int ruleCount) {
    final base = ruleCount > 0 ? 88 : 35;
    return conflictFree ? base : 45;
  }

  DateTime _nextCheck(AieSource source) {
    final now = DateTime.now().toUtc();
    return switch (source.sourceType) {
      AieSourceType.parkingSuspension ||
      AieSourceType.temporaryTrafficOrder ||
      AieSourceType.roadClosure =>
        now.add(const Duration(hours: 1)),
      AieSourceType.openDataApi ||
      AieSourceType.trafficRegulationOrder ||
      AieSourceType.controlledParkingZone =>
        now.add(const Duration(days: 1)),
      _ => now.add(const Duration(days: 7)),
    };
  }

  String _roadId(String council, String roadName) {
    return '${_safe(council)}_${_safe(roadName)}';
  }

  String _safe(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  String _checksum(String value) {
    var hash = 5381;
    for (final code in value.codeUnits) {
      hash = ((hash << 5) + hash + code) & 0x7fffffff;
    }
    return hash.toRadixString(16);
  }

  String _preview(String value) {
    final cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= 300) return cleaned;
    return cleaned.substring(0, 300);
  }

  Map<String, Object?> _baseDiagnostics({
    required AieSource source,
    required String input,
    String? constructedUrl,
  }) {
    return {
      'sourceId': source.sourceId,
      'sourceName': source.sourceName ?? source.sourceId,
      'originalSourceUrl': source.sourceUrl,
      'constructedUrl': constructedUrl,
      'selectedParser': source.documentType.name,
      'diagnosticsTimestamp': DateTime.now().toUtc().toIso8601String(),
      'inputSize': input.length,
    };
  }

  Map<String, Object?> _exceptionDiagnostics({
    required AieSource source,
    required String input,
    required String failureStage,
    required Object error,
    required StackTrace stackTrace,
    String? constructedUrl,
  }) {
    return {
      ..._baseDiagnostics(
        source: source,
        input: input,
        constructedUrl: constructedUrl,
      ),
      'failureStage': failureStage,
      'exceptionType': error.runtimeType.toString(),
      'exceptionMessage': error.toString(),
      'stackTrace':
          stackTrace.toString().split('\n').take(20).join('\n').trim(),
    };
  }

  AieSource _sourceWithDocumentType(
    AieSource source,
    AieDocumentType documentType,
    String sourceUrl,
  ) {
    return AieSource(
      sourceId: source.sourceId,
      sourceName: source.sourceName,
      sourceUrl: sourceUrl,
      council: source.council,
      sourceType: source.sourceType,
      documentType: documentType,
      lastSuccessfulImport: source.lastSuccessfulImport,
      lastFailedImport: source.lastFailedImport,
      nextScheduledCheck: source.nextScheduledCheck,
      importStatus: source.importStatus,
      checksum: source.checksum,
      version: source.version,
      confidence: source.confidence,
      enabled: source.enabled,
    );
  }

  Future<_AieSourcePreflight> _preflightSource(
    AieSource source,
    Uri inputUri,
  ) async {
    final datasetId = _datasetIdFromUri(inputUri);
    final host = inputUri.host;
    final sourceAuthority = _authorityFromCouncil(source.council);
    var authority = _authorityFromHost(host);
    final messages = <String>[];
    final diagnostics = <String, Object?>{
      'authority': authority,
      'datasetId': datasetId,
      'host': host,
    };

    if (datasetId == null) {
      final documentType = source.documentType;
      return _AieSourcePreflight(
        valid: true,
        fetchUri: inputUri,
        selectedDocumentType: documentType,
        availableDocumentTypes: [documentType],
        messages: messages,
        diagnostics: {
          ...diagnostics,
          'selectedExportFormat': _exportFormatForDocumentType(documentType),
          'availableExportFormats': _exportFormatForDocumentType(documentType),
        },
      );
    }

    final metadataUri = Uri(
      scheme: inputUri.scheme,
      host: host,
      path: '/api/views/$datasetId.json',
    );
    diagnostics['metadataUrl'] = metadataUri.toString();
    final metadataResponse = await _fetchClient.get(metadataUri);
    if (!metadataResponse.unreachable && metadataResponse.statusCode == 200) {
      final metadata = _decodeJsonMap(metadataResponse.body);
      authority = _authorityFromMetadata(metadata) ?? authority;
      diagnostics['authority'] = authority;
      diagnostics['metadataContentType'] = metadataResponse.contentType;
      diagnostics['metadataResponseSize'] = metadataResponse.body.length;
      diagnostics['metadataPreview'] = _preview(metadataResponse.body);
      final metadataFormats = _formatsFromMetadata(metadata);
      if (metadataFormats.isNotEmpty) {
        diagnostics['availableExportFormats'] =
            metadataFormats.map(_exportFormatForDocumentType).join(', ');
      }
    } else {
      diagnostics['metadataHttpStatus'] = metadataResponse.statusCode;
      diagnostics['metadataContentType'] = metadataResponse.contentType;
      diagnostics['metadataPreview'] = _preview(metadataResponse.body);
    }

    final mismatch = _authorityMismatch(
      sourceAuthority,
      authority,
      host,
      inputUri.path,
    );
    if (mismatch != null) {
      return _AieSourcePreflight(
        valid: false,
        fetchUri: inputUri,
        selectedDocumentType: source.documentType,
        availableDocumentTypes: const [],
        messages: [mismatch],
        diagnostics: {
          ...diagnostics,
          'failureLabel': 'Configuration error',
          'configurationError': mismatch,
          'configuredAuthority': sourceAuthority,
          'detectedAuthority': authority,
        },
      );
    }

    final available =
        _availableFormatsFromDiagnostics(diagnostics).toList(growable: true);
    if (available.isEmpty) {
      available.addAll(const [
        AieDocumentType.csv,
        AieDocumentType.json,
        AieDocumentType.geojson,
      ]);
    }
    final orderedAvailable = _orderedFormats(available);
    final selected = _selectPreferredFormat(orderedAvailable);
    final fetchUri = _exportUriForFormat(inputUri, datasetId, selected);
    diagnostics
      ..['selectedExportFormat'] = _exportFormatForDocumentType(selected)
      ..['availableExportFormats'] =
          orderedAvailable.map(_exportFormatForDocumentType).join(', ')
      ..['constructedUrl'] = fetchUri.toString()
      ..['resolvedEndpoint'] = fetchUri.toString();
    if (selected != source.documentType) {
      messages.add(
        'Configured ${source.documentType.name.toUpperCase()} export is not preferred/available; selected ${selected.name.toUpperCase()} automatically.',
      );
    }

    return _AieSourcePreflight(
      valid: true,
      fetchUri: fetchUri,
      selectedDocumentType: selected,
      availableDocumentTypes: orderedAvailable,
      messages: messages,
      diagnostics: diagnostics,
    );
  }

  _AieSourcePreflight? _nextFallbackPreflight(_AieSourcePreflight current) {
    for (final documentType in current.availableDocumentTypes) {
      if (documentType == current.selectedDocumentType) continue;
      final format = _exportFormatForDocumentType(documentType);
      final fallbackUri = _replaceExportFormat(current.fetchUri, format);
      return _AieSourcePreflight(
        valid: current.valid,
        fetchUri: fallbackUri,
        selectedDocumentType: documentType,
        availableDocumentTypes: current.availableDocumentTypes,
        messages: current.messages,
        diagnostics: {
          ...current.diagnostics,
          'selectedExportFormat': format,
          'constructedUrl': fallbackUri.toString(),
          'resolvedEndpoint': fallbackUri.toString(),
        },
      );
    }
    return null;
  }

  bool _isUnavailableExportResponse(AieFetchResponse response) {
    if (response.statusCode == 406) return true;
    final lower = response.body.toLowerCase();
    return lower.contains('unacceptable_response_type') ||
        lower.contains('requested type is not available');
  }

  String? _datasetIdFromUri(Uri uri) {
    final segments = uri.pathSegments;
    final viewsIndex = segments.indexOf('views');
    if (viewsIndex >= 0 && viewsIndex + 1 < segments.length) {
      return segments[viewsIndex + 1];
    }
    final resourceIndex = segments.indexOf('resource');
    if (resourceIndex >= 0 && resourceIndex + 1 < segments.length) {
      return segments[resourceIndex + 1].split('.').first;
    }
    final datasetIndex = segments.indexOf('dataset');
    if (datasetIndex >= 0 && segments.length > datasetIndex + 1) {
      final id = segments.reversed.firstWhere(
        _looksLikeSocrataDatasetId,
        orElse: () => '',
      );
      if (id.isNotEmpty) return id;
    }
    return null;
  }

  Uri _exportUriForFormat(
    Uri inputUri,
    String datasetId,
    AieDocumentType documentType,
  ) {
    final format = _exportFormatForDocumentType(documentType);
    if (inputUri.path.contains('/export.')) {
      return _replaceExportFormat(inputUri, format);
    }
    return Uri(
      scheme: inputUri.scheme,
      host: inputUri.host,
      path: '/api/v3/views/$datasetId/export.$format',
      queryParameters: const {'accessType': 'DOWNLOAD'},
    );
  }

  Uri _replaceExportFormat(Uri uri, String format) {
    final nextPath =
        uri.path.replaceFirst(RegExp(r'export\.[^/]+$'), 'export.$format');
    return uri.replace(path: nextPath);
  }

  AieDocumentType _selectPreferredFormat(List<AieDocumentType> available) {
    return _orderedFormats(available).first;
  }

  List<AieDocumentType> _orderedFormats(List<AieDocumentType> available) {
    const priority = [
      AieDocumentType.csv,
      AieDocumentType.json,
      AieDocumentType.geojson,
      AieDocumentType.xml,
    ];
    return [
      ...priority.where(available.contains),
      ...available.where((format) => !priority.contains(format)),
    ];
  }

  Iterable<AieDocumentType> _availableFormatsFromDiagnostics(
    Map<String, Object?> diagnostics,
  ) sync* {
    final value = diagnostics['availableExportFormats'];
    if (value == null) return;
    final text = value.toString().toLowerCase();
    for (final documentType in const [
      AieDocumentType.csv,
      AieDocumentType.json,
      AieDocumentType.geojson,
      AieDocumentType.xml,
    ]) {
      if (text.contains(_exportFormatForDocumentType(documentType))) {
        yield documentType;
      }
    }
  }

  List<AieDocumentType> _formatsFromMetadata(Map<String, Object?> metadata) {
    final raw = metadata['availableExportFormats'] ??
        metadata['availableFormats'] ??
        metadata['exportFormats'];
    if (raw is List) {
      return raw
          .map((value) => _documentTypeForExportFormat(value.toString()))
          .whereType<AieDocumentType>()
          .toList(growable: false);
    }
    if (raw is String) {
      return raw
          .split(RegExp(r'[,\\s]+'))
          .map(_documentTypeForExportFormat)
          .whereType<AieDocumentType>()
          .toList(growable: false);
    }
    return const [];
  }

  Map<String, Object?> _decodeJsonMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map) return decoded.cast<String, Object?>();
    return const {};
  }

  String? _authorityFromMetadata(Map<String, Object?> metadata) {
    final candidates = [
      metadata['authority'],
      metadata['owner'],
      metadata['attribution'],
      metadata['name'],
    ];
    for (final value in candidates) {
      if (value is Map) {
        final displayName = value['displayName'] ?? value['name'];
        if (displayName != null) return displayName.toString();
      }
      if (value is String && value.trim().isNotEmpty) return value;
    }
    return null;
  }

  String _authorityFromCouncil(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('westminster')) return 'westminster';
    if (lower.contains('camden')) return 'camden';
    if (lower.contains('islington')) return 'islington';
    if (lower.contains('lambeth')) return 'lambeth';
    if (lower.contains('kensington') || lower.contains('chelsea')) {
      return 'kensington';
    }
    return _safe(value);
  }

  String _authorityFromHost(String host) {
    final lower = host.toLowerCase();
    if (lower.contains('westminster')) return 'westminster';
    if (lower.contains('camden')) return 'camden';
    if (lower.contains('islington')) return 'islington';
    if (lower.contains('lambeth')) return 'lambeth';
    if (lower.contains('rbkc') ||
        lower.contains('kensington') ||
        lower.contains('chelsea')) {
      return 'kensington';
    }
    return _safe(host);
  }

  String? _authorityMismatch(
    String configuredAuthority,
    String detectedAuthority,
    String host,
    String path,
  ) {
    final detected = _authorityFromCouncil(detectedAuthority);
    if (configuredAuthority == detected) return null;
    if (host.toLowerCase().contains(configuredAuthority)) return null;
    if (path.toLowerCase().contains(configuredAuthority)) return null;
    return 'Configuration error: selected council may not match source dataset. Configured $configuredAuthority but source appears to be $detected.';
  }

  bool _looksLikeSocrataDatasetId(String value) {
    return RegExp(r'^[a-z0-9]{4}-[a-z0-9]{4}$', caseSensitive: false)
        .hasMatch(value);
  }

  String _exportFormatForDocumentType(AieDocumentType documentType) {
    return switch (documentType) {
      AieDocumentType.csv => 'csv',
      AieDocumentType.json => 'json',
      AieDocumentType.geojson => 'geojson',
      AieDocumentType.xml => 'xml',
      AieDocumentType.rss => 'xml',
      AieDocumentType.html => 'html',
      AieDocumentType.pdf => 'pdf',
      AieDocumentType.docx => 'docx',
    };
  }

  AieDocumentType? _documentTypeForExportFormat(String value) {
    final lower = value.toLowerCase().replaceAll('.', '').trim();
    return switch (lower) {
      'csv' => AieDocumentType.csv,
      'json' => AieDocumentType.json,
      'geojson' => AieDocumentType.geojson,
      'xml' => AieDocumentType.xml,
      _ => null,
    };
  }
}

class AieResolvedImportInput {
  const AieResolvedImportInput({
    required this.success,
    required this.body,
    required this.checksum,
    required this.messages,
    required this.diagnostics,
    required this.documentType,
    this.fetchUrl,
    this.contentType,
    this.fetchedAt,
  });

  factory AieResolvedImportInput.success({
    required String body,
    required String checksum,
    List<String> messages = const [],
    Map<String, Object?> diagnostics = const {},
    AieDocumentType? documentType,
    String? fetchUrl,
    String? contentType,
    DateTime? fetchedAt,
  }) {
    return AieResolvedImportInput(
      success: true,
      body: body,
      checksum: checksum,
      messages: messages,
      diagnostics: diagnostics,
      documentType: documentType ?? AieDocumentType.csv,
      fetchUrl: fetchUrl,
      contentType: contentType,
      fetchedAt: fetchedAt,
    );
  }

  factory AieResolvedImportInput.failure({
    required String checksum,
    required List<String> messages,
    String? fetchUrl,
    String? contentType,
    Map<String, Object?> diagnostics = const {},
    AieDocumentType? documentType,
  }) {
    return AieResolvedImportInput(
      success: false,
      body: '',
      checksum: checksum,
      messages: messages,
      diagnostics: diagnostics,
      documentType: documentType ?? AieDocumentType.csv,
      fetchUrl: fetchUrl,
      contentType: contentType,
    );
  }

  final bool success;
  final String body;
  final String checksum;
  final List<String> messages;
  final Map<String, Object?> diagnostics;
  final AieDocumentType documentType;
  final String? fetchUrl;
  final String? contentType;
  final DateTime? fetchedAt;
}

class _AieSourcePreflight {
  _AieSourcePreflight({
    required this.valid,
    required this.fetchUri,
    required this.selectedDocumentType,
    required this.availableDocumentTypes,
    required this.messages,
    required this.diagnostics,
  });

  final bool valid;
  final Uri fetchUri;
  final AieDocumentType selectedDocumentType;
  final List<AieDocumentType> availableDocumentTypes;
  final List<String> messages;
  final Map<String, Object?> diagnostics;
}

class AieFetchResponse {
  const AieFetchResponse({
    required this.statusCode,
    required this.body,
    this.contentType,
    this.finalUrl,
    this.unreachable = false,
  });

  const AieFetchResponse.unreachable()
      : statusCode = 0,
        body = '',
        contentType = null,
        finalUrl = null,
        unreachable = true;

  final int statusCode;
  final String body;
  final String? contentType;
  final String? finalUrl;
  final bool unreachable;
}

abstract interface class AieFetchClient {
  Future<AieFetchResponse> get(Uri uri);
}

class HttpAieFetchClient implements AieFetchClient {
  const HttpAieFetchClient();

  @override
  Future<AieFetchResponse> get(Uri uri) async {
    try {
      final response = await http.get(uri);
      return AieFetchResponse(
        statusCode: response.statusCode,
        body: response.body,
        contentType: response.headers['content-type'],
        finalUrl: uri.toString(),
      );
    } catch (_) {
      return const AieFetchResponse.unreachable();
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
