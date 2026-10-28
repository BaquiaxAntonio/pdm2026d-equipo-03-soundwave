import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/download_record.dart';
import '../../core/models/song.dart';
import '../../core/providers/data_mode_provider.dart';
import '../downloads/download_providers.dart';
import 'data/commons_api_client.dart';
import 'data/commons_catalog_repository.dart';
import 'mock_search_data.dart';
import 'search_filter_local.dart';

enum SearchViewStatus { initial, loading, results, empty, error }

class SearchViewState {
  SearchViewState({
    required this.query,
    required this.status,
    required this.isDemo,
    Iterable<Song> songs = const [],
    this.origin,
    this.fallbackReason,
    this.errorMessage,
  }) : songs = List.unmodifiable(songs);

  final String query;
  final SearchViewStatus status;
  final bool isDemo;
  final List<Song> songs;
  final CatalogResultOrigin? origin;
  final CatalogFallbackReason? fallbackReason;
  final String? errorMessage;

  String? get fallbackMessage {
    if (origin != CatalogResultOrigin.localFallback || fallbackReason == null) {
      return null;
    }
    const limitation = 'Mostrando solo canciones consultadas anteriormente.';
    return switch (fallbackReason!) {
      CatalogFallbackReason.network => 'Sin conexión. $limitation',
      CatalogFallbackReason.timeout =>
        'Commons tardó demasiado en responder. $limitation',
      CatalogFallbackReason.authentication =>
        'Commons rechazó la autorización de la consulta. $limitation',
      CatalogFallbackReason.rateLimited =>
        'Límite temporal de solicitudes de Commons. $limitation',
      CatalogFallbackReason.serviceUnavailable =>
        'Commons no está disponible temporalmente. $limitation',
      CatalogFallbackReason.invalidResponse =>
        'Commons devolvió una respuesta no válida. $limitation',
    };
  }
}

final searchDebounceDurationProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 350),
);

final searchControllerProvider =
    NotifierProvider<SearchController, SearchViewState>(SearchController.new);

enum SearchDownloadStatus {
  available,
  preparing,
  requesting,
  queued,
  downloading,
  completed,
  failed,
  pendingDeletion,
  unavailable,
}

class SearchDownloadViewState {
  const SearchDownloadViewState({
    required this.status,
    this.message,
    this.progress,
  });

  final SearchDownloadStatus status;
  final String? message;
  final double? progress;

  bool get canActivate => switch (status) {
    SearchDownloadStatus.available ||
    SearchDownloadStatus.failed ||
    SearchDownloadStatus.unavailable => true,
    _ => false,
  };
}

enum SearchDownloadRequestOutcome {
  requested,
  alreadyPresent,
  unavailable,
  ignored,
  failed,
}

class SearchDownloadRequestResult {
  const SearchDownloadRequestResult(this.outcome, [this.message]);

  final SearchDownloadRequestOutcome outcome;
  final String? message;
}

class SearchDownloadRequestState {
  const SearchDownloadRequestState({
    required this.isRequesting,
    this.errorMessage,
  });

  final bool isRequesting;
  final String? errorMessage;
}

final searchDownloadControllerProvider =
    NotifierProvider<
      SearchDownloadController,
      Map<String, SearchDownloadRequestState>
    >(SearchDownloadController.new);

final searchDownloadStateProvider =
    Provider.family<SearchDownloadViewState, String>((ref, songId) {
      if (ref.watch(dataModeProvider) == DataMode.demo) {
        return const SearchDownloadViewState(
          status: SearchDownloadStatus.unavailable,
          message: 'La descarga real no está disponible en modo demostración.',
        );
      }

      final request = ref.watch(
        searchDownloadControllerProvider.select((requests) => requests[songId]),
      );
      if (request?.isRequesting ?? false) {
        return const SearchDownloadViewState(
          status: SearchDownloadStatus.requesting,
          message: 'Solicitando descarga…',
        );
      }
      if (request?.errorMessage case final message?) {
        return SearchDownloadViewState(
          status: SearchDownloadStatus.failed,
          message: message,
        );
      }

      final session = ref.watch(downloadSessionProvider);
      return switch (session) {
        AsyncLoading() => const SearchDownloadViewState(
          status: SearchDownloadStatus.preparing,
          message: 'Preparando descargas…',
        ),
        AsyncError() => const SearchDownloadViewState(
          status: SearchDownloadStatus.unavailable,
          message: 'No se pudo abrir la sesión de descargas.',
        ),
        AsyncData(:final value) when value == null =>
          const SearchDownloadViewState(
            status: SearchDownloadStatus.unavailable,
            message: 'La sesión de descargas no está disponible.',
          ),
        AsyncData() => _downloadRecordState(
          ref.watch(downloadEntriesProvider),
          songId,
        ),
      };
    });

