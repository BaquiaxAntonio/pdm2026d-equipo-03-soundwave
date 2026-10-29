import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/song.dart';
import 'search_controller.dart';
import 'search_theme_local.dart';
import 'song_row_local.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _textController.clear();
    ref.read(searchControllerProvider.notifier).queryChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(searchControllerProvider);
    return Scaffold(
      backgroundColor: SearchThemeLocal.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth < 360
                ? SearchThemeLocal.space16
                : SearchThemeLocal.space24;
            return Center(
              child: ConstrainedBox(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Buscar música',
                            style: SearchThemeLocal.screenTitle,
                          ),
                          const SizedBox(height: SearchThemeLocal.space4),
                          const Text(
                            'Encuentra tu próximo favorito',
                            style: SearchThemeLocal.artist,
                          ),
                          if (search.isDemo) ...[
                            const SizedBox(height: SearchThemeLocal.space8),
                            const _DemoBadge(),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontal),
                      child: TextSelectionTheme(
                        data: const TextSelectionThemeData(
                          cursorColor: SearchThemeLocal.accent,
                          selectionColor: SearchThemeLocal.surfaceElevated,
                          selectionHandleColor: SearchThemeLocal.accent,
                        ),
                        child: ListenableBuilder(
                          listenable: _textController,
                          builder: (context, _) {
                            final hasText = _textController.text.isNotEmpty;
                            return TextField(
                              controller: _textController,
                              onChanged: ref
                                  .read(searchControllerProvider.notifier)
                                  .queryChanged,
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
                                            constraints: const BoxConstraints(
                                              minWidth: 48,
                                              minHeight: 48,
                                            ),
                                            icon: const Icon(Icons.clear),
                                            color:
                                                SearchThemeLocal.textSecondary,
                                            onPressed: _clearSearch,
                                          )
                                        : null,
                                  ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: SearchThemeLocal.space12),
                    Expanded(child: _SearchContent(state: search)),
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

class _DemoBadge extends StatelessWidget {
  const _DemoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SearchThemeLocal.space8,
        vertical: SearchThemeLocal.space4,
      ),
      decoration: BoxDecoration(
        color: SearchThemeLocal.surfaceElevated,
        borderRadius: BorderRadius.circular(SearchThemeLocal.buttonRadius),
        border: Border.all(color: SearchThemeLocal.accent),
      ),
      child: const Text(
        'Modo demostración: catálogo de muestra',
        style: TextStyle(
          color: SearchThemeLocal.accent,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SearchContent extends StatelessWidget {
  const _SearchContent({required this.state});

  final SearchViewState state;

  @override
  Widget build(BuildContext context) {
    final notice = state.fallbackMessage;
    return Column(
      children: [
        if (notice != null) _CatalogNotice(message: notice),
        Expanded(child: _content()),
      ],
    );
  }

  Widget _content() => switch (state.status) {
    SearchViewStatus.initial when state.isDemo => _SuggestionsList(
      results: state.songs,
    ),
    SearchViewStatus.initial => const _InitialState(),
    SearchViewStatus.loading => const _LoadingState(),
    SearchViewStatus.results => _ResultsList(results: state.songs),
    SearchViewStatus.empty => const _EmptyState(),
    SearchViewStatus.error => _ErrorState(
      message: state.errorMessage ?? 'No se pudo completar la búsqueda.',
    ),
  };
}

class _CatalogNotice extends StatelessWidget {
  const _CatalogNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        SearchThemeLocal.space24,
        0,
        SearchThemeLocal.space24,
        SearchThemeLocal.space8,
      ),
      padding: const EdgeInsets.all(SearchThemeLocal.space12),
      decoration: BoxDecoration(
        color: SearchThemeLocal.surface,
        borderRadius: BorderRadius.circular(SearchThemeLocal.buttonRadius),
        border: Border.all(color: SearchThemeLocal.surfaceElevated),
      ),
      child: Text(message, style: SearchThemeLocal.artist),
    );
  }
}

class _SuggestionsList extends StatelessWidget {
  const _SuggestionsList({required this.results});

  final List<Song> results;

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
  const _ResultsList({required this.results});

  final List<Song> results;

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

class _InitialState extends StatelessWidget {
  const _InitialState();

  @override
  Widget build(BuildContext context) {
    return const _CenteredState(
      icon: Icons.library_music_outlined,
      semanticLabel: 'Buscar en Commons',
      title: 'Busca por título o artista',
      message: 'Escribe para consultar el catálogo de Wikimedia Commons',
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: SearchThemeLocal.accent,
        semanticsLabel: 'Buscando canciones',
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const _CenteredState(
      icon: Icons.search_off,
      semanticLabel: 'Sin resultados',
      title: 'No encontramos canciones',
      message: 'Prueba con otro título o artista',
    );
  }
}

class _ErrorState extends ConsumerWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _CenteredState(
      icon: Icons.error_outline,
      semanticLabel: 'Error de búsqueda',
      title: 'No pudimos buscar',
      message: message,
      action: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: SearchThemeLocal.accent,
          foregroundColor: SearchThemeLocal.onAccent,
        ),
        onPressed: () => ref.read(searchControllerProvider.notifier).retry(),
        icon: const Icon(Icons.refresh),
        label: const Text('Reintentar'),
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.semanticLabel,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String semanticLabel;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SearchThemeLocal.space24),
      children: [
        const SizedBox(height: SearchThemeLocal.space32),
        Icon(
          icon,
          size: 48,
          color: SearchThemeLocal.textSecondary,
          semanticLabel: semanticLabel,
        ),
        const SizedBox(height: SearchThemeLocal.space16),
        Text(
          title,
          style: SearchThemeLocal.sectionTitle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: SearchThemeLocal.space8),
        Text(
          message,
          style: SearchThemeLocal.artist,
          textAlign: TextAlign.center,
        ),
        if (action != null) ...[
          const SizedBox(height: SearchThemeLocal.space16),
          Center(child: action),
        ],
      ],
    );
  }
}
