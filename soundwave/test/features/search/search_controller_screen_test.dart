import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/contracts/download_repository.dart';
import 'package:soundwave/core/models/download_record.dart';
import 'package:soundwave/core/models/song.dart';
import 'package:soundwave/core/providers/data_mode_provider.dart';
import 'package:soundwave/features/downloads/download_providers.dart';
import 'package:soundwave/features/search/data/commons_api_client.dart';
import 'package:soundwave/features/search/data/commons_catalog_repository.dart';
import 'package:soundwave/features/search/data/commons_song_adapter.dart';
import 'package:soundwave/features/search/search_controller.dart';
import 'package:soundwave/features/search/search_screen.dart';

void main() {
  testWidgets('debounce ejecuta solamente la última escritura', (tester) async {
    final queries = <String>[];
    final repository = _ControlledRepository((query) async {
      queries.add(query);
      return _outcome([_song(query)]);
    });
    final container = _container(
      repository,
      debounce: const Duration(milliseconds: 300),
    );
    addTearDown(container.dispose);
    final controller = container.read(searchControllerProvider.notifier);

    controller.queryChanged('primera');
    await tester.pump(const Duration(milliseconds: 200));
    controller.queryChanged('segunda');
    await tester.pump(const Duration(milliseconds: 299));
    expect(queries, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(queries, ['segunda']);
    expect(container.read(searchControllerProvider).query, 'segunda');
  });

  testWidgets('una respuesta antigua no sustituye la consulta más reciente', (
    tester,
  ) async {
    final first = Completer<CatalogSearchOutcome>();
    final second = Completer<CatalogSearchOutcome>();
    final repository = _ControlledRepository(
      (query) => query == 'primera' ? first.future : second.future,
    );
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(searchControllerProvider.notifier);

    controller.queryChanged('primera');
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    controller.queryChanged('segunda');
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(repository.calls, 2);

    second.complete(_outcome([_song('resultado nuevo')]));
    await tester.pump();
    await tester.pump();
    expect(
      container.read(searchControllerProvider).songs.single.title,
      'resultado nuevo',
    );

    first.complete(_outcome([_song('resultado antiguo')]));
    await tester.pump();

    final state = container.read(searchControllerProvider);
    expect(state.query, 'segunda');
    expect(state.songs.single.title, 'resultado nuevo');
  });

  testWidgets('limpiar impide publicar una consulta pendiente', (tester) async {
    final pending = Completer<CatalogSearchOutcome>();
    final repository = _ControlledRepository((_) => pending.future);
    final container = _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(searchControllerProvider.notifier);

    controller.queryChanged('pendiente');
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(repository.calls, 1);
    expect(
      container.read(searchControllerProvider).status,
      SearchViewStatus.loading,
    );

    controller.queryChanged('');
    expect(
      container.read(searchControllerProvider).status,
      SearchViewStatus.initial,
    );

    pending.complete(_outcome([_song('no debe mostrarse')]));
    await tester.pump();

    final state = container.read(searchControllerProvider);
    expect(state.status, SearchViewStatus.initial);
    expect(state.query, isEmpty);
    expect(state.songs, isEmpty);
  });

  testWidgets('consulta vacía no accede al repositorio', (tester) async {
    final repository = _ControlledRepository(
      (_) async => throw StateError('No debe ejecutarse.'),
    );
    final container = _container(
      repository,
      debounce: const Duration(milliseconds: 50),
    );
    addTearDown(container.dispose);

    container.read(searchControllerProvider.notifier).queryChanged('   ');
    await tester.pump(const Duration(seconds: 1));

    expect(repository.calls, 0);
    expect(
      container.read(searchControllerProvider).status,
      SearchViewStatus.initial,
    );
  });

  testWidgets('pantalla presenta carga y luego resultados', (tester) async {
    final pending = Completer<CatalogSearchOutcome>();
    final repository = _ControlledRepository((_) => pending.future);
    await _pumpScreen(tester, repository);

    await tester.enterText(find.byType(TextField), 'Noxville');
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(_outcome([_song('Welcome to Noxville')]));
    await tester.pump();

    expect(find.text('Welcome to Noxville'), findsOneWidget);
    expect(find.text('1 resultado'), findsOneWidget);
  });

  testWidgets('pantalla presenta estado vacío', (tester) async {
    final repository = _ControlledRepository((_) async => _outcome([]));
    await _pumpScreen(tester, repository);

    await tester.enterText(find.byType(TextField), 'sin resultados');
    await tester.pumpAndSettle();

    expect(find.text('No encontramos canciones'), findsOneWidget);
    expect(find.text('Prueba con otro título o artista'), findsOneWidget);
  });

  testWidgets('pantalla presenta error y permite reintentar', (tester) async {
    var attempt = 0;
    final repository = _ControlledRepository((_) async {
      attempt++;
      if (attempt == 1) {
        throw CatalogStorageException(
          'search local catalog',
          StateError('database unavailable'),
        );
      }
      return _outcome([_song('Resultado recuperado')]);
    });
    await _pumpScreen(tester, repository);

    await tester.enterText(find.byType(TextField), 'reintento');
    await tester.pumpAndSettle();

    expect(find.text('No pudimos buscar'), findsOneWidget);
    expect(
      find.text('No se pudo acceder al catálogo guardado.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Resultado recuperado'), findsOneWidget);
    expect(attempt, 2);
  });

  testWidgets('fallback por timeout muestra su causa y límite local', (
    tester,
  ) async {
    final repository = _ControlledRepository(
      (_) async => CatalogSearchOutcome(
        songs: [_song('Canción guardada')],
        origin: CatalogResultOrigin.localFallback,
        fallbackReason: CatalogFallbackReason.timeout,
      ),
    );
    await _pumpScreen(tester, repository);

    await tester.enterText(find.byType(TextField), 'guardada');
    await tester.pumpAndSettle();

    expect(find.text('Canción guardada'), findsOneWidget);
    expect(
      find.text(
        'Commons tardó demasiado en responder. '
        'Mostrando solo canciones consultadas anteriormente.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Sin conexión'), findsNothing);
  });

  testWidgets('modo demo se identifica y no crea el repositorio Commons', (
    tester,
  ) async {
    var repositoryReads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataModeProvider.overrideWithValue(DataMode.demo),
          searchDebounceDurationProvider.overrideWithValue(Duration.zero),
          commonsCatalogRepositoryProvider.overrideWith((ref) async {
            repositoryReads++;
            throw StateError('El modo demo no debe leer este proveedor.');
          }),
        ],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );

    expect(find.text('Modo demostración: catálogo de muestra'), findsOneWidget);
    expect(find.text('Sugerencias para ti'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Noche');
    await tester.pumpAndSettle();

    expect(find.text('Noche de código'), findsOneWidget);
    expect(repositoryReads, 0);
  });

  testWidgets('Descargar entrega la canción canónica a enqueue', (
    tester,
  ) async {
    final song = _song('Canción descargable');
    final downloads = _FakeDownloadRepository();
    addTearDown(downloads.dispose);
    await _pumpDownloadScreen(tester, song: song, downloads: downloads);

    await tester.tap(find.byTooltip('Descargar ${song.title}'));
    await tester.pumpAndSettle();

    expect(downloads.enqueued, hasLength(1));
    expect(downloads.enqueued.single, same(song));
  });

  testWidgets('pulsaciones rápidas no duplican enqueue', (tester) async {
    final song = _song('Una sola solicitud');
    final pending = Completer<void>();
    final downloads = _FakeDownloadRepository(enqueuePending: pending);
    addTearDown(downloads.dispose);
    await _pumpDownloadScreen(tester, song: song, downloads: downloads);
    final button = find.byTooltip('Descargar ${song.title}');

    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump();

    expect(downloads.enqueued, hasLength(1));

    pending.complete();
    await tester.pumpAndSettle();
    expect(downloads.enqueued, hasLength(1));
  });

  testWidgets('Search refleja los estados existentes de descarga', (
    tester,
  ) async {
    final song = _song('Canción con estado');
    final downloads = _FakeDownloadRepository();
    addTearDown(downloads.dispose);
    downloads.setRecord(_downloadRecord(song.id, DownloadState.queued));
    await _pumpDownloadScreen(tester, song: song, downloads: downloads);

    expect(find.text('En cola'), findsOneWidget);

    downloads.setRecord(
      _downloadRecord(
        song.id,
        DownloadState.downloading,
        bytesReceived: 50,
        totalBytes: 100,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Descargando 50 %'), findsOneWidget);

    downloads.setRecord(_downloadRecord(song.id, DownloadState.completed));
    await tester.pumpAndSettle();
    expect(find.text('Descargada'), findsOneWidget);

    downloads.setRecord(
      _downloadRecord(
        song.id,
        DownloadState.failed,
        errorMessage: 'Fallo controlado',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fallo controlado'), findsOneWidget);
    expect(
      find.byTooltip('Reintentar descarga de ${song.title}'),
      findsOneWidget,
    );

    downloads.setRecord(
      _downloadRecord(song.id, DownloadState.pendingDeletion),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pendiente de eliminación'), findsOneWidget);
  });

  testWidgets('error de enqueue se comunica sin simular éxito', (tester) async {
    final song = _song('Descarga con error');
    final downloads = _FakeDownloadRepository(
      enqueueError: StateError('transporte no configurado'),
    );
    addTearDown(downloads.dispose);
    await _pumpDownloadScreen(tester, song: song, downloads: downloads);

    await tester.tap(find.byTooltip('Descargar ${song.title}'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('No se pudo solicitar la descarga. Inténtalo de nuevo.'),
      findsWidgets,
    );
    expect(downloads.enqueued, hasLength(1));
  });

  testWidgets('sesión no disponible se explica y no intenta enqueue', (
    tester,
  ) async {
    final song = _song('Sin sesión');
    final repository = _ControlledRepository((_) async => _outcome([song]));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataModeProvider.overrideWithValue(DataMode.localSqlite),
          searchDebounceDurationProvider.overrideWithValue(Duration.zero),
          commonsCatalogRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
          downloadSessionProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );

    await tester.enterText(find.byType(TextField), song.title);
    await tester.pumpAndSettle();

    expect(
      find.text('La sesión de descargas no está disponible.'),
      findsOneWidget,
    );
    await tester.tap(
      find.byTooltip('Información de descarga de ${song.title}'),
    );
    await tester.pump();
    expect(
      find.text('La sesión de descargas no está disponible.'),
      findsWidgets,
    );
  });

  testWidgets('modo demo explica que la descarga real no está disponible', (
    tester,
  ) async {
    var sessionReads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataModeProvider.overrideWithValue(DataMode.demo),
          downloadSessionProvider.overrideWith((ref) async {
            sessionReads++;
            throw StateError('No debe abrir una sesión en modo demo.');
          }),
        ],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );

    expect(
      find.text('La descarga real no está disponible en modo demostración.'),
      findsWidgets,
    );
    await tester.tap(
      find.byTooltip('Información de descarga de Estudio tranquilo'),
    );
    await tester.pump();

    expect(
      find.text('La descarga real no está disponible en modo demostración.'),
      findsWidgets,
    );
    expect(sessionReads, 0);
  });
}

ProviderContainer _container(
  CommonsCatalogRepository repository, {
  Duration debounce = const Duration(milliseconds: 1),
}) => ProviderContainer(
  overrides: [
    dataModeProvider.overrideWithValue(DataMode.localSqlite),
    searchDebounceDurationProvider.overrideWithValue(debounce),
    commonsCatalogRepositoryProvider.overrideWith((ref) async => repository),
  ],
);

Future<void> _pumpScreen(
  WidgetTester tester,
  CommonsCatalogRepository repository,
) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      dataModeProvider.overrideWithValue(DataMode.localSqlite),
      searchDebounceDurationProvider.overrideWithValue(Duration.zero),
      commonsCatalogRepositoryProvider.overrideWith((ref) async => repository),
      downloadSessionProvider.overrideWith((ref) async => null),
    ],
    child: const MaterialApp(home: SearchScreen()),
  ),
);

Future<void> _pumpDownloadScreen(
  WidgetTester tester, {
  required Song song,
  required _FakeDownloadRepository downloads,
}) async {
  final repository = _ControlledRepository((_) async => _outcome([song]));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dataModeProvider.overrideWithValue(DataMode.localSqlite),
        searchDebounceDurationProvider.overrideWithValue(Duration.zero),
        commonsCatalogRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
        downloadSessionProvider.overrideWith(
          (ref) async => DownloadSession(
            downloads,
            (id) async => id == song.id ? song : null,
          ),
        ),
      ],
      child: const MaterialApp(home: SearchScreen()),
    ),
  );
  await tester.enterText(find.byType(TextField), song.title);
  await tester.pumpAndSettle();
}

