import 'package:flutter/material.dart';

import 'models/weather.dart';
import 'services/favorite_cities_store.dart';
import 'services/weather_api.dart';
import 'widgets/forecast_card.dart';
import 'widgets/hourly_forecast_strip.dart';
import 'widgets/weather_header.dart';

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WeatherAI',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
        scaffoldBackgroundColor: const Color(0xFFF3F7FB),
      ),
      home: const WeatherHomePage(),
    );
  }
}

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

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
    });
  }

  Future<void> _toggleFavorite(String city) async {
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

  bool _isFavorite(String city) {
    return _favoriteCities.any(
      (item) => item.toLowerCase() == city.toLowerCase(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Column(
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
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Погода, которая не заставляет гадать',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.black.withOpacity(0.55),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filled(
                          tooltip: 'Обновить',
                          onPressed: () => _loadWeather(_activeCity),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SearchField(
                      controller: _searchController,
                      onSubmitted: _loadWeather,
                    ),
                    const SizedBox(height: 14),
                    _FavoriteCitiesBar(
                      cities: _favoriteCities,
                      activeCity: _activeCity,
                      onCityPressed: _loadWeather,
                    ),
                  ],
                ),
              ),
            ),
            FutureBuilder<WeatherReport>(
              future: _weatherFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ErrorState(
                      message: snapshot.error.toString(),
                      onRetry: () => _loadWeather(_searchController.text),
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
                        isFavorite: _isFavorite(report.city.name),
                        onFavoritePressed: () => _toggleFavorite(
                          report.city.name,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _SectionTitle(
                        title: 'Ближайшие 24 часа',
                        subtitle: 'Температура и вероятность осадков',
                      ),
                      const SizedBox(height: 12),
                      HourlyForecastStrip(items: report.hourly),
                      const SizedBox(height: 24),
                      _SectionTitle(
                        title: 'Прогноз на 3 дня',
                        subtitle: 'Максимум / минимум и риск осадков',
                      ),
                      const SizedBox(height: 12),
                      ...report.daily.map((day) => ForecastCard(forecast: day)),
                    ]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
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
        fillColor: Colors.white,
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.black.withOpacity(0.55),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.blueGrey),
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
            style: TextStyle(color: Colors.black.withOpacity(0.56)),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}
