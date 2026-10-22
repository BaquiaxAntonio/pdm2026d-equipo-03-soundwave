import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/song.dart';
import '../../core/providers/data_mode_provider.dart';
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
