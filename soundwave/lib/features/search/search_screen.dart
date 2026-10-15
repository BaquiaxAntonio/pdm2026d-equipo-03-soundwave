import 'package:flutter/material.dart';

import 'data/mock_songs.dart';
import 'models/song.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _backgroundColor = Color(0xFF0B1220);
  static const _surfaceColor = Color(0xFF172235);
  static const _accentColor = Color(0xFF2DD4BF);
  static const _primaryTextColor = Color(0xFFF8FAFC);
  static const _secondaryTextColor = Color(0xFFCBD5E1);

  final _searchController = TextEditingController();
  String _query = '';

  List<Song> get _visibleSongs {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return mockSongs;
    }

    return mockSongs.where((song) {
      return song.title.toLowerCase().contains(normalizedQuery) ||
          song.artist.toLowerCase().contains(normalizedQuery);
    }).toList();
  }

  bool get _hasQuery => _query.trim().isNotEmpty;

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleSongs = _visibleSongs;
    final baseTheme = Theme.of(context);
    final localTheme = baseTheme.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: _accentColor,
        onPrimary: _backgroundColor,
        surface: _surfaceColor,
        onSurface: _primaryTextColor,
      ),
      scaffoldBackgroundColor: _backgroundColor,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: _accentColor,
        selectionColor: Color(0x662DD4BF),
        selectionHandleColor: _accentColor,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceColor,
        hintStyle: const TextStyle(color: _secondaryTextColor),
        prefixIconColor: _secondaryTextColor,
        suffixIconColor: _secondaryTextColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _accentColor, width: 2),
        ),
      ),
    );

    return Theme(
      data: localTheme,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Buscar música',
                style: TextStyle(
                  color: _primaryTextColor,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Encuentra tu próximo favorito',
                style: TextStyle(color: _secondaryTextColor, fontSize: 16),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                style: const TextStyle(color: _primaryTextColor),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Busca una canción o artista',
                  prefixIcon: const Icon(Icons.search),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          tooltip: 'Limpiar búsqueda',
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _hasQuery
                    ? '${visibleSongs.length} '
                          '${visibleSongs.length == 1 ? 'resultado' : 'resultados'}'
                    : 'Sugerencias para ti',
                style: const TextStyle(
                  color: _primaryTextColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              if (visibleSongs.isEmpty)
                const _EmptyResults()
              else
                ...visibleSongs.map(
                  (song) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SongTile(song: song),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({required this.song});

  final Song song;

  String get _formattedDuration {
    final minutes = song.durationInSeconds ~/ 60;
    final seconds = (song.durationInSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _SearchScreenState._surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _SearchScreenState._accentColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.music_note,
              color: _SearchScreenState._backgroundColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _SearchScreenState._primaryTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _SearchScreenState._secondaryTextColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formattedDuration,
            style: const TextStyle(
              color: _SearchScreenState._secondaryTextColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: _SearchScreenState._accentColor,
          ),
          SizedBox(height: 16),
          Text(
            'No encontramos canciones',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _SearchScreenState._primaryTextColor,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Prueba con otro título o artista',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _SearchScreenState._secondaryTextColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
