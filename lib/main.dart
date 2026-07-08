import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/weather.dart';
import 'services/favorite_cities_store.dart';
import 'services/weather_api.dart';
import 'widgets/forecast_card.dart';
import 'widgets/hourly_forecast_strip.dart';
import 'widgets/weather_header.dart';

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatefulWidget {
  const WeatherApp({super.key});

  @override
  State<WeatherApp> createState() => _WeatherAppState();
}

class _WeatherAppState extends State<WeatherApp> {
  static const _themeModeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_themeModeKey);

    if (!mounted) return;

    setState(() {
      _themeMode = switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeModeKey, mode.name);

    if (!mounted) return;

    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WeatherAI',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
        scaffoldBackgroundColor: const Color(0xFFF3F7FB),
        cardColor: Colors.white,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF64B5F6),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
      ),
      home: WeatherHomePage(
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  final _api = WeatherApi();
  final _favoriteStore = FavoriteCitiesStore();
  final _searchController = TextEditingController(text: 'Москва');

  Future<WeatherReport>? _weatherFuture;
  List<String> _favoriteCities = const ['Москва', 'Санкт-Петербург', 'Берлин'];
  String _activeCity = 'Москва';
  bool _isLocating = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _loadWeather(_activeCity);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final favorites = await _favoriteStore.load();
    if (!mounted) return;

    setState(() {
      _favoriteCities = favorites;
    });
  }

  void _loadWeather(String city) {
    final trimmedCity = city.trim();
    if (trimmedCity.isEmpty) return;

    setState(() {
      _activeCity = trimmedCity;
      _searchController.text = trimmedCity;
      _weatherFuture = _api.fetchWeatherByCity(trimmedCity);
      _selectedIndex = 0;
    });
  }

  Future<void> _loadNearbyWeather() async {
    setState(() {
      _isLocating = true;
      _activeCity = 'Погода рядом';
      _searchController.text = 'Погода рядом';
      _weatherFuture = _api.fetchWeatherNearby();
      _selectedIndex = 0;
    });

    try {
      await _weatherFuture;
    } catch (_) {
      // Ошибка будет показана через FutureBuilder.
    } finally {
      if (!mounted) return;
      setState(() {
        _isLocating = false;
      });
    }
  }

  Future<void> _toggleFavorite(String city) async {
    if (city.trim().isEmpty || city == 'Погода рядом') return;

    final nextFavorites = List<String>.from(_favoriteCities);
    final existingIndex = nextFavorites.indexWhere(
      (item) => item.toLowerCase() == city.toLowerCase(),
    );

    if (existingIndex >= 0) {
      nextFavorites.removeAt(existingIndex);
    } else {
      nextFavorites.insert(0, city);
    }

    setState(() {
      _favoriteCities = nextFavorites;
    });

    await _favoriteStore.save(nextFavorites);
  }

  Future<void> _removeFavorite(String city) async {
    final nextFavorites = List<String>.from(_favoriteCities)
      ..removeWhere((item) => item.toLowerCase() == city.toLowerCase());

    setState(() {
      _favoriteCities = nextFavorites;
    });

    await _favoriteStore.save(nextFavorites);
  }

  bool _isFavorite(String city) {
    return _favoriteCities.any(
      (item) => item.toLowerCase() == city.toLowerCase(),
    );
  }

  void _refresh() {
    if (_activeCity == 'Погода рядом') {
      _loadNearbyWeather();
    } else {
      _loadWeather(_activeCity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (_selectedIndex) {
      0 => _TodayTab(
          weatherFuture: _weatherFuture,
          isFavorite: _isFavorite,
          onToggleFavorite: _toggleFavorite,
          onRetry: _refresh,
        ),
      1 => _ForecastTab(
          weatherFuture: _weatherFuture,
          onRetry: _refresh,
        ),
      2 => _FavoritesTab(
          cities: _favoriteCities,
          onCityPressed: _loadWeather,
          onRemoveCity: _removeFavorite,
        ),
      _ => _SettingsTab(
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
        ),
    };

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              sliver: SliverToBoxAdapter(
                child: _TopPanel(
                  activeCity: _activeCity,
                  isLocating: _isLocating,
                  searchController: _searchController,
                  onRefresh: _refresh,
                  onSearch: _loadWeather,
                  onNearby: _loadNearbyWeather,
                  favoriteCities: _favoriteCities,
                  onCityPressed: _loadWeather,
                ),
              ),
            ),
            content,
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny_rounded),
            label: 'Сегодня',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Прогноз',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_border_rounded),
            selectedIcon: Icon(Icons.star_rounded),
            label: 'Избранное',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}

