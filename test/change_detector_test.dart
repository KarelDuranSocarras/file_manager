import 'package:flutter_test/flutter_test.dart';
import 'package:file_manager/features/sync/domain/services/change_detector.dart';

void main() {
  const detector = ChangeDetector();

  test('archivo sin registro previo es nuevo', () {
    final change = detector.classify(
      localSize: 100,
      localModifiedMs: 1000,
    );
    expect(change, FileChangeType.newFile);
  });

  test('tamaño distinto cuenta como cambiado', () {
    final change = detector.classify(
      localSize: 200,
      localModifiedMs: 1000,
      uploadedSize: 100,
      uploadedModifiedMs: 1000,
    );
    expect(change, FileChangeType.changed);
  });

  test('fecha de modificación distinta cuenta como cambiado', () {
    final change = detector.classify(
      localSize: 100,
      localModifiedMs: 2000,
      uploadedSize: 100,
      uploadedModifiedMs: 1000,
    );
    expect(change, FileChangeType.changed);
  });

  test('tamaño y fecha iguales se consideran sin cambios', () {
    final change = detector.classify(
      localSize: 100,
      localModifiedMs: 1000,
      uploadedSize: 100,
      uploadedModifiedMs: 1000,
    );
    expect(change, FileChangeType.unchanged);
  });
}
