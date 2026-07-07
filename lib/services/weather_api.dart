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
    final city = await _fetchCity(query);
    final forecast = await _fetchForecast(city);

    return WeatherReport(
      city: city,
      current: CurrentWeather.fromJson(
        forecast['current'] as Map<String, dynamic>,
      ),
      hourly: HourlyForecast.listFromJson(
        forecast['hourly'] as Map<String, dynamic>,
      ),
      daily: DailyForecast.listFromJson(
        forecast['daily'] as Map<String, dynamic>,
      ),
    );
  }

  Future<City> _fetchCity(String query) async {
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': query,
      'count': '1',
      'language': 'ru',
      'format': 'json',
    });

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw const WeatherApiException('Не удалось найти город');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final results = decoded['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      throw const WeatherApiException('Город не найден');
    }

    return City.fromJson(results.first as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> _fetchForecast(City city) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': city.latitude.toString(),
      'longitude': city.longitude.toString(),
      'current': [
        'temperature_2m',
        'relative_humidity_2m',
        'apparent_temperature',
        'weather_code',
        'wind_speed_10m',
      ].join(','),
      'hourly': [
        'temperature_2m',
        'precipitation_probability',
        'weather_code',
      ].join(','),
      'daily': [
        'weather_code',
        'temperature_2m_max',
        'temperature_2m_min',
        'precipitation_probability_max',
      ].join(','),
      'timezone': 'auto',
      'forecast_days': '14',
    });

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw const WeatherApiException('Не удалось загрузить прогноз');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
