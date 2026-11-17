import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../domain/services/sync_exceptions.dart';

class DriveEntry {
  const DriveEntry({
    required this.id,
    required this.name,
    this.relativeSegments = const [],
    this.sizeBytes,
  });

  final String id;
  final String name;
  final List<String> relativeSegments;
  final int? sizeBytes;
}

class DriveQuotaInfo {
  const DriveQuotaInfo({required this.usageBytes, this.limitBytes});

  final int usageBytes;
  final int? limitBytes;
}

class DriveApiClient {
  DriveApiClient(
    this._clientId,
    this._clientSecret,
    this._refreshToken, {
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(minutes: 10),
                sendTimeout: const Duration(minutes: 10),
              ),
            );

  static const String _tokenUrl = 'https://oauth2.googleapis.com/token';
  static const String _driveApi = 'https://www.googleapis.com/drive/v3';
  static const String _uploadApi = 'https://www.googleapis.com/upload/drive/v3';
  static const String _backupFolderName = 'Respaldo Drive';
  static const String _folderMime = 'application/vnd.google-apps.folder';

  final String _clientId;
  final String _clientSecret;
  final String _refreshToken;
  final Dio _dio;

  String? _accessToken;
  DateTime _tokenExpiresAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _backupFolderId;
  final Map<String, String> _folderIds = {};