class _TopPanel extends StatelessWidget {
  const _TopPanel({
    required this.activeCity,
    required this.isLocating,
    required this.searchController,
    required this.onRefresh,
    required this.onSearch,
    required this.onNearby,
    required this.favoriteCities,
    required this.onCityPressed,
  });

  final String activeCity;
  final bool isLocating;
  final TextEditingController searchController;
  final VoidCallback onRefresh;
  final ValueChanged<String> onSearch;
  final VoidCallback onNearby;
  final List<String> favoriteCities;
  final ValueChanged<String> onCityPressed;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.58);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WeatherAI',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Прогноз без VPN и лишней суеты',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: mutedColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            IconButton.filled(
              tooltip: 'Обновить',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SearchField(
          controller: searchController,
          onSubmitted: onSearch,
        ),
        const SizedBox(height: 14),
        _FavoriteCitiesBar(
          cities: favoriteCities,
          activeCity: activeCity,
          onCityPressed: onCityPressed,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: isLocating ? null : onNearby,
            icon: isLocating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.near_me_rounded),
            label: Text(
              isLocating ? 'Определяю район...' : 'Погода рядом со мной',
            ),
          ),
        ),
      ],
    );
  }
}

class _TodayTab extends StatelessWidget {
  const _TodayTab({
    required this.weatherFuture,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onRetry,
  });

  final Future<WeatherReport>? weatherFuture;
  final bool Function(String city) isFavorite;
  final ValueChanged<String> onToggleFavorite;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherReport>(
      future: weatherFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: _LoadingState(),
          );
        }

        if (snapshot.hasError) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _ErrorState(
              message: _friendlyError(snapshot.error),
              onRetry: onRetry,
            ),
          );
        }

        final report = snapshot.data;
        if (report == null) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('Нет данных')),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              WeatherHeader(
                report: report,
                isFavorite: isFavorite(report.city.name),
                onFavoritePressed: () => onToggleFavorite(report.city.name),
              ),
              const SizedBox(height: 16),
              _AdviceCard(report: report),
              const SizedBox(height: 24),
              const _SectionTitle(
                title: 'Ближайшие 24 часа',
                subtitle: 'Температура и вероятность осадков',
              ),
              const SizedBox(height: 12),
              HourlyForecastStrip(items: report.hourly),
            ]),
          ),
        );
      },
    );
  }
}

class _ForecastTab extends StatelessWidget {
  const _ForecastTab({
    required this.weatherFuture,
    required this.onRetry,
  });

  final Future<WeatherReport>? weatherFuture;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherReport>(
      future: weatherFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: _LoadingState(),
          );
        }

        if (snapshot.hasError) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _ErrorState(
              message: _friendlyError(snapshot.error),
              onRetry: onRetry,
            ),
          );
        }

        final report = snapshot.data;
        if (report == null) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('Нет данных')),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const _SectionTitle(
                title: 'Прогноз на 3 дня',
                subtitle: 'Максимум / минимум и риск осадков',
              ),
              const SizedBox(height: 12),
              ...report.daily.map((day) => ForecastCard(forecast: day)),
            ]),
          ),
        );
      },
    );
  }
}

