import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../providers/app_providers.dart';
import '../../../../providers/auth_provider.dart';
import '../../engine/tool_engine.dart';
import '../engines/pdf_converter_engine.dart';
import '../models/convert_settings.dart';
import '../models/conversion_result.dart';
import '../models/document_structure.dart';
import '../models/target_format.dart';
import '../services/pdf_analyzer.dart';
import '../services/pdf_rasterizer.dart';
import '../services/url_import_service.dart';

enum ConverterView {
  upload,
  analysis,
  review,
  convert,
  results,
  compare,
  diff,
}

class PdfConverterState {
  const PdfConverterState({
    this.view = ConverterView.upload,
    this.fileName,
    this.bytes,
    this.inputKind,
    this.structure,
    this.thumbnail,
    this.target,
    this.settings = const ConvertSettings(),
    this.progress,
    this.stage,
    this.result,
    this.compareResults = const [],
    this.compareFormats = const {},
    this.error,
    this.lockedTarget,
    this.password,
    this.history = const [],
    this.offlineOnly = false,
    this.dailyConversions = 0,
    this.isPro = false,
  });

  final ConverterView view;
  final String? fileName;
  final Uint8List? bytes;
  final ConverterInputKind? inputKind;
  final DocumentStructure? structure;
  final Uint8List? thumbnail;
  final TargetFormat? target;
  final ConvertSettings settings;
  final double? progress;
  final String? stage;
  final ConversionResult? result;
  final List<ConversionResult> compareResults;
  final Set<TargetFormat> compareFormats;
  final String? error;
  final TargetFormat? lockedTarget;
  final String? password;
  final List<ConversionHistoryItem> history;
  final bool offlineOnly;
  final int dailyConversions;
  final bool isPro;

  bool get hasFile => bytes != null && fileName != null;

  static const freeDailyLimit = 15;
  static const freePageSoftCap = 50;

  bool canUseFormat(TargetFormat format) {
    if (isPro) return true;
    return freeTargetFormats.contains(format);
  }

  bool get underDailyLimit => isPro || dailyConversions < freeDailyLimit;

  PdfConverterState copyWith({
    ConverterView? view,
    String? fileName,
    Uint8List? bytes,
    ConverterInputKind? inputKind,
    DocumentStructure? structure,
    Uint8List? thumbnail,
    TargetFormat? target,
    ConvertSettings? settings,
    double? progress,
    String? stage,
    ConversionResult? result,
    List<ConversionResult>? compareResults,
    Set<TargetFormat>? compareFormats,
    String? error,
    TargetFormat? lockedTarget,
    String? password,
    List<ConversionHistoryItem>? history,
    bool? offlineOnly,
    int? dailyConversions,
    bool? isPro,
    bool clearError = false,
    bool clearResult = false,
    bool clearFile = false,
    bool clearTarget = false,
    bool clearCompare = false,
  }) =>
      PdfConverterState(
        view: view ?? this.view,
        fileName: clearFile ? null : (fileName ?? this.fileName),
        bytes: clearFile ? null : (bytes ?? this.bytes),
        inputKind: clearFile ? null : (inputKind ?? this.inputKind),
        structure: clearFile ? null : (structure ?? this.structure),
        thumbnail: clearFile ? null : (thumbnail ?? this.thumbnail),
        target: clearTarget ? null : (target ?? this.target),
        settings: settings ?? this.settings,
        progress: progress,
        stage: stage,
        result: clearResult ? null : (result ?? this.result),
        compareResults:
            clearCompare ? const [] : (compareResults ?? this.compareResults),
        compareFormats:
            clearCompare ? const {} : (compareFormats ?? this.compareFormats),
        error: clearError ? null : (error ?? this.error),
        lockedTarget: lockedTarget ?? this.lockedTarget,
        password: password ?? this.password,
        history: history ?? this.history,
        offlineOnly: offlineOnly ?? this.offlineOnly,
        dailyConversions: dailyConversions ?? this.dailyConversions,
        isPro: isPro ?? this.isPro,
      );
}

class ConversionHistoryItem {
  const ConversionHistoryItem({
    required this.sourceName,
    required this.target,
    required this.timestamp,
    required this.confidence,
    this.outputName,
  });

  final String sourceName;
  final TargetFormat target;
  final DateTime timestamp;
  final int confidence;
  final String? outputName;
}

