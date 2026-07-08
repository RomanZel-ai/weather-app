class City {
  const City({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String country;
  final double latitude;
  final double longitude;

  String get title => country.isEmpty ? name : '$name, $country';

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      name: json['name'] as String? ?? '',
      country: json['country'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class CurrentWeather {
  const CurrentWeather({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
  });

  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int weatherCode;

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    return CurrentWeather(
      temperature: (json['temperature_2m'] as num).toDouble(),
      feelsLike: (json['apparent_temperature'] as num).toDouble(),
      humidity: (json['relative_humidity_2m'] as num).toInt(),
      windSpeed: (json['wind_speed_10m'] as num).toDouble(),
      weatherCode: (json['weather_code'] as num).toInt(),
    );
  }
}

class HourlyForecast {
  const HourlyForecast({
    required this.time,
    required this.temperature,
    required this.precipitationProbability,
    required this.weatherCode,
  });

  final DateTime time;
  final double temperature;
  final int precipitationProbability;
  final int weatherCode;

  static List<HourlyForecast> listFromJson(Map<String, dynamic> json) {
    final times = List<String>.from(json['time'] as List<dynamic>);
    final temperatures = List<num>.from(json['temperature_2m'] as List<dynamic>);
    final precipitation = List<num>.from(
      json['precipitation_probability'] as List<dynamic>,
    );
    final codes = List<num>.from(json['weather_code'] as List<dynamic>);

    return List<HourlyForecast>.generate(times.length, (index) {
      return HourlyForecast(
        time: DateTime.parse(times[index]),
        temperature: temperatures[index].toDouble(),
        precipitationProbability: precipitation[index].toInt(),
        weatherCode: codes[index].toInt(),
      );
    });
  }
}

class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.minTemperature,
    required this.maxTemperature,
    required this.precipitationProbability,
    required this.weatherCode,
  });

  final DateTime date;
  final double minTemperature;
  final double maxTemperature;
  final int precipitationProbability;
  final int weatherCode;

  static List<DailyForecast> listFromJson(Map<String, dynamic> json) {
    final dates = List<String>.from(json['time'] as List<dynamic>);
    final minTemps = List<num>.from(json['temperature_2m_min'] as List<dynamic>);
    final maxTemps = List<num>.from(json['temperature_2m_max'] as List<dynamic>);
    final precipitation = List<num>.from(
      json['precipitation_probability_max'] as List<dynamic>,
    );
    final codes = List<num>.from(json['weather_code'] as List<dynamic>);

    return List<DailyForecast>.generate(dates.length, (index) {
      return DailyForecast(
        date: DateTime.parse(dates[index]),
        minTemperature: minTemps[index].toDouble(),
        maxTemperature: maxTemps[index].toDouble(),
        precipitationProbability: precipitation[index].toInt(),
        weatherCode: codes[index].toInt(),
      );
    });
  }
}

class WeatherReport {
  const WeatherReport({
    required this.city,
    required this.current,
    required this.hourly,
    required this.daily,
  });

  final City city;
  final CurrentWeather current;
  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;
}

String weatherDescription(int code) {
  if (code == 0 || code == 113) return 'Ясно';
  if (code == 1 || code == 2 || code == 3 || code == 116) {
    return 'Переменная облачность';
  }
  if (code == 119) return 'Облачно';
  if (code == 122) return 'Пасмурно';
  if (code == 45 || code == 48 || code == 143 || code == 248 || code == 260) {
    return 'Туман';
  }
  if ([176, 263, 266, 281, 284, 293, 296, 299, 302, 305, 308, 311, 314, 353, 356, 359].contains(code)) {
    return 'Дождь';
  }
  if ([179, 182, 185, 227, 230, 317, 320, 323, 326, 329, 332, 335, 338, 368, 371].contains(code)) {
    return 'Снег';
  }
  if ([200, 386, 389, 392, 395].contains(code)) return 'Гроза';

  if (code >= 51 && code <= 67) return 'Дождь';
  if (code >= 71 && code <= 86) return 'Снег';
  if (code >= 95 && code <= 99) return 'Гроза';

  return 'Погода';
}

String weatherEmoji(int code) {
  if (code == 0 || code == 113) return '☀️';
  if (code == 1 || code == 2 || code == 3 || code == 116) return '⛅';
  if (code == 119 || code == 122) return '☁️';
  if (code == 45 || code == 48 || code == 143 || code == 248 || code == 260) {
    return '🌫️';
  }
  if ([176, 263, 266, 281, 284, 293, 296, 299, 302, 305, 308, 311, 314, 353, 356, 359].contains(code)) {
    return '🌧️';
  }
  if ([179, 182, 185, 227, 230, 317, 320, 323, 326, 329, 332, 335, 338, 368, 371].contains(code)) {
    return '❄️';
  }
  if ([200, 386, 389, 392, 395].contains(code)) return '⛈️';

  if (code >= 51 && code <= 67) return '🌧️';
  if (code >= 71 && code <= 86) return '❄️';
  if (code >= 95 && code <= 99) return '⛈️';

  return '🌡️';
}
