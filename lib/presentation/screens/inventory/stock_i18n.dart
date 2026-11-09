import 'package:flutter/widgets.dart';

import '../../../domain/models/stock_movement.dart';
import '../../../providers/app_preferences_provider.dart';

/// Short helper for the inventory screens: picks the text for the app language.
String stockTr(BuildContext c, String en, String ha, String fr, String pcm) =>
    c.appLanguage.tr(en: en, ha: ha, fr: fr, pcm: pcm);

String localGroupLabel(BuildContext c, InventoryGroup group) {
  switch (group) {
    case InventoryGroup.inputs:
      return stockTr(c, 'Inputs', 'Kayan noma', 'Intrants', 'Inputs');
    case InventoryGroup.produce:
      return stockTr(c, 'Produce', 'Amfanin gona', 'Produits', 'Produce');
    case InventoryGroup.animals:
      return stockTr(c, 'Animals', 'Dabbobi', 'Animaux', 'Animals');
  }
}

String localMovementLabel(BuildContext c, StockMovementType type) {
  switch (type) {
    case StockMovementType.opening:
      return stockTr(c, 'Opening stock', 'Kayan farko', 'Stock initial',
          'Opening stock');
    case StockMovementType.purchase:
      return stockTr(c, 'Purchase', 'Saye', 'Achat', 'Purchase');
    case StockMovementType.harvest:
      return stockTr(c, 'Harvest', 'Girbi', 'Récolte', 'Harvest');
    case StockMovementType.production:
      return stockTr(c, 'Production', 'Samarwa', 'Production', 'Production');
    case StockMovementType.transferIn:
      return stockTr(c, 'Moved to sale stock', 'An mayar zuwa kayan siyarwa',
          'Transféré au stock à vendre', 'Moved go sale stock');
    case StockMovementType.sale:
      return stockTr(c, 'Sale', 'Siyarwa', 'Vente', 'Sale');
    case StockMovementType.usage:
      return stockTr(c, 'Used', 'An yi amfani', 'Utilisé', 'Used');
    case StockMovementType.loss:
      return stockTr(c, 'Loss / waste', 'Asara / ɓarna', 'Perte / gaspillage',
          'Loss / waste');
    case StockMovementType.adjustment:
      return stockTr(c, 'Stock-take', 'Kidayar kaya', 'Inventaire',
          'Stock count');
  }
}

String localCategoryLabel(BuildContext c, String category) {
  switch (category) {
    case 'Feed':
      return stockTr(c, 'Feed', 'Abincin dabbobi', 'Aliment', 'Feed');
    case 'Seed':
      return stockTr(c, 'Seed', 'Iri', 'Semences', 'Seed');
    case 'Fertilizer':
      return stockTr(c, 'Fertilizer', 'Taki', 'Engrais', 'Fertilizer');
    case 'Chemicals':
      return stockTr(c, 'Chemicals', 'Sinadarai', 'Produits chimiques',
          'Chemicals');
    case 'Medicine':
      return stockTr(c, 'Medicine', 'Magani', 'Médicament', 'Medicine');
    case 'Tools':
      return stockTr(c, 'Tools', 'Kayan aiki', 'Outils', 'Tools');
    case 'Produce':
      return stockTr(c, 'Produce', 'Amfanin gona', 'Produits', 'Produce');
    case 'Other':
      return stockTr(c, 'Other', 'Wasu', 'Autre', 'Other');
  }
  return category;
}
