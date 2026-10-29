import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/models/song.dart';
import 'package:soundwave/features/search/data/commons_api_client.dart';
import 'package:soundwave/features/search/data/commons_catalog_repository.dart';
import 'package:soundwave/features/search/data/commons_song_adapter.dart';

void main() {
  test('guarda y devuelve resultados online con sus metadatos', () async {
    final item = _item('157450501', title: 'Welcome to Noxville');
    final remote = FakeCommonsCatalogSource()..searchResult = [item];
    final store = FakeCatalogSongStore();
    final repository = CommonsCatalogRepository(remote: remote, store: store);

    final outcome = await repository.searchWithContext('Noxville');

    expect(outcome.origin, CatalogResultOrigin.online);
    expect(outcome.fallbackReason, isNull);
    expect(outcome.songs.single.id, item.song.id);
    expect(outcome.providerItems.single.licenseShortName, 'CC BY 4.0');
    expect(store.saved[item.song.id], same(item.song));
  });

  test('cumple search y saveAll del contrato compartido', () async {
    final first = _item('1', title: 'First');
    final second = _item('2', title: 'Second');
    final remote = FakeCommonsCatalogSource()..searchResult = [first];
    final store = FakeCatalogSongStore();
    final repository = CommonsCatalogRepository(remote: remote, store: store);

    expect((await repository.search('First')).single.id, first.song.id);
    await repository.saveAll([second.song]);

    expect(store.saved.keys, containsAll([first.song.id, second.song.id]));
  });

  test('una respuesta online vacía no se confunde con fallback', () async {
    final remote = FakeCommonsCatalogSource()..searchResult = [];
    final store = FakeCatalogSongStore()
      ..saved[_item('1').song.id] = _item('1').song;
    final repository = CommonsCatalogRepository(remote: remote, store: store);

    final outcome = await repository.searchWithContext('sin coincidencias');

    expect(outcome.origin, CatalogResultOrigin.online);
    expect(outcome.songs, isEmpty);
    expect(store.searchCalls, 0);
  });

  test('usa el catálogo local para una consulta vacía', () async {
    final cached = _item('1', title: 'Cached').song;
    final remote = FakeCommonsCatalogSource();
    final store = FakeCatalogSongStore()..saved[cached.id] = cached;
    final repository = CommonsCatalogRepository(remote: remote, store: store);

    final outcome = await repository.searchWithContext('   ');

    expect(outcome.origin, CatalogResultOrigin.local);
    expect(outcome.songs, [cached]);
    expect(remote.searchCalls, 0);
  });

  test('distingue la causa de cada fallback local', () async {
    final cases = <CommonsApiFailure, CatalogFallbackReason>{
      CommonsApiFailure.network: CatalogFallbackReason.network,
      CommonsApiFailure.timeout: CatalogFallbackReason.timeout,
      CommonsApiFailure.authentication: CatalogFallbackReason.authentication,
      CommonsApiFailure.rateLimited: CatalogFallbackReason.rateLimited,
      CommonsApiFailure.server: CatalogFallbackReason.serviceUnavailable,
      CommonsApiFailure.invalidResponse: CatalogFallbackReason.invalidResponse,
    };
    for (final entry in cases.entries) {
      final cached = _item('1', title: 'Cached').song;
      final remote = FakeCommonsCatalogSource()
        ..searchError = CommonsApiException(entry.key, 'remote failed');
      final store = FakeCatalogSongStore()..saved[cached.id] = cached;
      final repository = CommonsCatalogRepository(remote: remote, store: store);

      final outcome = await repository.searchWithContext('Cached');

      expect(outcome.origin, CatalogResultOrigin.localFallback);
      expect(outcome.fallbackReason, entry.value);
      expect(outcome.songs, [cached]);
      expect(outcome.providerItems, isEmpty);
    }
  });

  test(
    'resultados simultáneos conservan su propia causa de fallback',
    () async {
      final timeout = Completer<List<CommonsCatalogItem>>();
      final quota = Completer<List<CommonsCatalogItem>>();
      final remote = FakeCommonsCatalogSource()
        ..searchHandler = (query) =>
            query == 'slow' ? timeout.future : quota.future;
      final repository = CommonsCatalogRepository(
        remote: remote,
        store: FakeCatalogSongStore(),
      );

      final slowResult = repository.searchWithContext('slow');
      final quotaResult = repository.searchWithContext('quota');
      timeout.completeError(
        const CommonsApiException(CommonsApiFailure.timeout, 'timeout'),
      );
      quota.completeError(
        const CommonsApiException(CommonsApiFailure.rateLimited, 'quota'),
      );

      expect((await slowResult).fallbackReason, CatalogFallbackReason.timeout);
      expect(
        (await quotaResult).fallbackReason,
        CatalogFallbackReason.rateLimited,
      );
    },
  );

  test('no oculta un error al guardar resultados online', () async {
    final remote = FakeCommonsCatalogSource()..searchResult = [_item('1')];
    final store = FakeCatalogSongStore()..saveError = StateError('disk full');
    final repository = CommonsCatalogRepository(remote: remote, store: store);

    await expectLater(
      repository.searchWithContext('audio'),
      throwsA(
        isA<CatalogStorageException>()
            .having(
              (error) => error.operation,
              'operation',
              'save catalog songs',
            )
            .having((error) => error.remoteFailure, 'remoteFailure', isNull),
      ),
    );
  });

  test('no oculta un error del catálogo local durante fallback', () async {
    const remoteFailure = CommonsApiException(
      CommonsApiFailure.network,
      'offline',
    );
    final remote = FakeCommonsCatalogSource()..searchError = remoteFailure;
    final store = FakeCatalogSongStore()
      ..searchError = StateError('database unavailable');
    final repository = CommonsCatalogRepository(remote: remote, store: store);

    await expectLater(
      repository.searchWithContext('audio'),
      throwsA(
        isA<CatalogStorageException>()
            .having(
              (error) => error.operation,
              'operation',
              'search local catalog',
            )
            .having(
              (error) => error.remoteFailure,
              'remoteFailure',
              same(remoteFailure),
            ),
      ),
    );
  });

  test('findById usa primero el catálogo guardado', () async {
    final cached = _item('1').song;
    final remote = FakeCommonsCatalogSource();
    final store = FakeCatalogSongStore()..saved[cached.id] = cached;
    final repository = CommonsCatalogRepository(remote: remote, store: store);

    final found = await repository.findById(cached.id);

    expect(found, same(cached));
    expect(remote.metadataCalls, 0);
  });

  test(
    'findById consulta metadatos Commons y guarda el Song ausente',
    () async {
      final item = _item('157450501');
      final remote = FakeCommonsCatalogSource()..metadataResult = item;
      final store = FakeCatalogSongStore();
      final repository = CommonsCatalogRepository(remote: remote, store: store);

      final found = await repository.findById(item.song.id);

      expect(found?.id, item.song.id);
      expect(remote.lastPageId, '157450501');
      expect(store.saved[item.song.id], same(item.song));
    },
  );

  test('findById no consulta Commons para IDs de otro proveedor', () async {
    final remote = FakeCommonsCatalogSource();
    final repository = CommonsCatalogRepository(
      remote: remote,
      store: FakeCatalogSongStore(),
    );

    expect(await repository.findById('other:1'), isNull);
    expect(remote.metadataCalls, 0);
  });
}

