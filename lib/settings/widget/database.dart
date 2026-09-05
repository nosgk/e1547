import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift_flutter/drift_flutter.dart';
import 'package:e1547/app/app.dart';
import 'package:e1547/app/widget/initialize.dart';
import 'package:e1547/logs/logs.dart';
import 'package:e1547/shared/shared.dart';
import 'package:file_picker/file_picker.dart';
import 'package:filesize/filesize.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sub/flutter_sub.dart';
import 'package:path/path.dart';

typedef DatabaseInfo = ({String name, String size});

final _logger = Logger('DbManagement');

class DatabaseManagementPage extends StatelessWidget {
  const DatabaseManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TransparentAppBar(
        child: DefaultAppBar(leading: CloseButton()),
      ),
      body: LimitedWidthLayout.builder(
        builder: (context) => ListView(
          padding: defaultActionListPadding.add(
            LimitedWidthLayout.of(context).padding,
          ),
          children: const [
            DatabaseInfoDisplay(),
            SizedBox(height: 64),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Card(
                child: Column(
                  children: [DatabaseExportTile(), DatabaseImportTile()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DatabaseInfoDisplay extends StatelessWidget {
  const DatabaseInfoDisplay({super.key});

  Future<DatabaseInfo> _loadDatabaseInfo() async {
    final dbPath = await getAppDatabasePath();
    final dbFile = File(dbPath);

    final name = dbPath.split(Platform.pathSeparator).last;
    final size = dbFile.existsSync()
        ? filesize(dbFile.lengthSync())
        : 'Unknown'.tr;

    return (name: name, size: size);
  }

  @override
  Widget build(BuildContext context) {
    return SubFuture<DatabaseInfo>(
      create: _loadDatabaseInfo,
      builder: (context, snapshot) {
        final dbInfo =
            snapshot.data ??
            (snapshot.error != null
                ? (name: 'Error loading database'.tr, size: 'N/A'.tr)
                : (name: 'Loading...'.tr, size: '...'));

        return Center(
          child: Column(
            children: [
              const SizedBox(height: 32),
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: Theme.of(context).colorScheme.primary,
                radius: 64,
                child: const Icon(Icons.storage, size: 64),
              ),
              const SizedBox(height: 16),
              Text(dbInfo.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Dimmed(
                child: Text(
                  dbInfo.size,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

class DatabaseExportTile extends StatelessWidget {
  const DatabaseExportTile({super.key});

  Future<void> _exportDatabase(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final includeTranslation = await _showExportOptions(context);
    if (includeTranslation == null) return;
    if (!context.mounted) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(4),
                child: SizedBox(
                  height: 28,
                  width: 28,
                  child: CircularProgressIndicator(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Exporting database...'.tr),
              ),
            ],
          ),
        ),
      );

      final dbPath = await getAppDatabasePath();
      final dbFile = File(dbPath);
      if (!dbFile.existsSync()) {
        throw Exception('Database file does not exist');
      }

      // Copy the database (plus WAL sidecar files) to a temporary file and
      // embed the current app settings into the copy. The live database is
      // never modified.
      final tempDir = await getTemporaryAppDirectory();
      final tempPath = join(
        tempDir,
        'e1547_export_${DateTime.now().millisecondsSinceEpoch}.db',
      );
      await dbFile.copy(tempPath);
      for (final suffix in ['-wal', '-shm']) {
        final sidecar = File('$dbPath$suffix');
        if (sidecar.existsSync()) {
          await sidecar.copy('$tempPath$suffix');
        }
      }
      try {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        final exportDb = AppDatabase(
          driftDatabase(
            name: 'export',
            native: DriftNativeOptions(databasePath: () async => tempPath),
          ),
        );
        try {
          await writePreferencesBackup(
            exportDb,
            includeTranslationSettings: includeTranslation,
          );
        } finally {
          await exportDb.close();
        }
      } finally {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
      }
      // Closing the connection checkpointed the WAL into the main file.
      for (final suffix in ['-wal', '-shm']) {
        final sidecar = File('$tempPath$suffix');
        if (sidecar.existsSync()) {
          await sidecar.delete();
        }
      }

      String? outputFile;
      try {
        outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Export Database'.tr,
          fileName: 'e1547_database_backup.db',
          type: FileType.custom,
          allowedExtensions: ['db'],
          bytes: await File(tempPath).readAsBytes(),
        );
      } finally {
        await File(tempPath).delete();
      }

      navigator.pop();
      if (outputFile != null) {
        messenger.showSnackBar(
          SnackBar(content: Text('Database exported successfully'.tr)),
        );
      }
    } on Exception catch (e) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text('Export failed'.tr)));
      _logger.warn('Database export failed', null, e);
    }
  }

  Future<bool?> _showExportOptions(BuildContext context) {
    var includeTranslation = true;
    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Export Database'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Includes all app settings'.tr),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: includeTranslation,
                onChanged: (value) =>
                    setState(() => includeTranslation = value ?? true),
                title: Text('Include translation service settings'.tr),
                subtitle: Text(
                  'Unchecked exports default translation settings'.tr,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('CANCEL'.tr),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(includeTranslation),
              child: Text('EXPORT'.tr),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.file_download),
      title: Text('Export'.tr),
      subtitle: Text(
        'Save a backup copy of your database and settings'.tr,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _exportDatabase(context),
    );
  }
}

class DatabaseImportTile extends StatelessWidget {
  const DatabaseImportTile({super.key});

  Future<void> _importDatabase(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    Map<String, String>? preferencesBackup;

    final confirmed = await _showImportWarning(context);
    if (!confirmed) return;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Import Database',
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      final path = result?.files.single.path;

      if (path == null) return;
      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(4),
                child: SizedBox(
                  height: 28,
                  width: 28,
                  child: CircularProgressIndicator(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Importing database...'.tr),
              ),
            ],
          ),
        ),
      );

      try {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        final importDb = AppDatabase(
          driftDatabase(
            name: 'import',
            native: DriftNativeOptions(databasePath: () async => path),
          ),
        );
        await importDb.customSelect('SELECT 1').get();
        preferencesBackup = await readPreferencesBackup(importDb);
        await importDb.close();
      } on Exception catch (e) {
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Invalid database file: {error}'.trArgs({'error': e}),
            ),
          ),
        );
        _logger.warn('Database validation failed', null, e);
        return;
      } finally {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
      }

      final importFile = File(path);
      final dbPath = await getAppDatabasePath();
      final newDbPath = '$dbPath.new';
      await importFile.copy(newDbPath);

      // Restore the app settings embedded in the backup, if any. The
      // restart below reloads them.
      if (preferencesBackup != null) {
        await applyPreferencesBackup(preferencesBackup);
      }

      navigator.pop();
      if (context.mounted) {
        await _showRestartDialog(context);
      }
    } on Exception catch (e) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Import failed: {error}'.trArgs({'error': '$e'})),
        ),
      );
    }
  }

  Future<bool> _showImportWarning(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (context) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: AlertDialog(
          title: Text('Import Database'.tr),
          content: Text(
            'This will replace your current database. \n'
                    'All data will be lost. This cannot be undone!'
                .tr,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('CANCEL'.tr),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text('IMPORT'.tr),
            ),
          ],
        ),
      ),
    ),
  ).then((value) => value ?? false);

  Future<void> _showRestartDialog(BuildContext context) => showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text('Restart Required'.tr),
      content: Text('The app needs to restart to apply changes.'.tr),
      actions: [
        TextButton(
          onPressed: () => AppInit.of(context).reinitialize(),
          child: Text('RESTART NOW'.tr),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.file_upload),
      title: Text('Import'.tr),
      subtitle: Text(
        'Replace current database with imported one'.tr,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _importDatabase(context),
    );
  }
}
