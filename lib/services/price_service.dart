import 'dart:convert';
import 'package:http/http.dart' as http;

class PriceService {
  static const String _coingeckoBaseUrl = 'https://api.coingecko.com/api/v3';

  static Future<double?> fetchCurrentPrice(String coingeckoTokenId) async {
    try {
      final response = await http.get(Uri.parse(
          '$_coingeckoBaseUrl/simple/price?ids=$coingeckoTokenId&vs_currencies=usd'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey(coingeckoTokenId) && data[coingeckoTokenId].containsKey('usd')) {
          return data[coingeckoTokenId]['usd']?.toDouble();
        }
      }
    } catch (e) {
      print('Error fetching current price for $coingeckoTokenId: $e');
    }
    return null;
  }

  static Future<double?> fetchHistoricalPrice(String coingeckoTokenId, DateTime date) async {
    final formattedDate = '${date.day}-${date.month}-${date.year}';
    try {
      final response = await http.get(Uri.parse(
          '$_coingeckoBaseUrl/coins/$coingeckoTokenId/history?date=$formattedDate&localization=false'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('market_data') && data['market_data'].containsKey('current_price') && data['market_data']['current_price'].containsKey('usd')) {
          return data['market_data']['current_price']['usd']?.toDouble();
        }
      }
    } catch (e) {
      print('Error fetching historical price for $coingeckoTokenId on $formattedDate: $e');
    }
    return null;
  }
}