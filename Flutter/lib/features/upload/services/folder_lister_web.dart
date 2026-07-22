/// One file discovered inside a picked folder.
typedef FolderEntry = ({String name, int sizeBytes, String path});

/// The browser has no filesystem path API, so folder upload on web goes
/// through the picker's multi-file selection instead of enumeration.
Future<List<FolderEntry>> listFolder(String path) async => const [];