final pdfConverterProvider =
    NotifierProvider.autoDispose<PdfConverterController, PdfConverterState>(
  PdfConverterController.new,
);

class PdfConverterController extends AutoDisposeNotifier<PdfConverterState> {
  final _analyzer = const PdfAnalyzer();
  final _engine = PdfConverterEngine();
  final _raster = PdfRasterizer();
  final _urlImport = UrlImportService();
  bool _canceled = false;

  static const _historyKey = 'pdf_converter_history';
  static const _settingsKey = 'pdf_converter_settings';
  static const _dailyKey = 'pdf_converter_daily';
  static const _offlineKey = 'pdf_converter_offline_only';

  @override
  PdfConverterState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final user = ref.watch(authProvider);
    final settings = _loadSettings(prefs);
    return PdfConverterState(
      history: _loadHistory(prefs),
      settings: settings,
      offlineOnly: prefs.getBool(_offlineKey) ?? false,
      dailyConversions: _loadDailyCount(prefs),
      isPro: user?.isPro ?? false,
    );
  }

  void setLockedTarget(TargetFormat? format) {
    state = state.copyWith(lockedTarget: format, target: format);
  }

  Future<void> stageFile({
    required String name,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) {
      state = state.copyWith(error: 'File is empty.');
      return;
    }
    final kind = PdfConverterEngine.detectKind(name);
    state = state.copyWith(
      fileName: name,
      bytes: bytes,
      inputKind: kind,
      view: ConverterView.analysis,
      clearError: true,
      clearResult: true,
      clearCompare: true,
      clearTarget: state.lockedTarget == null,
      target: state.lockedTarget,
      progress: null,
      stage: 'Analyzing…',
    );

    try {
      if (kind == ConverterInputKind.pdf) {
        final structure =
            _analyzer.analyzeBytes(bytes, password: state.password);
        if (!state.isPro && structure.pageCount > PdfConverterState.freePageSoftCap) {
          // Soft warn — still allow, but surface in error banner as notice.
          state = state.copyWith(
            error:
                'Free plan: ${PdfConverterState.freePageSoftCap}+ pages may be slow. Pro unlocks larger docs.',
          );
        }
        final thumb = await _raster.thumbnail(bytes);
        final target = state.lockedTarget ?? structure.recommendation.format;
        state = state.copyWith(
          structure: structure,
          thumbnail: thumb,
          target: target,
          view: ConverterView.review,
          progress: null,
          stage: null,
        );
      } else {
        state = state.copyWith(
          target: TargetFormat.pdf,
          view: ConverterView.convert,
          progress: null,
          stage: null,
        );
      }
    } catch (_) {
      state = state.copyWith(
        view: ConverterView.upload,
        error: 'Could not analyze this file (password or corrupt).',
        clearFile: true,
      );
    }
  }

  Future<void> importFromUrl(String url) async {
    if (state.offlineOnly) {
      state = state.copyWith(
        error: 'Offline-only mode is on. Turn it off in converter settings.',
      );
      return;
    }
    if (!state.isPro && !state.underDailyLimit) {
      state = state.copyWith(
        error:
            'Daily free conversion limit reached (${PdfConverterState.freeDailyLimit}). Upgrade to Pro.',
      );
      return;
    }
    state = state.copyWith(
      view: ConverterView.analysis,
      stage: 'Downloading…',
      progress: null,
      clearError: true,
    );
    try {
      final file = await _urlImport.fetch(url);
      await stageFile(name: file.name, bytes: file.bytes);
    } on ToolFailure catch (e) {
      state = state.copyWith(
        view: ConverterView.upload,
        error: e.message,
        progress: null,
        stage: null,
      );
    } catch (_) {
      state = state.copyWith(
        view: ConverterView.upload,
        error: 'URL import failed.',
        progress: null,
        stage: null,
      );
    }
  }

  void clearFile() {
    state = state.copyWith(
      clearFile: true,
      clearResult: true,
      clearError: true,
      clearCompare: true,
      clearTarget: state.lockedTarget == null,
      view: ConverterView.upload,
      progress: null,
      stage: null,
    );
  }

  void selectTarget(TargetFormat format) {
    if (!state.canUseFormat(format)) {
      state = state.copyWith(
        error: '${format.label} is a Pro format. Upgrade to unlock.',
      );
      return;
    }
    state = state.copyWith(target: format, clearError: true);
  }

  void toggleCompareFormat(TargetFormat format) {
    if (!state.canUseFormat(format)) {
      state = state.copyWith(
        error: '${format.label} is a Pro format. Upgrade to unlock.',
      );
      return;
    }
    final next = {...state.compareFormats};
    if (next.contains(format)) {
      next.remove(format);
    } else {
      if (next.length >= 3) {
        state = state.copyWith(error: 'Compare up to 3 formats at once.');
        return;
      }
      next.add(format);
    }
    state = state.copyWith(compareFormats: next, clearError: true);
  }

  void updateSettings(ConvertSettings settings) {
    state = state.copyWith(settings: settings);
    _saveSettings(ref.read(sharedPreferencesProvider), settings);
  }

  void setOfflineOnly(bool value) {
    state = state.copyWith(offlineOnly: value);
    ref.read(sharedPreferencesProvider).setBool(_offlineKey, value);
  }

  void goToConvert() {
    if (state.inputKind == ConverterInputKind.toPdf) {
      state = state.copyWith(
        view: ConverterView.convert,
        target: TargetFormat.pdf,
      );
    } else {
      state = state.copyWith(view: ConverterView.convert);
    }
  }

  void setPassword(String password) {
    state = state.copyWith(password: password);
  }

  void cancel() {
    _canceled = true;
    state = state.copyWith(
      view: state.hasFile ? ConverterView.convert : ConverterView.upload,
      progress: null,
      stage: null,
      clearError: true,
    );
  }

  Future<void> convert() async {
    final bytes = state.bytes;
    final name = state.fileName;
    final target = state.lockedTarget ?? state.target;
    if (bytes == null || name == null || target == null) {
      state = state.copyWith(error: 'Pick a file and format first.');
      return;
    }
    if (!state.canUseFormat(target)) {
      state = state.copyWith(
        error: '${target.label} requires Pro.',
      );
      return;
    }
    if (!state.underDailyLimit) {
      state = state.copyWith(
        error:
            'Daily free limit (${PdfConverterState.freeDailyLimit}) reached. Upgrade to Pro.',
      );
      return;
    }

    _canceled = false;
    state = state.copyWith(
      view: ConverterView.convert,
      progress: 0,
      stage: 'Starting',
      clearError: true,
      clearResult: true,
      clearCompare: true,
    );
    try {
      final result = await _engine.convert(
        bytes: bytes,
        fileName: name,
        target: target,
        settings: state.settings,
        password: state.password,
        onProgress: (fraction, stage) {
          if (!_canceled) {
            state = state.copyWith(progress: fraction, stage: stage);
          }
        },
        isCanceled: () => _canceled,
      );
      if (_canceled) return;
      _bumpDaily();
      _persistHistory(result, name);
      state = state.copyWith(
        result: result,
        view: ConverterView.results,
        progress: 1,
        stage: 'Done',
      );
    } on ToolCanceled {
      state = state.copyWith(
        progress: null,
        stage: null,
        view: ConverterView.convert,
      );
    } on ToolFailure catch (e) {
      state = state.copyWith(
        error: e.message,
        progress: null,
        stage: null,
        view: ConverterView.convert,
      );
    } catch (_) {
      state = state.copyWith(
        error: 'Conversion failed. Please try again.',
        progress: null,
        stage: null,
        view: ConverterView.convert,
      );
    }
  }

  Future<void> runCompare() async {
    final bytes = state.bytes;
    final name = state.fileName;
    final formats = state.compareFormats.toList();
    if (bytes == null || name == null || formats.length < 2) {
      state = state.copyWith(
        error: 'Select 2–3 formats to compare.',
      );
      return;
    }
    if (!state.isPro) {
      state = state.copyWith(
        error: 'Compare is a Pro feature.',
      );
      return;
    }
    if (!state.underDailyLimit) {
      state = state.copyWith(error: 'Daily free limit reached.');
      return;
    }

    _canceled = false;
    state = state.copyWith(
      view: ConverterView.compare,
      progress: 0,
      stage: 'Comparing…',
      clearError: true,
      clearResult: true,
      compareResults: const [],
    );

    final results = <ConversionResult>[];
    try {
      for (var i = 0; i < formats.length; i++) {
        if (_canceled) throw const ToolCanceled();
        final fmt = formats[i];
        state = state.copyWith(
          progress: i / formats.length,
          stage: 'Converting ${fmt.label}…',
        );
        final result = await _engine.convert(
          bytes: bytes,
          fileName: name,
          target: fmt,
          settings: state.settings,
          password: state.password,
          onProgress: (fraction, stage) {
            if (!_canceled) {
              state = state.copyWith(
                progress: (i + (fraction ?? 0)) / formats.length,
                stage: stage,
              );
            }
          },
          isCanceled: () => _canceled,
        );
        results.add(result);
      }
      if (_canceled) return;
      _bumpDaily();
      state = state.copyWith(
        compareResults: results,
        result: results.first,
        view: ConverterView.compare,
        progress: 1,
        stage: 'Done',
      );
    } on ToolCanceled {
      state = state.copyWith(
        progress: null,
        stage: null,
        view: ConverterView.convert,
      );
    } on ToolFailure catch (e) {
      state = state.copyWith(
        error: e.message,
        progress: null,
        stage: null,
        view: ConverterView.convert,
      );
    } catch (_) {
      state = state.copyWith(
        error: 'Compare failed.',
        progress: null,
        stage: null,
        view: ConverterView.convert,
      );
    }
  }

  void showDiff() {
    if (state.result == null && state.compareResults.isEmpty) return;
    state = state.copyWith(view: ConverterView.diff);
  }

  void convertAnother() => clearFile();

  void changeFormat() {
    state = state.copyWith(
      view: ConverterView.convert,
      clearResult: true,
      clearError: true,
      clearCompare: true,
      progress: null,
      stage: null,
    );
  }

  void _bumpDaily() {
    final prefs = ref.read(sharedPreferencesProvider);
    final next = state.dailyConversions + 1;
    state = state.copyWith(dailyConversions: next);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    prefs.setString(_dailyKey, '$today|$next');
  }

  int _loadDailyCount(SharedPreferences prefs) {
    final raw = prefs.getString(_dailyKey);
    if (raw == null) return 0;
    final parts = raw.split('|');
    if (parts.length != 2) return 0;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (parts[0] != today) return 0;
    return int.tryParse(parts[1]) ?? 0;
  }

  ConvertSettings _loadSettings(SharedPreferences prefs) {
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) return const ConvertSettings();
    final parts = raw.split('|');
    if (parts.length < 3) return const ConvertSettings();
    return ConvertSettings(
      imageQuality: double.tryParse(parts[0]) ?? 0.85,
      resolution: double.tryParse(parts[1]) ?? 2.0,
      zipMultiPageImages: parts[2] == '1',
    );
  }

  void _saveSettings(SharedPreferences prefs, ConvertSettings s) {
    prefs.setString(
      _settingsKey,
      '${s.imageQuality}|${s.resolution}|${s.zipMultiPageImages ? 1 : 0}',
    );
  }

  void _persistHistory(ConversionResult result, String source) {
    final prefs = ref.read(sharedPreferencesProvider);
    final item = ConversionHistoryItem(
      sourceName: source,
      target: result.format,
      timestamp: DateTime.now(),
      confidence: result.confidence,
      outputName: result.fileName,
    );
    final next = [item, ...state.history].take(20).toList();
    state = state.copyWith(history: next);
    final encoded = next
        .map((e) =>
            '${e.timestamp.toIso8601String()}|${e.target.name}|${e.confidence}|${e.sourceName}|${e.outputName ?? ''}')
        .join('\n');
    prefs.setString(_historyKey, encoded);
  }

  List<ConversionHistoryItem> _loadHistory(SharedPreferences prefs) {
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return const [];
    final items = <ConversionHistoryItem>[];
    for (final line in raw.split('\n')) {
      final parts = line.split('|');
      if (parts.length < 4) continue;
      final ts = DateTime.tryParse(parts[0]);
      final fmt = TargetFormatX.tryParse(parts[1]);
      final conf = int.tryParse(parts[2]) ?? 0;
      if (ts == null || fmt == null) continue;
      items.add(ConversionHistoryItem(
        timestamp: ts,
        target: fmt,
        confidence: conf,
        sourceName: parts[3],
        outputName: parts.length > 4 ? parts[4] : null,
      ));
    }
    return items;
  }

  Future<void> clearHistory() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_historyKey);
    state = state.copyWith(history: const []);
  }
}