Song _song(String title) => Song(
  id: 'wikimedia_commons:$title',
  title: title,
  artist: 'Artista',
  durationMs: 60000,
  provider: 'wikimedia_commons',
  sourceId: title,
);

CatalogSearchOutcome _outcome(List<Song> songs) =>
    CatalogSearchOutcome(songs: songs, origin: CatalogResultOrigin.online);

class _ControlledRepository extends CommonsCatalogRepository {
  _ControlledRepository(this.handler)
    : super(remote: const _UnusedSource(), store: const _UnusedStore());

  final Future<CatalogSearchOutcome> Function(String query) handler;
  int calls = 0;

  @override
  Future<CatalogSearchOutcome> searchWithContext(String query) {
    calls++;
    return handler(query);
  }
}

class _UnusedSource implements CommonsCatalogSource {
  const _UnusedSource();

  @override
  Future<CommonsCatalogItem?> findByPageId(String pageId) =>
      throw UnimplementedError();

  @override
  Future<List<CommonsCatalogItem>> search(String query) =>
      throw UnimplementedError();
}

class _UnusedStore implements CatalogSongStore {
  const _UnusedStore();

  @override
  Future<Song?> findById(String songId) => throw UnimplementedError();

  @override
  Future<void> save(Song song) => throw UnimplementedError();

