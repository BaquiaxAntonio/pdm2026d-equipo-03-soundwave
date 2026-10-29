import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppTab { home, search, player, downloads }

final activeTabProvider = NotifierProvider<ActiveTabNotifier, AppTab>(
  ActiveTabNotifier.new,
);

class ActiveTabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.home;

  void select(AppTab tab) => state = tab;
}
