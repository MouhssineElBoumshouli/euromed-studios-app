/// The project actions the app sends to the server (same pattern as
/// [BookingService]: live calls a server function that checks the rules
/// again; offline runs on the in-memory demo).
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/people.dart';
import '../domain/projects.dart';
import 'app_state.dart';
import 'backend.dart';
import 'live_sync.dart';
import 'projects_state.dart';

/// A refusal the person can read.
class ProjectProblem implements Exception {
  const ProjectProblem(this.message);
  final String message;
  @override
  String toString() => message;
}

const projectBucket = 'project-files';

class ProjectService {
  ProjectService(this._ref);
  final Ref _ref;

  static const _latency = Duration(milliseconds: 400);

  ProjectsNotifier get _local => _ref.read(projectsProvider.notifier);
  SupabaseClient get _db => Supabase.instance.client;

  Future<T> _call<T>(Future<T> Function() run) async {
    try {
      final r = await run();
      await liveSync?.refresh();
      return r;
    } on PostgrestException catch (e) {
      throw ProjectProblem(_translate(e.message));
    } on StorageException catch (e) {
      throw ProjectProblem(_translate(e.message));
    }
  }

  static String _translate(String m) {
    if (m.contains('needs_preparation_file')) {
      return 'Ajoutez d’abord un script, un conducteur ou un storyboard.';
    }
    if (m.contains('needs_validated_session')) {
      return 'Il faut au moins une séance validée liée au projet.';
    }
    if (m.contains('needs_quality_check')) {
      return 'Le passage en archive se fait après le contrôle qualité.';
    }
    if (m.contains('not_a_requester')) {
      return 'Votre profil ne permet pas de créer un projet.';
    }
    if (m.contains('exceeded') || m.contains('too large')) {
      return 'Fichier trop lourd (20 Mo maximum).';
    }
    if (m.contains('mime') || m.contains('invalid_mime_type')) {
      return 'Format non accepté. Utilisez PDF, Word, texte ou image.';
    }
    if (m.contains('file_missing')) {
      return 'L’envoi du fichier n’a pas abouti. Réessayez.';
    }
    if (m.contains('not_allowed') || m.contains('row-level security')) {
      return 'Vous ne pouvez pas faire cette action sur ce projet.';
    }
    return 'L’action n’a pas pu être enregistrée. Réessayez.';
  }

  Future<String> create({
    required Person by,
    required String title,
    required ProjectType type,
    String? description,
  }) async {
    if (isLive) {
      return _call(() async {
        final row = await _db.rpc(
          'create_project',
          params: {
            'p_title': title,
            'p_type': type.name,
            'p_description': description,
          },
        );
        return (row as Map<String, dynamic>)['id'] as String;
      });
    }
    await Future<void>.delayed(_latency);
    return _local
        .create(
          by: by,
          title: title,
          type: type,
          description: description,
          now: _ref.read(worldProvider).now,
        )
        .id;
  }

  Future<void> advance(String projectId, {required Person by}) async {
    if (isLive) {
      await _call(() => _db.rpc('advance_project', params: {'p_id': projectId}));
      return;
    }
    await Future<void>.delayed(_latency);
    try {
      _local.advance(projectId, by: by, world: _ref.read(worldProvider));
    } on StateError catch (e) {
      // Offline rules already give a sentence; server codes need one.
      throw ProjectProblem(
        e.message.contains(' ') ? e.message : _translate(e.message),
      );
    }
  }

  /// Uploads [bytes] to the project's folder, then records it.
  Future<void> addFile({
    required Person by,
    required String projectId,
    required FileKind kind,
    required String name,
    required Uint8List bytes,
  }) async {
    final safe = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    final path =
        '$projectId/${DateTime.now().millisecondsSinceEpoch}-$safe';
    if (isLive) {
      await _call(() async {
        await _db.storage.from(projectBucket).uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: _mime(name)),
            );
        try {
          await _db.rpc(
            'add_project_file',
            params: {
              'p_project': projectId,
              'p_kind': kind.name,
              'p_name': name,
              'p_path': path,
              'p_size': bytes.length,
            },
          );
        } catch (_) {
          // Don't leave an orphan file behind if recording it failed.
          await _db.storage.from(projectBucket).remove([path]);
          rethrow;
        }
      });
      return;
    }
    await Future<void>.delayed(_latency);
    final now = _ref.read(worldProvider).now;
    _local.addFile(
      ProjectFile(
        id: 'f${now.microsecondsSinceEpoch}',
        projectId: projectId,
        kind: kind,
        name: name,
        path: path,
        sizeBytes: bytes.length,
        uploadedBy: by.id,
        uploadedAt: now,
      ),
      now: now,
    );
  }

  Future<void> removeFile(ProjectFile f) async {
    if (isLive) {
      await _call(() async {
        await _db.rpc('remove_project_file', params: {'p_id': f.id});
        await _db.storage.from(projectBucket).remove([f.path]);
      });
      return;
    }
    await Future<void>.delayed(_latency);
    _local.removeFile(f.id);
  }

  /// A short-lived private link to open the file (1 minute).
  /// Null offline (no real files there).
  Future<String?> linkFor(ProjectFile f) async {
    if (!isLive) return null;
    try {
      return await _db.storage
          .from(projectBucket)
          .createSignedUrl(f.path, 60);
    } on StorageException {
      throw const ProjectProblem(
        'Le document est introuvable. Ajoutez-le à nouveau.',
      );
    }
  }

  static String _mime(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'odt' => 'application/vnd.oasis.opendocument.text',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => 'text/plain',
    };
  }
}

final projectServiceProvider = Provider<ProjectService>(ProjectService.new);