  @override
  Future<List<Song>> search(String query) => throw UnimplementedError();
}

DownloadRecord _downloadRecord(
  String songId,
  DownloadState state, {
  int bytesReceived = 0,
  int? totalBytes,
  String? errorMessage,
}) {
  final now = DateTime(2026);
  return DownloadRecord(
    songId: songId,
    state: state,
    bytesReceived: bytesReceived,
    totalBytes: totalBytes,
    createdAt: now,
    updatedAt: now,
    errorMessage: errorMessage,
  );
}

class _FakeDownloadRepository implements DownloadRepository {
  _FakeDownloadRepository({this.enqueuePending, this.enqueueError});

  final Completer<void>? enqueuePending;
  final Object? enqueueError;
  final enqueued = <Song>[];
  final _records = <String, DownloadRecord>{};
  final _changes = StreamController<List<DownloadRecord>>.broadcast(sync: true);

  void setRecord(DownloadRecord record) {
    _records[record.songId] = record;
    _changes.add(List.unmodifiable(_records.values));
  }

  @override
  Stream<List<DownloadRecord>> watchDownloads() async* {
    yield List.unmodifiable(_records.values);
    yield* _changes.stream;
  }

  @override
  Future<DownloadRecord?> findBySongId(String songId) async => _records[songId];

  @override
  Future<void> enqueue(Song song) async {
    enqueued.add(song);
    final pending = enqueuePending;
    if (pending != null) await pending.future;
    final error = enqueueError;
    if (error != null) throw error;
    setRecord(_downloadRecord(song.id, DownloadState.queued));
  }

  @override
  Future<void> retry(String songId) async {
    setRecord(_downloadRecord(songId, DownloadState.queued));
  }

  @override
  Future<void> requestRemoval(
    String songId, {
    required DateTime undoUntil,
  }) async {
    setRecord(_downloadRecord(songId, DownloadState.pendingDeletion));
  }

  @override
  Future<void> undoRemoval(String songId) async {
    setRecord(_downloadRecord(songId, DownloadState.completed));
  }

  void dispose() {
    _changes.close();
  }
}
