import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_profiles.dart';
import 'models.dart';

class LocalStore extends ChangeNotifier {
  LocalStore(this.preferences) {
    final records = readJsonList(preferences.getString('profiles'));
    try {
      _profiles = records.map(LocalProfile.fromJson).toList();
      if (_profiles.isEmpty || !_profiles.any((p) => p.id == 'default')) {
        _profiles = [
          const LocalProfile(id: 'default', name: '管理员', admin: true),
        ];
      }
    } catch (_) {
      _profiles = [const LocalProfile(id: 'default', name: '管理员', admin: true)];
    }
    _current = preferences.getString('activeProfile') ?? 'default';
    if (!_profiles.any((p) => p.id == _current)) _current = 'default';
    _locked = profile.protected;
    _loadLibrary();
  }
  final SharedPreferences preferences;
  final Map<String, WatchEntry> _history = {};
  final Map<String, Drama> _favorites = {};
  Future<void> _writes = Future<void>.value();
  late List<LocalProfile> _profiles;
  String _current = 'default';
  bool _locked = false;
  int _epoch = 0;
  int _failures = 0;
  DateTime _retryAfter = DateTime(2000);

  List<LocalProfile> get profiles => List.unmodifiable(_profiles);
  LocalProfile get profile => _profiles.firstWhere((p) => p.id == _current);
  bool get locked => _locked;
  int get profileEpoch => _epoch;
  bool get canDownload => !locked && (profile.admin || profile.download);
  bool allowsSource(String source) =>
      !locked && SourceSite.isAvailable(source) && profile.allows(source);
  List<SourceSite> get sources =>
      SourceSite.values.where((s) => allowsSource(s.id)).toList();
  String _key(String key, [String? id]) =>
      (id ?? _current) == 'default' ? key : 'profile.${id ?? _current}.$key';

  void _loadLibrary() {
    _history.clear();
    _favorites.clear();
    for (final row in readJsonList(preferences.getString(_key('history')))) {
      try {
        final entry = WatchEntry.fromJson(row);
        _history[entry.drama.id] = entry;
      } catch (_) {}
    }
    for (final row in readJsonList(preferences.getString(_key('favorites')))) {
      try {
        final drama = Drama.fromJson(row);
        _favorites[drama.id] = drama;
      } catch (_) {}
    }
  }

  List<WatchEntry> get history =>
      _history.values.where((e) => allowsSource(e.drama.source)).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  List<Drama> get favorites => _favorites.values
      .where((d) => allowsSource(d.source))
      .toList()
      .reversed
      .toList();
  WatchEntry? watched(String id) {
    final entry = _history[id];
    return entry != null && allowsSource(entry.drama.source) ? entry : null;
  }

  bool isFavorite(String id) {
    final drama = _favorites[id];
    return drama != null && allowsSource(drama.source);
  }

  bool get hideVip => preferences.getBool(_key('hideVip')) ?? true;
  String get displayMode => preferences.getString('displayMode') ?? 'auto';
  String get themeMode {
    final saved = preferences.getString('themeMode');
    return {'light', 'dark', 'system'}.contains(saved) ? saved! : 'system';
  }

  bool get autoExport => preferences.getBool('autoExport') ?? false;
  bool get exportPosters => preferences.getBool('exportPosters') ?? false;
  Future<void> setExportPosters(bool value) async {
    _requireAdmin();
    await preferences.setBool('exportPosters', value);
    notifyListeners();
  }

  String get source {
    final saved = preferences.getString(_key('source')) ?? '';
    if (sources.any((s) => s.id == saved)) return saved;
    return sources.isEmpty ? '' : sources.first.id;
  }

  Future<void> setSource(String value) async {
    if (!allowsSource(value)) throw StateError('当前用户没有此站源权限');
    await preferences.setString(_key('source'), value);
  }

  Future<void> setDisplayMode(String value) async {
    if (!{'auto', 'television', 'standard'}.contains(value)) return;
    await preferences.setString('displayMode', value);
    notifyListeners();
  }

