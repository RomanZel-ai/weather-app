import 'package:flutter/material.dart';

import '../models/weather.dart';

class ForecastCard extends StatelessWidget {
  const ForecastCard({
    super.key,
    required this.forecast,
    this.onTap,
    this.showChevron = false,
  });

  final DailyForecast forecast;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withOpacity(0.62);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 58,
                child: Text(
                  _dayLabel(forecast.date),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                weatherEmoji(forecast.weatherCode),
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  weatherDescription(forecast.weatherCode),
                  style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${forecast.maxTemperature.round()}° / ${forecast.minTemperature.round()}°',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'осадки ${forecast.precipitationProbability}%',
                    style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
                  ),
                ],
              ),
              if (showChevron) ...[
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: mutedColor),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    if (target == today) return 'Сегодня';
    if (target == today.add(const Duration(days: 1))) return 'Завтра';

    const labels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return labels[date.weekday - 1];
  }
}
