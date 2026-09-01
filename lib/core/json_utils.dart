/// Utilitários para ler o JSON da API.
///
/// A API devolve `camelCase` nos VOs, mas o objeto de usuário que vem
/// dentro do JWT é serializado em `PascalCase`. Estes helpers leem as
/// duas formas sem quebrar.
Object? pick(Map<String, dynamic> json, String key) {
  if (json.containsKey(key)) return json[key];

  final lower = key.toLowerCase();
  for (final entry in json.entries) {
    if (entry.key.toLowerCase() == lower) return entry.value;
  }
  return null;
}

String? asString(Map<String, dynamic> json, String key) {
  final value = pick(json, key);
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || text == 'null' || text == 'Unknown') return null;
  return text;
}

int? asInt(Map<String, dynamic> json, String key) {
  final value = pick(json, key);
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? asDouble(Map<String, dynamic> json, String key) {
  final value = pick(json, key);
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.'));
}

bool asBool(Map<String, dynamic> json, String key, {bool fallback = false}) {
  final value = pick(json, key);
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value.toString().toLowerCase();
  return text == 'true' || text == '1';
}

DateTime? asDate(Map<String, dynamic> json, String key) {
  final value = pick(json, key);
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

/// A API grava as datas em horário de Brasília sem fuso.
/// Enviamos no mesmo formato para o histórico diário bater.
String toApiDate(DateTime date) {
  final utcMinus3 = date.toUtc().subtract(const Duration(hours: 3));
  return utcMinus3.toIso8601String();
}

String toApiDay(DateTime date) => toApiDate(date).substring(0, 10);