SearchDownloadViewState _downloadRecordState(
  AsyncValue<List<DownloadEntry>> entries,
  String songId,
) => switch (entries) {
  AsyncLoading() => const SearchDownloadViewState(
    status: SearchDownloadStatus.preparing,
    message: 'Comprobando descarga…',
  ),
  AsyncError() => const SearchDownloadViewState(
    status: SearchDownloadStatus.unavailable,
    message: 'No se pudo consultar el estado de descarga.',
  ),
  AsyncData(:final value) => _stateForRecord(
    value.where((entry) => entry.record.songId == songId).firstOrNull?.record,
  ),
};

SearchDownloadViewState _stateForRecord(DownloadRecord? record) {
  if (record == null) {
    return const SearchDownloadViewState(
      status: SearchDownloadStatus.available,
    );
  }
  return switch (record.state) {
    DownloadState.queued => const SearchDownloadViewState(
      status: SearchDownloadStatus.queued,
      message: 'En cola',
    ),
    DownloadState.downloading => SearchDownloadViewState(
      status: SearchDownloadStatus.downloading,
      progress: record.progress,
      message: record.progress == null
          ? 'Descargando…'
          : 'Descargando ${(record.progress! * 100).round()} %',
    ),
    DownloadState.completed => const SearchDownloadViewState(
      status: SearchDownloadStatus.completed,
      message: 'Descargada',
    ),
    DownloadState.failed => SearchDownloadViewState(
      status: SearchDownloadStatus.failed,
      message: record.errorMessage ?? 'Descarga fallida',
    ),
    DownloadState.pendingDeletion => const SearchDownloadViewState(
      status: SearchDownloadStatus.pendingDeletion,
      message: 'Pendiente de eliminación',
    ),
  };
}

/// UI integration only: an approved resolver must still override
/// `openDownloadProvider`; Search never treats catalog metadata as permission.
class SearchDownloadController
    extends Notifier<Map<String, SearchDownloadRequestState>> {
  final _inFlight = <String>{};

  @override
  Map<String, SearchDownloadRequestState> build() {
    ref.onDispose(_inFlight.clear);
    return const {};
  }

  Future<SearchDownloadRequestResult> request(Song song) async {
    if (ref.read(dataModeProvider) == DataMode.demo) {
      return const SearchDownloadRequestResult(
        SearchDownloadRequestOutcome.unavailable,
        'La descarga real no está disponible en modo demostración.',
      );
    }
    if (!_inFlight.add(song.id)) {
      return const SearchDownloadRequestResult(
        SearchDownloadRequestOutcome.ignored,
      );
    }

    _setRequest(song.id, const SearchDownloadRequestState(isRequesting: true));
    try {
      late final DownloadSession? session;
      try {
        session = await ref.read(downloadSessionProvider.future);
      } catch (_) {
        const message = 'No se pudo abrir la sesión de descargas.';
        _setError(song.id, message);
        return const SearchDownloadRequestResult(
          SearchDownloadRequestOutcome.unavailable,
          message,
        );
      }
      if (session == null) {
        const message = 'La sesión de descargas no está disponible.';
        _clearRequest(song.id);
        return const SearchDownloadRequestResult(
          SearchDownloadRequestOutcome.unavailable,
          message,
        );
      }

      try {
        final existing = await session.repository.findBySongId(song.id);
        if (existing != null) {
          if (existing.state == DownloadState.failed) {
            await session.repository.retry(song.id);
            _clearRequest(song.id);
            return const SearchDownloadRequestResult(
              SearchDownloadRequestOutcome.requested,
              'Reintento de descarga solicitado.',
            );
          }
          _clearRequest(song.id);
          return const SearchDownloadRequestResult(
            SearchDownloadRequestOutcome.alreadyPresent,
            'La canción ya tiene una solicitud de descarga.',
          );
        }

        await session.repository.enqueue(song);
        _clearRequest(song.id);
        return const SearchDownloadRequestResult(
          SearchDownloadRequestOutcome.requested,
          'Descarga solicitada.',
        );
      } catch (_) {
        const message = 'No se pudo solicitar la descarga. Inténtalo de nuevo.';
        _setError(song.id, message);
        return const SearchDownloadRequestResult(
          SearchDownloadRequestOutcome.failed,
          message,
        );
      }
    } finally {
      _inFlight.remove(song.id);
    }
  }

  void _setRequest(String songId, SearchDownloadRequestState request) {
    state = {...state, songId: request};
  }

  void _setError(String songId, String message) {
    _setRequest(
      songId,
      SearchDownloadRequestState(isRequesting: false, errorMessage: message),
    );
  }

  void _clearRequest(String songId) {
    final next = {...state}..remove(songId);
    state = next;
  }
}

