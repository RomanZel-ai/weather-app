import 'package:shared_preferences/shared_preferences.dart';

class FavoriteCitiesStore {
  static const _key = 'favorite_cities';
  static const _defaultCities = ['Москва', 'Санкт-Петербург', 'Берлин'];

  Future<List<String>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getStringList(_key);

    if (saved == null || saved.isEmpty) {
      return List<String>.from(_defaultCities);
    }

    return saved;
  }

  Future<void> save(List<String> cities) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_key, cities);
  }
}
