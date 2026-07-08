import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/weather.dart';
import 'services/favorite_cities_store.dart';
import 'services/weather_api.dart';
import 'widgets/forecast_card.dart';
import 'widgets/hourly_forecast_strip.dart';
import 'widgets/temperature_chart.dart';
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
  static const _lastCityKey = 'last_city';
  static const _lastSourceKey = 'last_source';

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
    _bootstrap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final preferences = await SharedPreferences.getInstance();
    final favorites = await _favoriteStore.load();
    final lastSource = preferences.getString(_lastSourceKey) ?? 'city';
    final lastCity = preferences.getString(_lastCityKey) ?? 'Москва';

    if (!mounted) return;

    setState(() {
      _favoriteCities = favorites;
    });

    if (lastSource == 'nearby') {
      await _loadNearbyWeather(saveSelection: false);
    } else {
      _loadWeather(lastCity, saveSelection: false);
    }
  }

  Future<void> _saveLastSelection(String source, String city) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_lastSourceKey, source);
    await preferences.setString(_lastCityKey, city);
  }

  void _loadWeather(String city, {bool saveSelection = true}) {
    final trimmedCity = city.trim();
    if (trimmedCity.isEmpty) return;

    setState(() {
      _activeCity = trimmedCity;
      _searchController.text = trimmedCity;
      _weatherFuture = _api.fetchWeatherByCity(trimmedCity);
      _selectedIndex = 0;
    });

    if (saveSelection) {
      _saveLastSelection('city', trimmedCity);
    }
  }

  Future<void> _loadNearbyWeather({bool saveSelection = true}) async {
    setState(() {
      _isLocating = true;
      _activeCity = 'Погода рядом';
      _searchController.text = 'Погода рядом';
      _weatherFuture = _api.fetchWeatherNearby();
      _selectedIndex = 0;
    });

    if (saveSelection) {
      await _saveLastSelection('nearby', 'Погода рядом');
    }

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
              const SizedBox(height: 16),
              _SmartAlertsSection(report: report),
              const SizedBox(height: 24),
              const _SectionTitle(
                title: 'Ближайшие 24 часа',
                subtitle: 'Температура и вероятность осадков',
              ),
              const SizedBox(height: 12),
              TemperatureChart(items: report.hourly),
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
                subtitle: 'Нажми на день, чтобы увидеть детали',
              ),
              const SizedBox(height: 12),
              ...report.daily.map(
                (day) => ForecastCard(
                  forecast: day,
                  showChevron: true,
                  onTap: () => _showDayDetails(context, report, day),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  void _showDayDetails(
    BuildContext context,
    WeatherReport report,
    DailyForecast day,
  ) {
    final hours = report.hourly.where((hour) {
      return _sameDate(hour.time, day.date);
    }).toList();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return _DayDetailsSheet(day: day, hours: hours);
      },
    );
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DayDetailsSheet extends StatelessWidget {
  const _DayDetailsSheet({
    required this.day,
    required this.hours,
  });

  final DailyForecast day;
  final List<HourlyForecast> hours;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 18;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPadding),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                title: _dayTitle(day.date),
                subtitle: '${weatherDescription(day.weatherCode)} · осадки до ${day.precipitationProbability}%',
              ),
              const SizedBox(height: 14),
              ForecastCard(forecast: day),
              const SizedBox(height: 10),
              _PartTile(title: 'Ночь', emoji: '🌙', hours: _partHours(0, 6)),
              _PartTile(title: 'Утро', emoji: '🌅', hours: _partHours(6, 12)),
              _PartTile(title: 'День', emoji: '☀️', hours: _partHours(12, 18)),
              _PartTile(title: 'Вечер', emoji: '🌆', hours: _partHours(18, 24)),
            ],
          ),
        ),
      ),
    );
  }

  List<HourlyForecast> _partHours(int from, int to) {
    return hours.where((hour) => hour.time.hour >= from && hour.time.hour < to).toList();
  }

  String _dayTitle(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) return 'Детали на сегодня';
    if (target == today.add(const Duration(days: 1))) return 'Детали на завтра';

    const weekdays = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
    return weekdays[date.weekday - 1];
  }
}

