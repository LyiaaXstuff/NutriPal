import '../models/nutrition_label_data.dart';
import 'azure_layout_client.dart';
import 'nutrition_label_parser_service.dart';

class NutritionScanService {
  static Future<NutritionLabelData> analyze(String imagePath) =>
      AzureLayoutClient.isConfigured
      ? AzureLayoutClient().analyze(imagePath)
      : NutritionLabelParserService.parseImage(imagePath);
}
