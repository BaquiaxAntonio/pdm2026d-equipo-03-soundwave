import 'package:flutter/material.dart';

import 'mock_search_data.dart';
import 'search_filter_local.dart';
import 'search_song_local.dart';
import 'search_theme_local.dart';
import 'song_row_local.dart';

// Pantalla de búsqueda con propuesta visual SoundWave aplicada.
// Motivo: buscador sticky + lista desplazable; filtrado local inmediato
// sin cargas artificiales; estados inicial / resultados / vacío claros.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SearchThemeLocal.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Margen 24 habitual, 16 en pantallas muy estrechas.
            final horizontal = constraints.maxWidth < 360
                ? SearchThemeLocal.space16
                : SearchThemeLocal.space24;
            return Center(
              child: ConstrainedBox(
                // En ventanas amplias limita y centra para evitar filas largas.
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        SearchThemeLocal.space16,
                        horizontal,
                        SearchThemeLocal.space12,
                      ),
                      // Encabezado compacto para no restar espacio a la lista.
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Buscar música',
                            style: SearchThemeLocal.screenTitle,
                          ),
                          SizedBox(height: SearchThemeLocal.space4),
                          Text(
                            'Encuentra tu próximo favorito',
                            style: SearchThemeLocal.artist,
                          ),
                        ],
                      ),
                    ),
                    // Buscador siempre visible; la lista desplaza debajo.
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontal),
                      child: TextSelectionTheme(
                        data: const TextSelectionThemeData(
                          cursorColor: SearchThemeLocal.accent,
                          selectionColor: SearchThemeLocal.surfaceElevated,
                          selectionHandleColor: SearchThemeLocal.accent,
                        ),
                        child: ListenableBuilder(
                          listenable: _controller,
                          builder: (context, _) {
                            final hasText = _controller.text.isNotEmpty;
                            return TextField(
                              controller: _controller,
                              style: const TextStyle(
                                fontSize: 16,
                                color: SearchThemeLocal.textPrimary,
                              ),
                              cursorColor: SearchThemeLocal.accent,
                              decoration:
                                  SearchThemeLocal.searchDecoration(
                                    hasText: hasText,
                                  ).copyWith(
                                    suffixIcon: hasText
                                        ? IconButton(
                                            tooltip: 'Limpiar búsqueda',
                                            // Área táctil mínima 48x48.
                                            constraints: const BoxConstraints(
                                              minWidth: 48,
                                              minHeight: 48,
                                            ),
                                            icon: const Icon(Icons.clear),
                                            color:
                                                SearchThemeLocal.textSecondary,
                                            onPressed: _controller.clear,
                                          )
                                        : null,
                                  ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: SearchThemeLocal.space12),
                    Expanded(
                      child: ListenableBuilder(
                        listenable: _controller,
                        builder: (context, _) {
                          final query = _controller.text;
                          final results = filterSearchSongs(
                            mockSearchSongs,
                            query,
                          );
                          if (query.trim().isEmpty) {
                            return _SuggestionsList(results: results);
                          }
                          if (results.isEmpty) {
                            return const _EmptyState();
                          }
                          return _ResultsList(results: results);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SuggestionsList extends StatelessWidget {
  final List<SearchSongLocal> results;

  const _SuggestionsList({required this.results});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: SearchThemeLocal.space32),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: SearchThemeLocal.space24,
            vertical: SearchThemeLocal.space8,
          ),
          child: Text(
            'Sugerencias para ti',
            style: SearchThemeLocal.sectionTitle,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: SearchThemeLocal.space24),
          child: Text(
            // No se presenta como personalización real.
            'Selección de muestra, no personalizada',
            style: SearchThemeLocal.auxiliary,
          ),
        ),
        const SizedBox(height: SearchThemeLocal.space8),
        for (final song in results) SongRowLocal(song: song),
      ],
    );
  }
}

class _ResultsList extends StatelessWidget {
  final List<SearchSongLocal> results;

  const _ResultsList({required this.results});

  @override
  Widget build(BuildContext context) {
    final count = results.length;
    final label = count == 1 ? '1 resultado' : '$count resultados';
    return ListView(
      padding: const EdgeInsets.only(bottom: SearchThemeLocal.space32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SearchThemeLocal.space24,
            vertical: SearchThemeLocal.space8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Resultados', style: SearchThemeLocal.sectionTitle),
              const SizedBox(height: SearchThemeLocal.space4),
              Text(label, style: SearchThemeLocal.auxiliary),
            ],
          ),
        ),
        for (final song in results) SongRowLocal(song: song),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SearchThemeLocal.space24),
      children: const [
        SizedBox(height: SearchThemeLocal.space32),
        Icon(
          Icons.search_off,
          size: 48,
          color: SearchThemeLocal.textSecondary,
          semanticLabel: 'Sin resultados',
        ),
        SizedBox(height: SearchThemeLocal.space16),
        Text(
          'No encontramos canciones',
          style: SearchThemeLocal.sectionTitle,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: SearchThemeLocal.space8),
        Text(
          'Prueba con otro título o artista',
          style: SearchThemeLocal.artist,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
