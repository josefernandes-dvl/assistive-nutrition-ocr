import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Persistência local do perfil, do histórico e do consentimento.
///
/// Grava um único arquivo JSON no **diretório de documentos do aplicativo**,
/// que em Android/iOS é área privada do app (RNF13): outros aplicativos não o
/// leem e a desinstalação o remove junto (RN06).
///
/// Nada aqui sai do dispositivo. O backend continua recebendo apenas nomes de
/// ingredientes e rótulos de distúrbio, sem identificador (RNF10).
class LocalStore {
  /// Injeção usada pelos testes — em produção resolve o diretório do app.
  final Future<Directory> Function() _resolveDirectory;

  LocalStore({Future<Directory> Function()? directoryResolver})
      : _resolveDirectory =
            directoryResolver ?? getApplicationDocumentsDirectory;

  static const String fileName = 'nutriscan_data.json';

  /// Versão do formato gravado. Serve para migração futura: um arquivo com
  /// versão desconhecida é descartado em vez de interpretado errado.
  static const int schemaVersion = 1;

  /// Teto de itens do histórico. Evita crescimento sem limite do arquivo em
  /// uso prolongado; a exclusão continua sob controle do usuário (RF17).
  static const int maxHistoryEntries = 200;

  File? _cachedFile;

  Future<File> _file() async {
    final cached = _cachedFile;
    if (cached != null) return cached;
    final dir = await _resolveDirectory();
    final file = File(p.join(dir.path, fileName));
    _cachedFile = file;
    return file;
  }

  /// Lê o estado persistido. Retorna `null` quando não há nada gravado.
  ///
  /// Arquivo corrompido ou de versão desconhecida é tratado como ausência de
  /// dados — o app abre vazio em vez de falhar no boot.
  Future<Map<String, dynamic>?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;

      final decoded = json.decode(content);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['schema_version'] != schemaVersion) return null;

      return decoded;
    } catch (_) {
      return null;
    }
  }

  /// Grava o estado. Escreve primeiro num arquivo temporário e só então
  /// renomeia, para que uma interrupção no meio da escrita não deixe um JSON
  /// truncado no lugar do histórico do usuário.
  Future<void> write(Map<String, dynamic> data) async {
    final file = await _file();
    await file.parent.create(recursive: true);

    final payload = <String, dynamic>{
      'schema_version': schemaVersion,
      ...data,
    };

    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(json.encode(payload), flush: true);
    await tmp.rename(file.path);
  }

  /// Apaga fisicamente o arquivo (RF03/RNF14 — direito de eliminação).
  Future<void> erase() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Arquivo já ausente — o efeito desejado é o mesmo.
    }
  }
}
