import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

// ================================================
// GROQ SERVICE
//
// Handles all AI calls to Groq API
// Used for:
//   - Sales Trend Prediction
//   - AI Trending Shoes
//   - Restock Prediction
//   - Product Replacement
// ================================================
class GroqService {

  // Groq API endpoint
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  // model to use — fast and free
  static const String _model = 'llama3-70b-8192';

  // get API key from .env
  String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';

  // ================================================
  // SEND MESSAGE TO GROQ
  // base method used by all AI features
  // always returns JSON string
  // ================================================
  Future<String> _sendMessage(String systemPrompt, String userMessage) async {
    try {

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': systemPrompt,
            },
            {
              'role': 'user',
              'content': userMessage,
            },
          ],
          'temperature': 0.3,
          'max_tokens': 1024,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        return content;
      } else {
        print('Groq API error: ${response.statusCode} ${response.body}');
        return '';
      }

    } catch (error) {
      print('Groq service error: $error');
      return '';
    }
  }

  // ================================================
  // GET SALES TREND PREDICTION
  // sends monthly sales data → gets prediction
  // ================================================
  Future<List<double>> getSalesTrendPrediction({
    required List<double> monthlySales,
  }) async {
    try {

      final systemPrompt = '''
You are a retail sales analyst AI. 
Analyze the given monthly sales data and predict the next 3 months.
Return ONLY a JSON array of 3 numbers representing predicted sales.
No explanation. No markdown. Just the JSON array.
Example: [2500000, 2700000, 2900000]
''';

      final userMessage = '''
Monthly sales data (in PHP): ${monthlySales.toString()}
Predict the next 3 months of sales.
''';

      final result = await _sendMessage(systemPrompt, userMessage);

      if (result.isEmpty) return [];

      // clean the response and parse JSON
      final cleaned = result
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final List<dynamic> parsed = jsonDecode(cleaned);
      return parsed.map((e) => (e as num).toDouble()).toList();

    } catch (error) {
      print('getSalesTrendPrediction error: $error');
      return [];
    }
  }

  // ================================================
  // GET AI TRENDING SHOES
  // sends sales data → gets trending products
  // ================================================
  Future<List<Map<String, dynamic>>> getTrendingShoes({
    required List<Map<String, dynamic>> salesData,
  }) async {
    try {

      final systemPrompt = '''
You are a sneaker retail analyst AI.
Analyze the given shoe sales data and identify the top 3 trending shoes.
Return ONLY a JSON array with exactly 3 objects.
Each object must have: productName, salesCount, growthPercent (number only).
No explanation. No markdown. Just the JSON array.
Example: [{"productName":"Nike Air Max 270","salesCount":342,"growthPercent":28}]
''';

      final userMessage = '''
Shoe sales data: ${jsonEncode(salesData)}
Identify the top 3 trending shoes with highest growth.
''';

      final result = await _sendMessage(systemPrompt, userMessage);

      if (result.isEmpty) return [];

      final cleaned = result
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final List<dynamic> parsed = jsonDecode(cleaned);
      return parsed.map((e) => e as Map<String, dynamic>).toList();

    } catch (error) {
      print('getTrendingShoes error: $error');
      return [];
    }
  }

  // ================================================
  // GET RESTOCK PREDICTION
  // sends inventory data → gets restock suggestions
  // ================================================
  Future<List<Map<String, dynamic>>> getRestockPrediction({
    required List<Map<String, dynamic>> inventoryData,
  }) async {
    try {

      final systemPrompt = '''
You are an inventory management AI for a sneaker retail store.
Analyze the given inventory data and identify which products need restocking.
Return ONLY a JSON array of objects for products that need restocking soon.
Each object must have: 
  productName (string),
  currentStock (number),
  maxStock (number),
  daysUntilStockout (number),
  recommendedRestock (number).
No explanation. No markdown. Just the JSON array.
Example: [{"productName":"Nike Air Max","currentStock":15,"maxStock":100,"daysUntilStockout":8,"recommendedRestock":120}]
''';

      final userMessage = '''
Inventory data: ${jsonEncode(inventoryData)}
Identify which products need restocking and when they will run out.
''';

      final result = await _sendMessage(systemPrompt, userMessage);

      if (result.isEmpty) return [];

      final cleaned = result
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final List<dynamic> parsed = jsonDecode(cleaned);
      return parsed.map((e) => e as Map<String, dynamic>).toList();

    } catch (error) {
      print('getRestockPrediction error: $error');
      return [];
    }
  }

  // ================================================
  // GET PRODUCT REPLACEMENT SUGGESTIONS
  // sends discontinued products → gets replacements
  // ================================================
  Future<List<Map<String, dynamic>>> getProductReplacements({
    required List<Map<String, dynamic>> discontinuedProducts,
    required List<String> availableBrands,
  }) async {
    try {

      final systemPrompt = '''
You are a sneaker product specialist AI.
Given a list of discontinued shoes, suggest the best replacement for each.
Only suggest replacements from the available brands provided.
Return ONLY a JSON array of objects.
Each object must have:
  discontinuedProduct (string),
  recommendedReplacement (string),
  brand (string),
  reason (string — max 10 words).
No explanation. No markdown. Just the JSON array.
Example: [{"discontinuedProduct":"Nike React Infinity Run","recommendedReplacement":"Nike Vomero 17","brand":"Nike","reason":"Similar cushioning and running performance"}]
''';

      final userMessage = '''
Discontinued products: ${jsonEncode(discontinuedProducts)}
Available brands: ${availableBrands.join(', ')}
Suggest the best replacement for each discontinued product.
''';

      final result = await _sendMessage(systemPrompt, userMessage);

      if (result.isEmpty) return [];

      final cleaned = result
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final List<dynamic> parsed = jsonDecode(cleaned);
      return parsed.map((e) => e as Map<String, dynamic>).toList();

    } catch (error) {
      print('getProductReplacements error: $error');
      return [];
    }
  }
}