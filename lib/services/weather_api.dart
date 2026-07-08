import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather.dart';

enum WeatherSource {
  wttr,
  yandex,
}

extension WeatherSourceLabel on WeatherSource {
  String get title {
    return switch (this) {
      WeatherSource.wttr => 'wttr.in',
      WeatherSource.yandex => 'Яндекс Погода',
    };
  }
}

class WeatherApiException implements Exception {
  const WeatherApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WeatherApi {
  WeatherApi({http.Client? client}) : _client = client ?? http.Client();

  static const _yandexKey = String.fromEnvironment('YANDEX_WEATHER_KEY');

  final http.Client _client;

  Future<WeatherReport> fetchWeatherByCity(
    String query, {
    WeatherSource source = WeatherSource.wttr,
  }) async {
    final cityName = query.trim();
    if (cityName.isEmpty) {
      throw const WeatherApiException('Введите город');
    }

    if (source == WeatherSource.yandex && _yandexKey.isNotEmpty) {
      try {
        final place = await _resolvePlaceWithWttr(cityName);
        return await _fetchYandexForecast(place);
      } catch (_) {
        return _fetchWttrByCity(cityName);
      }
    }

    return _fetchWttrByCity(cityName);
  }

  Future<WeatherReport> fetchWeatherNearby({
    WeatherSource source = WeatherSource.wttr,
  }) async {
    if (source == WeatherSource.yandex && _yandexKey.isNotEmpty) {
      try {
        final place = await _resolvePlaceWithWttr('');
        return await _fetchYandexForecast(place);
      } catch (_) {
        return _fetchWttrNearby();
      }
    }

    return _fetchWttrNearby();
  }

  Future<WeatherReport> _fetchWttrByCity(String cityName) async {
    final decoded = await _fetchWttrJson(cityName);

    return _parseWttrResponse(
      cityName: cityName,
      body: jsonEncode(decoded),
    );
  }

  Future<WeatherReport> _fetchWttrNearby() async {
    final decoded = await _fetchWttrJson('');

    return _parseWttrResponse(
      cityName: 'Погода рядом',
      body: jsonEncode(decoded),
    );
  }

  Future<Map<String, dynamic>> _fetchWttrJson(String location) async {
    final trimmed = location.trim();
    final path = trimmed.isEmpty ? '' : '/${Uri.encodeComponent(trimmed)}';

    final uri = Uri.parse('https://wttr.in$path?format=j1&lang=ru');

    final response = await _client.get(uri).timeout(
          const Duration(seconds: 12),
        );

    if (response.statusCode != 200) {
      throw const WeatherApiException('Не удалось загрузить прогноз');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<_ResolvedPlace> _resolvePlaceWithWttr(String location) async {
    final decoded = await _fetchWttrJson(location);
    final nearest = decoded['nearest_area'] as List<dynamic>?;

    if (nearest == null || nearest.isEmpty) {
      throw const WeatherApiException('Не удалось определить координаты');
    }

    final area = nearest.first as Map<String, dynamic>;
    final name = _firstListValue(area['areaName']) ??
        (location.trim().isEmpty ? 'Погода рядом' : location.trim());
    final country = _firstListValue(area['country']) ?? '';
    final region = _firstListValue(area['region']) ?? '';

    return _ResolvedPlace(
      name: name,
      country: country.isNotEmpty ? country : region,
      latitude: _doubleValue(area['latitude']),
      longitude: _doubleValue(area['longitude']),
    );
  }

  Future<WeatherReport> _fetchYandexForecast(_ResolvedPlace place) async {
    final uri = Uri.https('api.weather.yandex.ru', '/v2/forecast', {
      'lat': place.latitude.toString(),
      'lon': place.longitude.toString(),
      'lang': 'ru_RU',
      'limit': '3',
      'hours': 'true',
      'extra': 'false',
    });

    final response = await _client.get(
      uri,
      headers: {
        'X-Yandex-Weather-Key': _yandexKey,
      },
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw WeatherApiException(
        'Яндекс Погода не ответила: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseYandexResponse(place: place, decoded: decoded);
  }

  WeatherReport _parseYandexResponse({
    required _ResolvedPlace place,
    required Map<String, dynamic> decoded,
  }) {
    final fact = decoded['fact'] as Map<String, dynamic>;
    final forecastsRaw = decoded['forecasts'] as List<dynamic>? ?? [];

    final city = City(
      name: place.name,
      country: place.country,
      latitude: place.latitude,
      longitude: place.longitude,
    );

    final current = CurrentWeather(
      temperature: _doubleValue(fact['temp']),
      feelsLike: _doubleValue(fact['feels_like']),
      humidity: _intValue(fact['humidity']),
      windSpeed: _doubleValue(fact['wind_speed']),
      weatherCode: _yandexConditionCode(fact['condition']?.toString()),
    );

    final hourly = <HourlyForecast>[];
    final daily = <DailyForecast>[];

    for (final rawForecast in forecastsRaw) {
      final forecast = rawForecast as Map<String, dynamic>;
      final date = DateTime.parse(forecast['date'] as String);
      final parts = forecast['parts'] as Map<String, dynamic>? ?? {};
      final hours = forecast['hours'] as List<dynamic>? ?? [];

      for (final rawHour in hours) {
        final hour = rawHour as Map<String, dynamic>;
        final hourValue = _intValue(hour['hour']);

        hourly.add(
          HourlyForecast(
            time: DateTime(date.year, date.month, date.day, hourValue),
            temperature: _doubleValue(hour['temp']),
            precipitationProbability: _yandexPrecipitationProbability(hour),
            weatherCode: _yandexConditionCode(hour['condition']?.toString()),
          ),
        );
      }

      final dayParts = [
        parts['night'],
        parts['morning'],
        parts['day'],
        parts['evening'],
      ].whereType<Map<String, dynamic>>().toList();

      final representativePart =
          (parts['day_short'] as Map<String, dynamic>?) ??
              (parts['day'] as Map<String, dynamic>?) ??
              (dayParts.isNotEmpty ? dayParts.first : <String, dynamic>{});

      final temps = <double>[];

      for (final part in dayParts) {
        for (final key in ['temp_min', 'temp_max', 'temp_avg', 'temp']) {
          final value = part[key];
          if (value != null) temps.add(_doubleValue(value));
        }
      }

      final minTemp = temps.isEmpty ? current.temperature : temps.reduce(
          (a, b) => a < b ? a : b,
        );
      final maxTemp = temps.isEmpty ? current.temperature : temps.reduce(
          (a, b) => a > b ? a : b,
        );

      var maxPrecipitation = 0;
      for (final part in dayParts) {
        final probability = _yandexPrecipitationProbability(part);
        if (probability > maxPrecipitation) {
          maxPrecipitation = probability;
        }
      }

      daily.add(
        DailyForecast(
          date: date,
          minTemperature: minTemp,
          maxTemperature: maxTemp,
          precipitationProbability: maxPrecipitation,
          weatherCode: _yandexConditionCode(
            representativePart['condition']?.toString(),
          ),
        ),
      );
    }

    return WeatherReport(
      city: city,
      current: current,
      hourly: hourly,
      daily: daily,
    );
  }

  WeatherReport _parseWttrResponse({
    required String cityName,
    required String body,
  }) {
    final decoded = jsonDecode(body) as Map<String, dynamic>;

    final currentRaw = (decoded['current_condition'] as List<dynamic>).first
        as Map<String, dynamic>;

    final weatherDays = decoded['weather'] as List<dynamic>;

    final city = City(
      name: cityName,
      country: '',
      latitude: 0,
      longitude: 0,
    );

    final current = CurrentWeather(
      temperature: _doubleValue(currentRaw['temp_C']),
      feelsLike: _doubleValue(currentRaw['FeelsLikeC']),
      humidity: _intValue(currentRaw['humidity']),
      windSpeed: _doubleValue(currentRaw['windspeedKmph']) / 3.6,
      weatherCode: _intValue(currentRaw['weatherCode']),
    );

    final hourly = <HourlyForecast>[];
    final daily = <DailyForecast>[];

    for (final rawDay in weatherDays) {
      final day = rawDay as Map<String, dynamic>;
      final date = DateTime.parse(day['date'] as String);

      final dayHourly = day['hourly'] as List<dynamic>;

      var maxRainProbability = 0;
      var dayCode = 0;

      for (final rawHour in dayHourly) {
        final hour = rawHour as Map<String, dynamic>;
        final timeRaw = hour['time'].toString().padLeft(4, '0');
        final hourValue = int.parse(timeRaw.substring(0, 2));

        final forecastTime = DateTime(
          date.year,
          date.month,
          date.day,
          hourValue,
        );

        final rainProbability = _intValue(hour['chanceofrain']);
        final code = _intValue(hour['weatherCode']);

        if (rainProbability > maxRainProbability) {
          maxRainProbability = rainProbability;
        }
        if (dayCode == 0) {
          dayCode = code;
        }

        hourly.add(
          HourlyForecast(
            time: forecastTime,
            temperature: _doubleValue(hour['tempC']),
            precipitationProbability: rainProbability,
            weatherCode: code,
          ),
        );
      }

      daily.add(
        DailyForecast(
          date: date,
          minTemperature: _doubleValue(day['mintempC']),
          maxTemperature: _doubleValue(day['maxtempC']),
          precipitationProbability: maxRainProbability,
          weatherCode: dayCode,
        ),
      );
    }

    return WeatherReport(
      city: city,
      current: current,
      hourly: hourly,
      daily: daily,
    );
  }

  int _yandexPrecipitationProbability(Map<String, dynamic> raw) {
    final explicit = raw['prec_prob'];
    if (explicit != null) return _intValue(explicit).clamp(0, 100);

    final type = _intValue(raw['prec_type']);
    final strength = _doubleValue(raw['prec_strength']);

    if (type == 0 || strength <= 0) return 0;

    return (20 + strength * 80).round().clamp(0, 100);
  }

  int _yandexConditionCode(String? condition) {
    return switch (condition) {
      'clear' => 113,
      'partly-cloudy' => 116,
      'cloudy' => 119,
      'overcast' => 122,
      'light-rain' => 296,
      'rain' => 302,
      'heavy-rain' => 308,
      'showers' => 356,
      'wet-snow' => 182,
      'light-snow' => 326,
      'snow' => 332,
      'snow-showers' => 371,
      'hail' => 389,
      'thunderstorm' => 389,
      'thunderstorm-with-rain' => 389,
      'thunderstorm-with-hail' => 389,
      'fog' => 143,
      'mist' => 143,
      _ => 113,
    };
  }

  String? _firstListValue(dynamic raw) {
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map<String, dynamic>) {
        return first['value']?.toString();
      }
    }

    return null;
  }

  double _doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  int _intValue(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}

class _ResolvedPlace {
  const _ResolvedPlace({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String country;
  final double latitude;
  final double longitude;
}
