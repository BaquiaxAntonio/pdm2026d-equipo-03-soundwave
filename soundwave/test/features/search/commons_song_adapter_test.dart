import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/features/search/data/commons_song_adapter.dart';

void main() {
  late Object? realResponse;

  setUpAll(() async {
    final fixture = File(
      'test/features/search/fixtures/welcome_to_noxville_response.json',
    );
    realResponse = jsonDecode(await fixture.readAsString());
  });

  test('convierte la respuesta real al Song canónico', () {
    final item = parseCommonsCatalogResponse(realResponse).single;

    expect(item.song.id, 'wikimedia_commons:157450501');
    expect(item.song.sourceId, '157450501');
    expect(item.song.provider, 'wikimedia_commons');
    expect(item.song.title, 'Welcome to Noxville');
    expect(item.song.artist, 'Sir Goose of Honker');
    expect(item.song.durationMs, 6741);
    expect(item.song.artworkUrl, isNull);
    expect(item.mimeType, 'audio/wav');
    expect(item.fileSizeBytes, 647212);
    expect(
      item.mediaUrl,
      Uri.parse(
        'https://upload.wikimedia.org/wikipedia/commons/7/76/'
        'Welcome_to_Noxville.wav?utm_source=commons.wikimedia.org&'
        'utm_campaign=imageinfo&utm_content=original',
      ),
    );
  });

  test('conserva licencia, atribución y página de origen', () {
    final item = parseCommonsCatalogResponse(realResponse).single;

    expect(
      item.sourcePageUrl,
      Uri.parse(
        'https://commons.wikimedia.org/wiki/File:Welcome_to_Noxville.wav',
      ),
    );
    expect(
      item.artistHtml,
      '<a href="//commons.wikimedia.org/wiki/User:Sir_Goose_of_Honker" '
      'title="User:Sir Goose of Honker">Sir Goose of Honker</a>',
    );
    expect(
      item.creditHtml,
      '<span class="int-own-work" lang="en">Own work</span>',
    );
    expect(item.creditText, 'Own work');
    expect(item.licenseShortName, 'CC BY 4.0');
    expect(
      item.licenseUrl,
      Uri.parse('https://creativecommons.org/licenses/by/4.0'),
    );
    expect(item.usageTerms, 'Creative Commons Attribution 4.0');
    expect(item.attributionRequired, isTrue);
    expect(item.copyrighted, isTrue);
    expect(item.restrictions, '');
  });

  test('normaliza HTML, entidades y espacios del autor', () {
    const artistHtml =
        '<span>A&nbsp;&amp; B &#39;C&#x27;</span>\n <b>Music</b>';
    final item = parseCommonsCatalogResponse(
      _response([_validPage(artistValue: artistHtml)]),
    ).single;

    expect(item.song.artist, "A & B 'C' Music");
    expect(item.artistHtml, artistHtml);
  });

  test('mantiene el ID estable cuando cambia la URL', () {
    final first = _validPage();
    final second = _validPage();
    _imageInfo(first)['url'] = 'https://upload.wikimedia.org/old.wav';
    _imageInfo(second)['url'] = 'https://upload.wikimedia.org/new.wav';

    final firstSong = parseCommonsCatalogResponse(
      _response([first]),
    ).single.song;
    final secondSong = parseCommonsCatalogResponse(
      _response([second]),
    ).single.song;

    expect(firstSong.id, secondSong.id);
    expect(firstSong.sourceId, secondSong.sourceId);
    expect(firstSong.id, 'wikimedia_commons:157450501');
  });

  test('usa únicamente imageinfo duration para la duración', () {
    final page = _validPage();
    _imageInfo(page)
      ..remove('duration')
      ..['metadata'] = [
        {'name': 'playtime_seconds', 'value': 99.5},
      ];
    _extendedMetadata(page)['Duration'] = {'value': '99.5'};

    final item = parseCommonsCatalogResponse(_response([page])).single;

    expect(item.song.durationMs, isNull);
  });

  test('trata duraciones inválidas como opcionales', () {
    for (final duration in <Object?>[
      '6.741',
      -1,
      double.infinity,
      double.nan,
    ]) {
      final item = parseCommonsCatalogResponse(
        _response([_validPage(duration: duration)]),
      ).single;
      expect(item.song.durationMs, isNull, reason: 'duration=$duration');
    }
  });

  test('omite registros con campos canónicos obligatorios inválidos', () {
    final withoutPageId = _validPage()..remove('pageid');
    final invalidPages = <Object?>[
      null,
      <String, Object?>{},
      withoutPageId,
      _validPage(pageId: '157450501'),
      _validPage(pageId: 0),
      _validPage(title: 42),
      _validPage(title: 'File:.wav'),
      {
        'pageid': 157450501,
        'title': 'File:Welcome to Noxville.wav',
        'imageinfo': <Object?>[],
      },
      _validPage(artistValue: null),
      _validPage(artistValue: '<span> </span>'),
    ];

    for (final page in invalidPages) {
      expect(
        parseCommonsCatalogResponse(_response([page])),
        isEmpty,
        reason: 'page=$page',
      );
    }
  });

  test('conserva resultados válidos cuando otro registro es inválido', () {
    final items = parseCommonsCatalogResponse(
      _response([
        _validPage(pageId: 'incorrecto'),
        _validPage(pageId: 157450502, title: 'File:Valid track.wav'),
      ]),
    );

    expect(items, hasLength(1));
    expect(items.single.song.id, 'wikimedia_commons:157450502');
    expect(items.single.song.title, 'Valid track');
  });

  test('mantiene el Song aunque falten licencia y URL de descarga', () {
    final item = parseCommonsCatalogResponse(_response([_validPage()])).single;

    expect(item.song.id, 'wikimedia_commons:157450501');
    expect(item.mediaUrl, isNull);
    expect(item.licenseShortName, isNull);
    expect(item.licenseUrl, isNull);
    expect(item.attributionRequired, isNull);
  });

  test('ignora tipos incorrectos en metadatos opcionales', () {
    final page = _validPage();
    _imageInfo(page)
      ..['duration'] = '6.7'
      ..['url'] = 12
      ..['descriptionurl'] = false
      ..['mime'] = <Object?>[]
      ..['size'] = '647212';
    _extendedMetadata(page).addAll({
      'Credit': {'value': 20},
      'LicenseShortName': {'value': false},
      'LicenseUrl': {'value': '/relative/license'},
      'UsageTerms': {'value': <Object?>[]},
      'AttributionRequired': {'value': 'sometimes'},
      'Copyrighted': {'value': 1},
      'Restrictions': {'value': null},
    });

    final item = parseCommonsCatalogResponse(_response([page])).single;

    expect(item.song.durationMs, isNull);
    expect(item.mediaUrl, isNull);
    expect(item.mimeType, isNull);
    expect(item.fileSizeBytes, isNull);
    expect(item.creditHtml, isNull);
    expect(item.licenseShortName, isNull);
    expect(item.licenseUrl, isNull);
    expect(item.usageTerms, isNull);
    expect(item.attributionRequired, isNull);
    expect(item.copyrighted, isNull);
    expect(item.restrictions, isNull);
    expect(
      item.sourcePageUrl,
      Uri.parse('https://commons.wikimedia.org/w/index.php?curid=157450501'),
    );
  });

  test('rechaza un contenedor de respuesta mal formado', () {
    for (final response in <Object?>[
      null,
      <String, Object?>{},
      {'query': <String, Object?>{}},
      {
        'query': {'pages': <String, Object?>{}},
      },
    ]) {
      expect(
        () => parseCommonsCatalogResponse(response),
        throwsFormatException,
        reason: 'response=$response',
      );
    }
  });
}

Map<String, Object?> _response(List<Object?> pages) => {
  'query': {'pages': pages},
};

Map<String, Object?> _validPage({
  Object? pageId = 157450501,
  Object? title = 'File:Welcome to Noxville.wav',
  Object? artistValue = '<b>Sir Goose of Honker</b>',
  Object? duration = 6.741333333333333,
}) => {
  'pageid': pageId,
  'title': title,
  'imageinfo': <Object?>[
    <String, Object?>{
      'duration': duration,
      'extmetadata': <String, Object?>{
        'Artist': <String, Object?>{'value': artistValue},
      },
    },
  ],
};

Map<String, Object?> _imageInfo(Map<String, Object?> page) =>
    (page['imageinfo']! as List<Object?>).single as Map<String, Object?>;

Map<String, Object?> _extendedMetadata(Map<String, Object?> page) =>
    _imageInfo(page)['extmetadata']! as Map<String, Object?>;
