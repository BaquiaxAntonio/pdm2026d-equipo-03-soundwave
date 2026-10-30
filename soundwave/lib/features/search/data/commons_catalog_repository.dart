import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts/catalog_repository.dart';
import '../../../core/database/dao_providers.dart';
import '../../../core/database/song_dao.dart';
import '../../../core/models/song.dart';
import 'commons_api_client.dart';
import 'commons_song_adapter.dart';

enum CatalogResultOrigin { online, local, localFallback }

enum CatalogFallbackReason {
  network,
  timeout,
  authentication,
  rateLimited,
  serviceUnavailable,
  invalidResponse,
}

/// Per-request result details; concurrent searches never share mutable status.
class CatalogSearchOutcome {
  CatalogSearchOutcome({
    required Iterable<Song> songs,
    required this.origin,
    this.fallbackReason,
    Iterable<CommonsCatalogItem> providerItems = const [],
  }) : songs = List.unmodifiable(songs),
       providerItems = List.unmodifiable(providerItems);

  final List<Song> songs;
  final CatalogResultOrigin origin;
  final CatalogFallbackReason? fallbackReason;

  /// Provider-specific metadata retained for download and license decisions.
  final List<CommonsCatalogItem> providerItems;
}

class CatalogStorageException implements Exception {
  const CatalogStorageException(
    this.operation,
    this.cause, {
    this.remoteFailure,
  });

  final String operation;
  final Object cause;
  final CommonsApiException? remoteFailure;

  @override
  String toString() => 'CatalogStorageException($operation): $cause';
}

abstract interface class CatalogSongStore {
  Future<List<Song>> search(String query);

  Future<Song?> findById(String songId);

  Future<void> save(Song song);
}

class SongDaoCatalogStore implements CatalogSongStore {
  const SongDaoCatalogStore(this.dao);

  final SongDao dao;

  @override
  Future<List<Song>> search(String query) => dao.search(query);

  @override
  Future<Song?> findById(String songId) => dao.findById(songId);

  @override
  Future<void> save(Song song) => dao.upsert(song);
}

class CommonsCatalogRepository implements CatalogRepository {
  const CommonsCatalogRepository({required this.remote, required this.store});

  final CommonsCatalogSource remote;
  final CatalogSongStore store;

  @override
  Future<List<Song>> search(String query) async =>
      (await searchWithContext(query)).songs;

  Future<CatalogSearchOutcome> searchWithContext(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return CatalogSearchOutcome(
        songs: await _localSearch(normalizedQuery),
        origin: CatalogResultOrigin.local,
      );
    }

    try {
      final items = await remote.search(normalizedQuery);
      final songs = items.map((item) => item.song).toList(growable: false);
      await saveAll(songs);
      return CatalogSearchOutcome(
        songs: songs,
        origin: CatalogResultOrigin.online,
        providerItems: items,
      );
    } on CommonsApiException catch (error) {
      return CatalogSearchOutcome(
        songs: await _localSearch(normalizedQuery, remoteFailure: error),
        origin: CatalogResultOrigin.localFallback,
        fallbackReason: _fallbackReason(error.failure),
      );
    }
  }

  @override
  Future<Song?> findById(String songId) async {
    final local = await _localFindById(songId);
    if (local != null) return local;

    const prefix = 'wikimedia_commons:';
    if (!songId.startsWith(prefix)) return null;
    final sourceId = songId.substring(prefix.length);
    final item = await remote.findByPageId(sourceId);
    if (item == null) return null;
    await saveAll([item.song]);
    return item.song;
  }

  @override
  Future<void> saveAll(Iterable<Song> songs) async {
    try {
      for (final song in songs) {
        await store.save(song);
      }
    } catch (error) {
      if (error is CatalogStorageException) rethrow;
      throw CatalogStorageException('save catalog songs', error);
    }
  }

  Future<List<Song>> _localSearch(
    String query, {
    CommonsApiException? remoteFailure,
  }) async {
    try {
      return await store.search(query);
    } catch (error) {
      if (error is CatalogStorageException) rethrow;
      throw CatalogStorageException(
        'search local catalog',
        error,
        remoteFailure: remoteFailure,
      );
    }
  }

  Future<Song?> _localFindById(String songId) async {
    try {
      return await store.findById(songId);
    } catch (error) {
      if (error is CatalogStorageException) rethrow;
      throw CatalogStorageException('find local catalog song', error);
    }
  }

  CatalogFallbackReason _fallbackReason(
    CommonsApiFailure failure,
  ) => switch (failure) {
    CommonsApiFailure.network => CatalogFallbackReason.network,
    CommonsApiFailure.timeout => CatalogFallbackReason.timeout,
    CommonsApiFailure.authentication => CatalogFallbackReason.authentication,
    CommonsApiFailure.rateLimited => CatalogFallbackReason.rateLimited,
    CommonsApiFailure.server => CatalogFallbackReason.serviceUnavailable,
    CommonsApiFailure.invalidResponse => CatalogFallbackReason.invalidResponse,
  };
}

final commonsApiClientProvider = Provider<CommonsApiClient>(
  (ref) => CommonsApiClient(),
);

final commonsCatalogRepositoryProvider =
    FutureProvider<CommonsCatalogRepository>((ref) async {
      final dao = await ref.watch(songDaoProvider.future);
      return CommonsCatalogRepository(
        remote: ref.watch(commonsApiClientProvider),
        store: SongDaoCatalogStore(dao),
      );
    });