class SearchController extends Notifier<SearchViewState> {
  Timer? _debounce;
  var _requestGeneration = 0;

  @override
  SearchViewState build() {
    ref.onDispose(() {
      _debounce?.cancel();
      _requestGeneration++;
    });
    return _initialState(isDemo: ref.watch(dataModeProvider) == DataMode.demo);
  }

  void queryChanged(String value) {
    _debounce?.cancel();
    final generation = ++_requestGeneration;
    final query = value.trim();
    final isDemo = ref.read(dataModeProvider) == DataMode.demo;
    if (query.isEmpty) {
      state = _initialState(isDemo: isDemo);
      return;
    }

    _debounce = Timer(ref.read(searchDebounceDurationProvider), () {
      unawaited(_runSearch(query, generation, isDemo: isDemo));
    });
  }

  Future<void> retry() {
    final query = state.query.trim();
    if (query.isEmpty) return Future.value();
    _debounce?.cancel();
    final generation = ++_requestGeneration;
    return _runSearch(query, generation, isDemo: state.isDemo);
  }

  Future<void> _runSearch(
    String query,
    int generation, {
    required bool isDemo,
  }) async {
    if (isDemo) {
      final songs = filterSearchSongs(mockSearchSongs, query);
      if (generation != _requestGeneration) return;
      state = SearchViewState(
        query: query,
        status: songs.isEmpty
            ? SearchViewStatus.empty
            : SearchViewStatus.results,
        isDemo: true,
        songs: songs,
      );
      return;
    }

    state = SearchViewState(
      query: query,
      status: SearchViewStatus.loading,
      isDemo: false,
    );
    try {
      final repository = await ref.read(
        commonsCatalogRepositoryProvider.future,
      );
      final outcome = await repository.searchWithContext(query);
      if (generation != _requestGeneration) return;
      state = SearchViewState(
        query: query,
        status: outcome.songs.isEmpty
            ? SearchViewStatus.empty
            : SearchViewStatus.results,
        isDemo: false,
        songs: outcome.songs,
        origin: outcome.origin,
        fallbackReason: outcome.fallbackReason,
      );
    } catch (error) {
      if (generation != _requestGeneration) return;
      state = SearchViewState(
        query: query,
        status: SearchViewStatus.error,
        isDemo: false,
        errorMessage: _errorMessage(error),
      );
    }
  }

  SearchViewState _initialState({required bool isDemo}) => SearchViewState(
    query: '',
    status: SearchViewStatus.initial,
    isDemo: isDemo,
    songs: isDemo ? mockSearchSongs : const [],
  );

  String _errorMessage(Object error) {
    if (error is CatalogStorageException) {
      return 'No se pudo acceder al catálogo guardado.';
    }
    if (error is CommonsApiException) {
      return switch (error.failure) {
        CommonsApiFailure.network => 'No se pudo conectar con Commons.',
        CommonsApiFailure.timeout => 'Commons tardó demasiado en responder.',
        CommonsApiFailure.authentication =>
          'Commons rechazó la autorización de la consulta.',
        CommonsApiFailure.rateLimited =>
          'Commons limitó temporalmente las solicitudes.',
        CommonsApiFailure.server => 'Commons no está disponible temporalmente.',
        CommonsApiFailure.invalidResponse =>
          'Commons devolvió una respuesta no válida.',
      };
    }
    return 'No se pudo completar la búsqueda.';
  }
}