  Future<String> _fetchAccessToken() async {
    if (_accessToken != null && DateTime.now().isBefore(_tokenExpiresAt)) {
      return _accessToken!;
    }
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        _tokenUrl,
        data: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'refresh_token': _refreshToken,
          'grant_type': 'refresh_token',
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final token = res.data?['access_token'] as String?;
      final expiresIn = res.data?['expires_in'] as int? ?? 3600;
      if (token == null) {
        throw const DriveAuthException('Respuesta de autenticación inválida');
      }
      _accessToken = token;
      _tokenExpiresAt = DateTime.now().add(Duration(seconds: expiresIn - 60));
      return token;
    } on DioException catch (e) {
      throw _mapDio(e, authEndpoint: true);
    }
  }

  Future<String> _ensureBackupFolder(String token) async {
    final cached = _backupFolderId;
    if (cached != null) return cached;
    final query = "name = '$_backupFolderName' and mimeType = '$_folderMime' "
        'and trashed = false';
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_driveApi/files',
        queryParameters: {
          'q': query,
          'fields': 'files(id)',
          'pageSize': 1,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final files = (res.data?['files'] as List?)
          ?.cast<Map<String, dynamic>>()
          .toList();
      if (files != null && files.isNotEmpty) {
        _backupFolderId = files.first['id'] as String;
        return _backupFolderId!;
      }
      final created = await _dio.post<Map<String, dynamic>>(
        '$_driveApi/files',
        data: {'name': _backupFolderName, 'mimeType': _folderMime},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final id = created.data?['id'] as String?;
      if (id == null) {
        throw const DriveApiException(
          'No se pudo crear la carpeta de respaldo en Drive',
        );
      }
      _backupFolderId = id;
      return id;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<String> _ensureFolderPath(String token, List<String> segments) async {
    var parentId = await _ensureBackupFolder(token);
    final walked = <String>[];
    for (final segment in segments) {
      walked.add(segment);
      final key = walked.join('/');
      final cached = _folderIds[key];
      if (cached != null) {
        parentId = cached;
        continue;
      }
      final query = "name = '$segment' and mimeType = '$_folderMime' and "
          "'$parentId' in parents and trashed = false";
      final res = await _dio.get<Map<String, dynamic>>(
        '$_driveApi/files',
        queryParameters: {'q': query, 'fields': 'files(id)', 'pageSize': 1},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final files = (res.data?['files'] as List?)
          ?.cast<Map<String, dynamic>>()
          .toList();
      String folderId;
      if (files != null && files.isNotEmpty) {
        folderId = files.first['id'] as String;
      } else {
        final created = await _dio.post<Map<String, dynamic>>(
          '$_driveApi/files',
          data: {'name': segment, 'mimeType': _folderMime, 'parents': [parentId]},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        final id = created.data?['id'] as String?;
        if (id == null) {
          throw const DriveApiException('No se pudo crear la subcarpeta en Drive');
        }
        folderId = id;
      }
      _folderIds[key] = folderId;
      parentId = folderId;
    }
    return parentId;
  }

  Future<String> uploadFile({
    required String name,
    required String filePath,
    List<String> relativeDirs = const [],
    String? existingFileId,
  }) async {
    final token = await _fetchAccessToken();
    final file = File(filePath);
    final int length;
    try {
      length = await file.length();
    } on FileSystemException {
      throw const DriveApiException('No se pudo leer el archivo local');
    }
    final metadata = existingFileId == null
        ? {
            'name': name,
            'parents': [await _ensureFolderPath(token, relativeDirs)],
          }
        : {'name': name};
    final form = FormData.fromMap(<String, MultipartFile>{
      'metadata': MultipartFile.fromString(
        jsonEncode(metadata),
        filename: 'metadata.json',
      ),
      'file': MultipartFile.fromStream(
        () => file.openRead(),
        length,
        filename: name,
      ),
    });
    try {
      final res = await _dio.request<Map<String, dynamic>>(
        existingFileId == null
            ? '$_uploadApi/files'
            : '$_uploadApi/files/$existingFileId',
        data: form,
        queryParameters: {'uploadType': 'multipart', 'fields': 'id'},
        options: Options(
          method: existingFileId == null ? 'POST' : 'PATCH',
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/related; boundary=${form.boundary}',
          },
        ),
      );
      final id = res.data?['id'] as String?;
      if (id == null) {
        throw const DriveApiException(
          'Google Drive devolvió una respuesta inválida',
        );
      }
      return id;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> trashFile(String fileId) async {
    final token = await _fetchAccessToken();
    try {
      await _dio.patch(
        '$_driveApi/files/$fileId',
        data: {'trashed': true},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> untrashFile(String fileId) async {
    final token = await _fetchAccessToken();
    try {
      await _dio.patch(
        '$_driveApi/files/$fileId',
        data: {'trashed': false},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<void> deleteFile(String fileId) async {
    final token = await _fetchAccessToken();
    try {
      await _dio.delete(
        '$_driveApi/files/$fileId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<List<DriveEntry>> listBackupFiles() async {
    final token = await _fetchAccessToken();
    final rootId = await _ensureBackupFolder(token);
    final result = <DriveEntry>[];

    Future<void> walk(String parentId, List<String> segments) async {
      var pageToken = '';
      do {
        final Response<Map<String, dynamic>> res;
        try {
          res = await _dio.get<Map<String, dynamic>>(
            '$_driveApi/files',
            queryParameters: {
              'q': "'$parentId' in parents and trashed = false",
              'fields': 'nextPageToken, files(id, name, mimeType, size)',
              'pageSize': 1000,
              if (pageToken.isNotEmpty) 'pageToken': pageToken,
            },
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
        } on DioException catch (e) {
          throw _mapDio(e);
        }
        final files = (res.data?['files'] as List?)
                ?.cast<Map<String, dynamic>>()
                .toList() ??
            const <Map<String, dynamic>>[];
        for (final f in files) {
          final mime = f['mimeType'] as String?;
          if (mime == _folderMime) {
            await walk(f['id'] as String, [...segments, f['name'] as String]);
          } else {
            result.add(DriveEntry(
              id: f['id'] as String,
              name: f['name'] as String,
              relativeSegments: List.of(segments),
              sizeBytes: int.tryParse('${f['size']}'),
            ));
          }
        }
        pageToken = res.data?['nextPageToken'] as String? ?? '';
      } while (pageToken.isNotEmpty);
    }

    await walk(rootId, const []);
    return result;
  }

  Future<void> downloadFile({
    required String fileId,
    required String savePath,
  }) async {
    final token = await _fetchAccessToken();
    try {
      await _dio.download(
        '$_driveApi/files/$fileId',
        savePath,
        queryParameters: {'alt': 'media'},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<DriveQuotaInfo> quota() async {
    final token = await _fetchAccessToken();
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_driveApi/about',
        queryParameters: {'fields': 'storageQuota'},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final quota = res.data?['storageQuota'] as Map<String, dynamic>?;
      return DriveQuotaInfo(
        usageBytes: int.tryParse('${quota?['usage']}') ?? 0,
        limitBytes: quota?['limit'] == null
            ? null
            : int.tryParse('${quota!['limit']}'),
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Exception _mapDio(DioException e, {bool authEndpoint = false}) {
    final type = e.type;
    if (type == DioExceptionType.connectionError ||
        type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.receiveTimeout ||
        type == DioExceptionType.sendTimeout) {
      return const DriveNetworkException('Sin conexión con Google Drive');
    }
    final status = e.response?.statusCode;
    if (status == 401 || (authEndpoint && status == 400)) {
      return const DriveAuthException(
        'Credenciales de Google Drive inválidas o vencidas',
      );
    }
    if (status == 403) {
      final data = e.response?.data;
      if (data is Map) {
        final errors = data['error'];
        if (errors is Map) {
          final reason = errors['errors'];
          if (reason.toString().contains('uota')) {
            return const DriveQuotaException('Cuota de Google Drive agotada');
          }
        }
      }
      return const DriveApiException('Acceso denegado por Google Drive');
    }
    return DriveApiException('Error de Google Drive (HTTP ${status ?? '?'})');
  }
}
