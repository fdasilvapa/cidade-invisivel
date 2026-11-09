import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/mobility_profile.dart';
import 'issue_repository.dart';

/// Preferências do usuário + acesso ao repositório. Exposto via [AppScope].
class AppState extends ChangeNotifier {
  final IssueRepository issues = IssueRepository();
  SharedPreferences? _prefs;

  bool onboarded = false;
  MobilityProfile profile = MobilityProfile.general;
  String displayName = '';
  bool notifyNearby = true;
  bool notifyUpdates = true;
  bool notifyVerification = true;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    onboarded = _prefs!.getBool('onboarded') ?? false;
    profile = MobilityProfile.fromName(_prefs!.getString('profile'));
    displayName = _prefs!.getString('displayName') ?? '';
    notifyNearby = _prefs!.getBool('notifyNearby') ?? true;
    notifyUpdates = _prefs!.getBool('notifyUpdates') ?? true;
    notifyVerification = _prefs!.getBool('notifyVerification') ?? true;
    await issues.load();
  }

  void _persist() {
    final p = _prefs;
    if (p != null) {
      p.setBool('onboarded', onboarded);
      p.setString('profile', profile.name);
      p.setString('displayName', displayName);
      p.setBool('notifyNearby', notifyNearby);
      p.setBool('notifyUpdates', notifyUpdates);
      p.setBool('notifyVerification', notifyVerification);
    }
    notifyListeners();
  }

  void completeOnboarding(MobilityProfile? chosen) {
    if (chosen != null) profile = chosen;
    onboarded = true;
    _persist();
  }

  void setProfile(MobilityProfile p) {
    profile = p;
    _persist();
  }

  void setName(String n) {
    displayName = n.trim();
    _persist();
  }

  void setNotify({bool? nearby, bool? updates, bool? verification}) {
    notifyNearby = nearby ?? notifyNearby;
    notifyUpdates = updates ?? notifyUpdates;
    notifyVerification = verification ?? notifyVerification;
    _persist();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