  Future<void> setThemeMode(String value) async {
    if (!{'light', 'dark', 'system'}.contains(value)) return;
    await preferences.setString('themeMode', value);
    notifyListeners();
  }

  Future<void> setAutoExport(bool value) async {
    _requireAdmin();
    await preferences.setBool('autoExport', value);
    notifyListeners();
  }

  Future<void> setHideVip(bool value) async {
    if (locked) return;
    await preferences.setBool(_key('hideVip'), value);
    notifyListeners();
  }

  Future<void> toggleFavorite(Drama drama) async {
    if (!allowsSource(drama.source)) return;
    if (_favorites.containsKey(drama.id)) {
      _favorites.remove(drama.id);
    } else {
      _favorites[drama.id] = drama;
    }
    notifyListeners();
    final key = _key('favorites');
    final content = jsonEncode(
      _favorites.values.map((e) => e.toJson()).toList(),
    );
    await _queue(() async {
      await preferences.setString(key, content);
    });
  }

  Future<void> saveWatch(WatchEntry entry) async {
    if (!allowsSource(entry.drama.source)) return;
    _history[entry.drama.id] = entry;
    if (_history.length > 300) {
      final entries = _history.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      for (final old in entries.skip(300)) {
        _history.remove(old.drama.id);
      }
    }
    notifyListeners();
    final key = _key('history');
    final content = jsonEncode(_history.values.map((e) => e.toJson()).toList());
    await _queue(() async {
      await preferences.setString(key, content);
    });
  }

