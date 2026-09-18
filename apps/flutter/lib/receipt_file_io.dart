import 'dart:io';

Future<void> saveAndOpenReceipt(List<int> bytes, String filename) async {
  final home = Platform.environment['HOME'];
  if (home == null) throw StateError('Dossier utilisateur macOS introuvable.');
  final downloads = Directory('$home/Downloads');
  if (!downloads.existsSync()) downloads.createSync(recursive: true);
  final file = File('${downloads.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  await Process.run('open', [file.path]);
}
