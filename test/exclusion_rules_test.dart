import 'package:flutter_test/flutter_test.dart';
import 'package:file_manager/features/sync/domain/services/exclusion_rules.dart';

void main() {
  const rules = ExclusionRules();

  test('excluye archivos ocultos', () {
    expect(rules.isExcluded('/home/u/carpeta/.gitignore'), isTrue);
  });

  test('excluye archivos temporales', () {
    expect(rules.isExcluded('C:/respaldo/documento.tmp'), isTrue);
    expect(rules.isExcluded('C:/respaldo/descarga.crdownload'), isTrue);
  });

  test('excluye locks temporales de Office', () {
    expect(rules.isExcluded('C:/respaldo/~\$informe.docx'), isTrue);
  });

  test('excluye archivos de sistema conocidos', () {
    expect(rules.isExcluded('C:/respaldo/Thumbs.db'), isTrue);
    expect(rules.isExcluded('C:/respaldo/desktop.ini'), isTrue);
    expect(rules.isExcluded('/home/u/carpeta/.DS_Store'), isTrue);
  });

  test('no excluye archivos normales', () {
    expect(rules.isExcluded('/home/u/carpeta/foto.jpg'), isFalse);
    expect(rules.isExcluded('C:/respaldo/informe.docx'), isFalse);
  });

  test('excluye contenido dentro de carpetas ocultas', () {
    expect(rules.isExcluded('/home/u/carpeta/.git/config'), isTrue);
    expect(rules.isExcluded('C:/respaldo/.trash/archivo.pdf'), isTrue);
  });

  test('respeta exclusiones personalizadas por extensión', () {
    const custom = ExclusionRules(customExtensions: ['.bak']);
    expect(custom.isExcluded('C:/respaldo/respaldo.bak'), isTrue);
    expect(rules.isExcluded('C:/respaldo/respaldo.bak'), isFalse);
  });
}
