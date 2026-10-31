import 'package:flutter/material.dart';

import '../models/player_playlist.dart';
import '../player_song_local.dart';

/// El padre resuelve la persistencia y devuelve un mensaje si no puede guardar.
class PlayerPlaylistForm extends StatefulWidget {
  const PlayerPlaylistForm({
    super.key,
    this.initial,
    required this.onSave,
    this.availableSongs = const [],
    this.initialSongIds = const [],
  });

  final PlayerPlaylist? initial;
  final Future<String?> Function(String name, List<String> songIds) onSave;
  final List<PlayerSongLocal> availableSongs;
  final List<String> initialSongIds;

  @override
  State<PlayerPlaylistForm> createState() => _PlayerPlaylistFormState();
}

class _PlayerPlaylistFormState extends State<PlayerPlaylistForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  final _selectedIds = <String>{};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _selectedIds.addAll(widget.initialSongIds);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    String? error;
    try {
      final songIds = widget.availableSongs
          .where((song) => _selectedIds.contains(song.id))
          .map((song) => song.id)
          .toList();
      error = await widget.onSave(_name.text.trim(), songIds);
    } catch (_) {
      error = 'No se pudo guardar la lista. Intenta de nuevo.';
    }
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(widget.initial == null ? 'Nueva lista' : 'Editar lista'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Escribe un nombre para la lista.'
                    : null,
                onFieldSubmitted: (_) => _save(),
              ),
              if (widget.availableSongs.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Elige las canciones de esta lista'),
                Wrap(
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                              _selectedIds.addAll(
                                widget.availableSongs.map((song) => song.id),
                              );
                            }),
                      child: const Text('Seleccionar todas'),
                    ),
                    TextButton(
                      onPressed: _saving || _selectedIds.isEmpty
                          ? null
                          : () => setState(_selectedIds.clear),
                      child: const Text('Limpiar selección'),
                    ),
                  ],
                ),
                Text('${_selectedIds.length} seleccionadas'),
                for (final song in widget.availableSongs)
                  CheckboxListTile(
                    key: ValueKey('playlist-song:${song.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(song.title),
                    subtitle: Text(song.artist),
                    value: _selectedIds.contains(song.id),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                            if (value == true) {
                              _selectedIds.add(song.id);
                            } else {
                              _selectedIds.remove(song.id);
                            }
                          }),
                  ),
              ],
              if (widget.availableSongs.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    'No hay canciones disponibles. Agrega canciones a la cola para poder seleccionarlas aquí.',
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(
            _saving
                ? 'Guardando…'
                : widget.initial == null
                ? 'Crear'
                : 'Guardar cambios',
          ),
        ),
      ],
    ),
  );
}