CommonsCatalogItem _item(String sourceId, {String title = 'Track'}) =>
    CommonsCatalogItem(
      song: Song(
        id: 'wikimedia_commons:$sourceId',
        title: title,
        artist: 'Artist',
        provider: 'wikimedia_commons',
        sourceId: sourceId,
      ),
      sourcePageUrl: Uri.parse(
        'https://commons.wikimedia.org/?curid=$sourceId',
      ),
      artistHtml: '<b>Artist</b>',
      licenseShortName: 'CC BY 4.0',
    );

class FakeCommonsCatalogSource implements CommonsCatalogSource {
  List<CommonsCatalogItem> searchResult = const [];
  CommonsCatalogItem? metadataResult;
  Object? searchError;
  Future<List<CommonsCatalogItem>> Function(String query)? searchHandler;
  int searchCalls = 0;
  int metadataCalls = 0;
  String? lastPageId;

  @override
  Future<List<CommonsCatalogItem>> search(String query) async {
    searchCalls++;
    final handler = searchHandler;
    if (handler != null) return handler(query);
    final error = searchError;
    if (error != null) throw error;
    return searchResult;
  }

  @override
  Future<CommonsCatalogItem?> findByPageId(String pageId) async {
    metadataCalls++;
    lastPageId = pageId;
    return metadataResult;
  }
}

class FakeCatalogSongStore implements CatalogSongStore {
  final saved = <String, Song>{};
  Object? saveError;
  Object? searchError;
  int searchCalls = 0;

  @override
  Future<Song?> findById(String songId) async => saved[songId];

  @override
  Future<void> save(Song song) async {
    final error = saveError;
    if (error != null) throw error;
    saved[song.id] = song;
  }

  @override
  Future<List<Song>> search(String query) async {
    searchCalls++;
    final error = searchError;
    if (error != null) throw error;
    final normalized = query.toLowerCase();
    return saved.values
        .where(
          (song) =>
              normalized.isEmpty ||
              song.title.toLowerCase().contains(normalized) ||
              song.artist.toLowerCase().contains(normalized),
        )
        .toList(growable: false);
  }
}
