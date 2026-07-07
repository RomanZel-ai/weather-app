import 'package:flutter/material.dart';

import '../models/weather.dart';

class HourlyForecastStrip extends StatelessWidget {
  const HourlyForecastStrip({super.key, required this.items});

  final List<HourlyForecast> items;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().subtract(const Duration(hours: 1));
    final nextHours = items.where((item) => item.time.isAfter(now)).take(24).toList();

    return SizedBox(
      height: 126,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: nextHours.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return _HourlyTile(forecast: nextHours[index]);
        },
      ),
    );
  }
}

class _HourlyTile extends StatelessWidget {
  const _HourlyTile({required this.forecast});

  final HourlyForecast forecast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 76,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6EEF6)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _hourLabel(forecast.time),
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.black.withOpacity(0.56),
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            weatherEmoji(forecast.weatherCode),
            style: const TextStyle(fontSize: 26),
          ),
          Text(
            '${forecast.temperature.round()}°',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${forecast.precipitationProbability}%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFF1976D2),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _hourLabel(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    return '$hour:00';
  }
}