class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab({
    required this.cities,
    required this.onCityPressed,
    required this.onRemoveCity,
  });

  final List<String> cities;
  final ValueChanged<String> onCityPressed;
  final ValueChanged<String> onRemoveCity;

  @override
  Widget build(BuildContext context) {
    if (cities.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Пока нет избранных городов.\nНайди город и нажми звёздочку.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      sliver: SliverList.separated(
        itemCount: cities.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const _SectionTitle(
              title: 'Избранные города',
              subtitle: 'Быстрый доступ к нужным прогнозам',
            );
          }

          final city = cities[index - 1];

          return Card(
            elevation: 0,
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.location_city_rounded),
              ),
              title: Text(
                city,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Открыть прогноз'),
              onTap: () => onCityPressed(city),
              trailing: IconButton(
                tooltip: 'Удалить',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => onRemoveCity(city),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          const _SectionTitle(
            title: 'Настройки',
            subtitle: 'Немного управления и информации',
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  onChanged: (value) {
                    if (value != null) onThemeModeChanged(value);
                  },
                  title: const Text('Как в системе'),
                  secondary: const Icon(Icons.phone_android_rounded),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  onChanged: (value) {
                    if (value != null) onThemeModeChanged(value);
                  },
                  title: const Text('Светлая тема'),
                  secondary: const Icon(Icons.light_mode_rounded),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (value) {
                    if (value != null) onThemeModeChanged(value);
                  },
                  title: const Text('Тёмная тема'),
                  secondary: const Icon(Icons.dark_mode_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.cloud_queue_rounded),
              ),
              title: const Text(
                'Источник погоды',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('wttr.in — работает без VPN'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.info_outline_rounded),
              ),
              title: const Text(
                'WeatherAI v1.3',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Нижняя навигация, избранное и настройки'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    final advice = _buildAdvice(report);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                advice.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Совет дня',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(advice.text),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _Advice _buildAdvice(WeatherReport report) {
    final current = report.current;
    final today = report.daily.isNotEmpty ? report.daily.first : null;
    final rain = today?.precipitationProbability ?? 0;

    if (rain >= 65) {
      return const _Advice('☔', 'Лучше взять зонт: риск осадков высокий.');
    }

    if (current.temperature <= -5) {
      return const _Advice('🧣', 'Будет холодно. Шапка и шарф сегодня не лишние.');
    }

    if (current.temperature <= 5) {
      return const _Advice('🧥', 'Прохладно. Лучше надеть тёплую куртку.');
    }

    if (current.windSpeed >= 10) {
      return const _Advice('💨', 'Ветрено. Лёгкие вещи может неплохо потрепать.');
    }

    if (current.temperature >= 27) {
      return const _Advice('🧴', 'Жарко. Вода и солнцезащита — хорошая идея.');
    }

    return const _Advice('👌', 'Погода выглядит спокойной. День без сюрпризов.');
  }
}

class _Advice {
  const _Advice(this.emoji, this.text);

  final String emoji;
  final String text;
}

String _friendlyError(Object? error) {
  final text = error.toString();

  if (text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection') ||
      text.contains('TimeoutException')) {
    return 'Проверь интернет и попробуй ещё раз. Иногда погодный источник отвечает медленно.';
  }

  if (text.contains('Город не найден') || text.contains('Введите город')) {
    return 'Не нашёл такой город. Попробуй написать название по-русски или по-английски.';
  }

  return text.replaceFirst('Exception: ', '');
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: 'Введите город',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          tooltip: 'Найти',
          icon: const Icon(Icons.arrow_forward_rounded),
          onPressed: () => onSubmitted(controller.text),
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _FavoriteCitiesBar extends StatelessWidget {
  const _FavoriteCitiesBar({
    required this.cities,
    required this.activeCity,
    required this.onCityPressed,
  });

  final List<String> cities;
  final String activeCity;
  final ValueChanged<String> onCityPressed;

  @override
  Widget build(BuildContext context) {
    if (cities.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final city = cities[index];
          final selected = city.toLowerCase() == activeCity.toLowerCase();

          return ChoiceChip(
            selected: selected,
            label: Text(city),
            onSelected: (_) => onCityPressed(city),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.58);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: mutedColor,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1976D2).withOpacity(0.25),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '☁️',
                style: TextStyle(fontSize: 48),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'WeatherAI',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Загружаю свежий прогноз...',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.58),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 22),
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.58);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Не получилось загрузить погоду',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: mutedColor),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}
