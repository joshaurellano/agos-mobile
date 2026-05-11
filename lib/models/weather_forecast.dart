class WeatherForecast {
  final String time;
  final String condition;
  final String icon;
  final String temp;
  final int rainChance;
  final String wind;

  const WeatherForecast({
    required this.time,
    required this.condition,
    required this.icon,
    required this.temp,
    required this.rainChance,
    required this.wind,
  });
}