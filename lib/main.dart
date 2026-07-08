import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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
  bool _isLocating = false;

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

  Future<void> _loadWeatherForCurrentLocation() async {
    setState(() {
      _isLocating = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw const WeatherApiException(
          'Геолокация выключена. Включи GPS и попробуй ещё раз.',
        );
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw const WeatherApiException(
          'Нет разрешения на геолокацию. Разреши доступ к местоположению.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        throw const WeatherApiException(
          'Геолокация запрещена навсегда. Включи её в настройках приложения.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      if (!mounted) return;

      setState(() {
        _activeCity = 'Моё местоположение';
        _searchController.text = 'Моё местоположение';
        _weatherFuture = _api.fetchWeatherByLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _weatherFuture = Future<WeatherReport>.error(error);
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isLocating = false;
      });
    }
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
                                'Прогноз без VPN и лишней суеты',
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
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: _isLocating
                            ? null
                            : _loadWeatherForCurrentLocation,
                        icon: _isLocating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded),
                        label: Text(
                          _isLocating
                              ? 'Определяю местоположение...'
                              : 'Погода рядом со мной',
                        ),
                      ),
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
                    child: _LoadingState(),
                  );
                }

                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ErrorState(
                      message: _friendlyError(snapshot.error),
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
                      const _SectionTitle(
                        title: 'Ближайшие 24 часа',
                        subtitle: 'Температура и вероятность осадков',
                      ),
                      const SizedBox(height: 12),
                      HourlyForecastStrip(items: report.hourly),
                      const SizedBox(height: 24),
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
            ),
          ],
        ),
      ),
    );
  }
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

  if (text.contains('Геолокация') ||
      text.contains('местополож') ||
      text.contains('Location')) {
    return text.replaceFirst('Exception: ', '');
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
                  color: Colors.black.withOpacity(0.55),
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Color(0xFF1976D2),
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
            style: TextStyle(color: Colors.black.withOpacity(0.56)),
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