class _PartTile extends StatelessWidget {
  const _PartTile({
    required this.title,
    required this.emoji,
    required this.hours,
  });

  final String title;
  final String emoji;
  final List<HourlyForecast> hours;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.58);

    if (hours.isEmpty) {
      return Card(
        elevation: 0,
        child: ListTile(
          leading: CircleAvatar(child: Text(emoji)),
          title: Text(title),
          subtitle: const Text('Нет данных'),
        ),
      );
    }

    final avgTemp = hours.map((hour) => hour.temperature).reduce((a, b) => a + b) / hours.length;
    final maxRain = hours.map((hour) => hour.precipitationProbability).reduce((a, b) => a > b ? a : b);
    final code = hours[hours.length ~/ 2].weatherCode;

    return Card(
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(child: Text(emoji)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${weatherDescription(code)} · осадки до $maxRain%',
          style: TextStyle(color: mutedColor),
        ),
        trailing: Text(
          '${avgTemp.round()}°',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
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
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: _SectionTitle(
                  title: 'Избранные города',
                  subtitle: 'Быстрый доступ к нужным прогнозам',
                ),
              );
            }

            final city = cities[index - 1];

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
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
              ),
            );
          },
          childCount: cities.length + 1,
        ),
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
          const _InfoCard(
            icon: Icons.notifications_active_outlined,
            title: 'Умные уведомления',
            subtitle: 'Пока внутри приложения: дождь, ветер, холод и жара',
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            icon: Icons.cloud_queue_rounded,
            title: 'Источник погоды',
            subtitle: 'wttr.in — работает без VPN',
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            icon: Icons.info_outline_rounded,
            title: 'WeatherAI v1.4',
            subtitle: 'Последний город, график, уведомления и детали дня',
          ),
        ]),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle),
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

class _SmartAlertsSection extends StatelessWidget {
  const _SmartAlertsSection({required this.report});

  final WeatherReport report;

  @override
  Widget build(BuildContext context) {
    final alerts = _buildAlerts(report);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Умные уведомления',
          subtitle: 'Важное по погоде на ближайшее время',
        ),
        const SizedBox(height: 12),
        ...alerts.map((alert) => _AlertCard(alert: alert)),
      ],
    );
  }

  List<_WeatherAlert> _buildAlerts(WeatherReport report) {
    final alerts = <_WeatherAlert>[];
    final current = report.current;
    final today = report.daily.isNotEmpty ? report.daily.first : null;
    final tomorrow = report.daily.length > 1 ? report.daily[1] : null;

    final rain = today?.precipitationProbability ?? 0;

    if (rain >= 65) {
      alerts.add(
        const _WeatherAlert(
          '☔',
          'Высокий риск дождя',
          'Зонт сегодня лучше взять с собой.',
        ),
      );
    }

    if (current.windSpeed >= 10) {
      alerts.add(
        const _WeatherAlert(
          '💨',
          'Сильный ветер',
          'Будь аккуратнее на улице и с лёгкими вещами.',
        ),
      );
    }

    if (current.temperature <= 0) {
      alerts.add(
        const _WeatherAlert(
          '🥶',
          'Холодно',
          'Лучше одеться теплее, особенно утром и вечером.',
        ),
      );
    }

    if (current.temperature >= 27) {
      alerts.add(
        const _WeatherAlert(
          '🥵',
          'Жарко',
          'Пей воду и избегай долгого солнца.',
        ),
      );
    }

    if (today != null && tomorrow != null) {
      final drop = today.maxTemperature - tomorrow.maxTemperature;
      if (drop >= 5) {
        alerts.add(
          _WeatherAlert(
            '📉',
            'Завтра похолодает',
            'Максимальная температура ниже примерно на ${drop.round()}°.',
          ),
        );
      }
    }

    if (alerts.isEmpty) {
      alerts.add(
        const _WeatherAlert(
          '✅',
          'Без погодных тревог',
          'Пока ничего критичного не видно.',
        ),
      );
    }

    return alerts;
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final _WeatherAlert alert;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(child: Text(alert.emoji)),
        title: Text(
          alert.title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(alert.text),
      ),
    );
  }
}

class _WeatherAlert {
  const _WeatherAlert(this.emoji, this.title, this.text);

  final String emoji;
  final String title;
  final String text;
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
