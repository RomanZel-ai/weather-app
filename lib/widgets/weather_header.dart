import 'package:flutter/material.dart';

import '../models/weather.dart';

class WeatherHeader extends StatelessWidget {
  const WeatherHeader({
    super.key,
    required this.report,
    required this.isFavorite,
    required this.onFavoritePressed,
  });

  final WeatherReport report;
  final bool isFavorite;
  final VoidCallback onFavoritePressed;

  @override
  Widget build(BuildContext context) {
    final current = report.current;
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: _gradientForCode(current.weatherCode),
        boxShadow: [
          BoxShadow(
            color: _shadowColorForCode(current.weatherCode),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  report.city.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: isFavorite ? 'Убрать из избранного' : 'В избранное',
                onPressed: onFavoritePressed,
                icon: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                weatherEmoji(current.weatherCode),
                style: const TextStyle(fontSize: 56),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${current.temperature.round()}°',
                      style: theme.textTheme.displayLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 0.9,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      weatherDescription(current.weatherCode),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white.withOpacity(0.92),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricChip(
                label: 'Ощущается',
                value: '${current.feelsLike.round()}°',
              ),
              _MetricChip(label: 'Влажность', value: '${current.humidity}%'),
              _MetricChip(
                label: 'Ветер',
                value: '${current.windSpeed.round()} м/с',
              ),
            ],
          ),
        ],
      ),
    );
  }

  LinearGradient _gradientForCode(int code) {
    final isRain = [
      176,
      263,
      266,
      281,
      284,
      293,
      296,
      299,
      302,
      305,
      308,
      311,
      314,
      353,
      356,
      359,
    ].contains(code);

    final isSnow = [
      179,
      182,
      185,
      227,
      230,
      317,
      320,
      323,
      326,
      329,
      332,
      335,
      338,
      368,
      371,
    ].contains(code);

    final isThunder = [200, 386, 389, 392, 395].contains(code);

    if (isThunder) {
      return const LinearGradient(
        colors: [Color(0xFF263238), Color(0xFF5C6BC0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    if (isRain) {
      return const LinearGradient(
        colors: [Color(0xFF1565C0), Color(0xFF455A64)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    if (isSnow) {
      return const LinearGradient(
        colors: [Color(0xFF90CAF9), Color(0xFF5E92F3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    if (code == 119 || code == 122) {
      return const LinearGradient(
        colors: [Color(0xFF607D8B), Color(0xFF90A4AE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    return const LinearGradient(
      colors: [Color(0xFF1976D2), Color(0xFF64B5F6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  Color _shadowColorForCode(int code) {
    if ([200, 386, 389, 392, 395].contains(code)) {
      return const Color(0xFF263238).withOpacity(0.25);
    }

    if (code == 119 || code == 122) {
      return const Color(0xFF607D8B).withOpacity(0.22);
    }

    return const Color(0xFF1976D2).withOpacity(0.22);
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
