enum AiTopic {
  cropManagement,
  animalHealth,
  diseaseAndPest,
  soilAndWater,
  marketAndFinance,
  weatherAndClimate,
  general,
}

extension AiTopicExt on AiTopic {
  String get label {
    switch (this) {
      case AiTopic.cropManagement:
        return 'Crop Management';
      case AiTopic.animalHealth:
        return 'Animal Health';
      case AiTopic.diseaseAndPest:
        return 'Disease & Pest';
      case AiTopic.soilAndWater:
        return 'Soil & Water';
      case AiTopic.marketAndFinance:
        return 'Market & Finance';
      case AiTopic.weatherAndClimate:
        return 'Weather & Climate';
      case AiTopic.general:
        return 'General Farming';
    }
  }

  String get emoji {
    switch (this) {
      case AiTopic.cropManagement:
        return '🌱';
      case AiTopic.animalHealth:
        return '🐄';
      case AiTopic.diseaseAndPest:
        return '🔬';
      case AiTopic.soilAndWater:
        return '🪱';
      case AiTopic.marketAndFinance:
        return '💰';
      case AiTopic.weatherAndClimate:
        return '🌦️';
      case AiTopic.general:
        return '🌾';
    }
  }

  String get description {
    switch (this) {
      case AiTopic.cropManagement:
        return 'Planting, fertiliser, harvest';
      case AiTopic.animalHealth:
        return 'Vaccines, feeding, treatment';
      case AiTopic.diseaseAndPest:
        return 'Diagnose and treat problems';
      case AiTopic.soilAndWater:
        return 'pH, irrigation, composting';
      case AiTopic.marketAndFinance:
        return 'Prices, loans, profit';
      case AiTopic.weatherAndClimate:
        return 'Forecasts and planting calendar';
      case AiTopic.general:
        return 'Any farming question';
    }
  }
}