  WatchEntry? mediaWatched(String id) {
    try {
      final data =
          jsonDecode(preferences.getString(_key('mediaHistory')) ?? '{}')
              as Map;
      return data[id] == null
          ? null
          : WatchEntry.fromJson(Map<String, dynamic>.from(data[id] as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveMediaWatch(String id, WatchEntry entry) async {
    if (!canDownload || !allowsSource(entry.drama.source)) return;
    final key = _key('mediaHistory');
    await _queue(() async {
      final data = jsonDecode(preferences.getString(key) ?? '{}') as Map;
      data.remove(id);
      data[id] = entry.toJson();
      while (data.length > 300) {
        data.remove(data.keys.first);
      }
      await preferences.setString(key, jsonEncode(data));
    });
  }

  Future<void> clearHistory() async {
    if (locked) return;
    _history.clear();
    notifyListeners();
    final key = _key('history');
    await _queue(() async {
      await preferences.remove(key);
    });
  }

  Future<void> refreshDrama(Drama drama) async {
    if (!allowsSource(drama.source)) return;
    final favorite = _favorites.containsKey(drama.id);
    final watched = _history[drama.id];
    if (!favorite && watched == null) return;
    if (favorite) _favorites[drama.id] = drama;
    if (watched != null) {
      _history[drama.id] = WatchEntry(
        drama: drama,
        episode: watched.episode,
        position: watched.position,
        duration: watched.duration,
        updatedAt: watched.updatedAt,
      );
    }
    final favorites = jsonEncode(
      _favorites.values.map((item) => item.toJson()).toList(),
    );
    final history = jsonEncode(
      _history.values.map((item) => item.toJson()).toList(),
    );
    final favoriteKey = _key('favorites'), historyKey = _key('history');
    notifyListeners();
    await _queue(() async {
      await preferences.setString(favoriteKey, favorites);
      await preferences.setString(historyKey, history);
    });
  }

  void _requireAdmin() {
    if (locked || !profile.admin) throw StateError('仅管理员可以修改此设置');
  }

  Future<void> switchProfile(String id, {String pin = ''}) async {
    if (DateTime.now().isBefore(_retryAfter)) {
      throw StateError('密码输入过于频繁，请稍后再试');
    }
    final target = _profiles.firstWhere((p) => p.id == id);
    if (!await checkProfilePin(target, pin)) {
      _failures++;
      if (_failures >= 3) {
        _retryAfter = DateTime.now().add(
          Duration(seconds: (_failures * 2).clamp(0, 30)),
        );
      }
      throw StateError('密码不正确');
    }
    await _writes;
    _failures = 0;
    _current = id;
    _locked = false;
    await preferences.setString('activeProfile', id);
    _loadLibrary();
    _epoch++;
    notifyListeners();
  }

  void lock() {
    if (!profile.protected) return;
    _locked = true;
    _epoch++;
    notifyListeners();
  }

  Future<void> saveProfile({
    String? id,
    required String name,
    required List<String> sources,
    required bool download,
    String? pin,
  }) async {
    _requireAdmin();
    final old = _profiles.where((p) => p.id == id).firstOrNull;
    final targetId = old?.id ?? randomProfileToken();
    final cleanName = name.trim();
    if (cleanName.isEmpty || cleanName.length > 40) {
      throw StateError('用户名需要 1 至 40 个字符');
    }
    if (sources.any(
      (s) => !SourceSite.knownValues.any((site) => site.id == s),
    )) {
      throw StateError('站源无效');
    }
    if (targetId != 'default' &&
        !_profiles.firstWhere((p) => p.admin).protected) {
      throw StateError('请先为管理员设置密码，再创建或修改其他用户');
    }
    if (old == null && _profiles.length >= 20) {
      throw StateError('最多支持 20 个本地用户');
    }
    var salt = old?.salt ?? '', hash = old?.pinHash ?? '';
    if (pin != null) {
      if (pin.isEmpty) {
        if (targetId == 'default' && _profiles.length > 1) {
          throw StateError('存在其他用户时不能取消管理员密码');
        }
        salt = '';
        hash = '';
      } else {
        if (pin.length < 6 || pin.length > 128) {
          throw StateError('密码需要 6 至 128 个字符');
        }
        salt = randomProfileToken();
        hash = await hashProfilePin(pin, salt);
      }
    }
    final updated = LocalProfile(
      id: targetId,
      name: cleanName,
      admin: targetId == 'default',
      sources: sources.toSet().toList(),
      download: download,
      salt: salt,
      pinHash: hash,
    );
    _profiles =
        [
          for (final p in _profiles)
            if (p.id != targetId) p,
          updated,
        ]..sort(
          (a, b) => a.admin
              ? -1
              : b.admin
              ? 1
              : a.name.compareTo(b.name),
        );
    await preferences.setString(
      'profiles',
      jsonEncode(_profiles.map((p) => p.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> deleteProfile(String id) async {
    _requireAdmin();
    if (id == 'default') throw StateError('不能删除管理员');
    _profiles.removeWhere((p) => p.id == id);
    for (final key in [
      'history',
      'favorites',
      'source',
      'hideVip',
      'mediaHistory',
    ]) {
      await preferences.remove(_key(key, id));
    }
    await preferences.setString(
      'profiles',
      jsonEncode(_profiles.map((p) => p.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<String> exportBackup() async {
    _requireAdmin();
    await _writes;
    return jsonEncode({
      'schema': 1,
      'app': 'zhenguojian',
      'profiles': _profiles.map((p) => p.toJson()).toList(),
      'displayMode': displayMode,
      'themeMode': themeMode,
      'autoExport': autoExport,
      'exportPosters': exportPosters,
      'libraries': {
        for (final profile in _profiles)
          profile.id: {
            'history': readJsonList(
              preferences.getString(_key('history', profile.id)),
            ),
            'mediaHistory': jsonDecode(
              preferences.getString(_key('mediaHistory', profile.id)) ?? '{}',
            ),
            'favorites': readJsonList(
              preferences.getString(_key('favorites', profile.id)),
            ),
            'source': preferences.getString(_key('source', profile.id)) ?? '',
            'hideVip': preferences.getBool(_key('hideVip', profile.id)) ?? true,
          },
      },
    });
  }

  Map<String, dynamic> validateBackup(String content) {
    if (utf8.encode(content).length > 8 * 1024 * 1024) {
      throw const FormatException('备份文件过大');
    }
    final data = jsonDecode(content) as Map<String, dynamic>;
    if (data['schema'] != 1 || data['app'] != 'zhenguojian') {
      throw const FormatException('不支持的备份格式');
    }
    final profiles = (data['profiles'] as List)
        .map((p) => LocalProfile.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();
    if (profiles.isEmpty ||
        profiles.length > 20 ||
        profiles.map((p) => p.id).toSet().length != profiles.length ||
        profiles.where((p) => p.admin).length != 1 ||
        (profiles.length > 1 &&
            !profiles.firstWhere((p) => p.admin).protected)) {
      throw const FormatException('备份用户配置无效');
    }
    if (data.containsKey('themeMode') &&
        !{'light', 'dark', 'system'}.contains(data['themeMode'])) {
      throw const FormatException('备份主题设置无效');
    }
    final libraries = data['libraries'] as Map;
    for (final p in profiles) {
      final library = libraries[p.id] as Map;
      final history = library['history'] as List,
          favorites = library['favorites'] as List;
      final media = library['mediaHistory'] as Map? ?? {};
      if (media.length > 300) throw const FormatException('本地观看记录过多');
      for (final value in media.values) {
        WatchEntry.fromJson(Map<String, dynamic>.from(value as Map));
      }
      if (history.length > 300 || favorites.length > 20000) {
        throw const FormatException('备份记录过多');
      }
      for (final row in history) {
        WatchEntry.fromJson(Map<String, dynamic>.from(row as Map));
      }
      for (final row in favorites) {
        Drama.fromJson(Map<String, dynamic>.from(row as Map));
      }
      if (library['hideVip'] is! bool || library['source'] is! String) {
        throw const FormatException('备份设置无效');
      }
    }
    return data;
  }

  Future<void> importBackup(String content) async {
    _requireAdmin();
    final data = validateBackup(content);
    await _writes;
    final profiles = (data['profiles'] as List)
        .map((p) => LocalProfile.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();
    final libraries = data['libraries'] as Map;
    for (final p in profiles) {
      final library = libraries[p.id] as Map;
      await preferences.setString(
        _key('history', p.id),
        jsonEncode(library['history']),
      );
      await preferences.setString(
        _key('mediaHistory', p.id),
        jsonEncode(library['mediaHistory'] ?? {}),
      );
      await preferences.setString(
        _key('favorites', p.id),
        jsonEncode(library['favorites']),
      );
      await preferences.setString(
        _key('source', p.id),
        library['source'] as String,
      );
      await preferences.setBool(
        _key('hideVip', p.id),
        library['hideVip'] as bool,
      );
    }
    for (final old in _profiles.where(
      (old) => !profiles.any((p) => p.id == old.id),
    )) {
      for (final key in [
        'history',
        'favorites',
        'source',
        'hideVip',
        'mediaHistory',
      ]) {
        await preferences.remove(_key(key, old.id));
      }
    }
    _profiles = profiles;
    await preferences.setString(
      'profiles',
      jsonEncode(profiles.map((p) => p.toJson()).toList()),
    );
    await preferences.setString('activeProfile', 'default');
    final mode = data['displayMode'];
    await preferences.setString(
      'displayMode',
      {'auto', 'television', 'standard'}.contains(mode)
          ? mode as String
          : 'auto',
    );
    await preferences.setString(
      'themeMode',
      data['themeMode'] as String? ?? themeMode,
    );
    await preferences.setBool('autoExport', data['autoExport'] == true);
    await preferences.setBool('exportPosters', data['exportPosters'] == true);
    _current = 'default';
    _locked = profile.protected;
    _loadLibrary();
    _epoch++;
    notifyListeners();
  }

  Future<void> _queue(Future<void> Function() action) {
    _writes = _writes.catchError((Object _) {}).then((_) => action());
    return _writes;
  }
}
