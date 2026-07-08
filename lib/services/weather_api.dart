import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather.dart';

class WeatherApiException implements Exception {
  const WeatherApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WeatherApi {
  WeatherApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<WeatherReport> fetchWeatherByCity(String query) async {
    final cityName = query.trim();
    if (cityName.isEmpty) {
      throw const WeatherApiException('Введите город');
    }

    final uri = Uri.parse(
      'https://wttr.in/${Uri.encodeComponent(cityName)}?format=j1&lang=ru',
    );

    final response = await _client.get(uri).timeout(
          const Duration(seconds: 12),
        );

    if (response.statusCode != 200) {
      throw const WeatherApiException('Не удалось загрузить прогноз');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    final currentRaw =
        (decoded['current_condition'] as List<dynamic>).first as Map<String, dynamic>;

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

  double _doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  int _intValue(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}
