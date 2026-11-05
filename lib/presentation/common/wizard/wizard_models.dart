import 'package:flutter/widgets.dart';

import '../../../providers/app_preferences_provider.dart';

/// A piece of text in each supported language. English is required and is the
/// fallback when a translation is missing.
@immutable
class LocalizedText {
  /// Creates a localized text.
  const LocalizedText(this.en, {this.ha, this.fr});

  /// English (also the fallback).
  final String en;

  /// Hausa.
  final String? ha;

  /// French.
  final String? fr;

  /// The text for [language].
  String resolve(AppLanguage language) => language.tr(en: en, ha: ha, fr: fr);
}

/// One screen of a guided flow.
///
/// A step explains itself (title, [why], optional [tip]), shows a photo, and
/// builds the inputs for that question.
@immutable
class WizardStep {
  /// Creates a step.
  const WizardStep({
    required this.id,
    required this.icon,
    required this.image,
    required this.title,
    required this.why,
    required this.builder,
    this.tip,
    this.validate,
  });

  /// Unique within the wizard; also keys the animations.
  final String id;

  /// Icon shown next to the title.
  final IconData icon;

  /// Asset path of the photo behind the title.
  final String image;

  /// Short name of the step, e.g. "How big is your farm?".
  final LocalizedText title;

  /// One or two plain sentences on why we ask and how the answer is used.
  final LocalizedText why;

  /// Optional extra hint, shown under the inputs.
  final LocalizedText? tip;

  /// Builds the inputs. Called again whenever the owner rebuilds the wizard,
  /// so it may read the owner's live state.
  final WidgetBuilder builder;

  /// Returns a message when the answer is not acceptable yet, or null when the
  /// farmer may continue.
  final LocalizedText? Function()? validate;
}

/// Wording every wizard shares, so it is translated once.
abstract final class WizardText {
  static const LocalizedText next =
      LocalizedText('Next', ha: 'Na gaba', fr: 'Suivant');
  static const LocalizedText back =
      LocalizedText('Back', ha: 'Koma baya', fr: 'Retour');
  static const LocalizedText whyWeAsk =
      LocalizedText('Why we ask', ha: 'Dalilin tambaya', fr: 'Pourquoi nous demandons');
  static const LocalizedText tip = LocalizedText('Tip', ha: 'Shawara', fr: 'Astuce');
  static const LocalizedText allSet =
      LocalizedText('All set!', ha: 'An gama!', fr: 'Tout est prêt !');
  static const LocalizedText leaveTitle = LocalizedText(
    'Leave without saving?',
    ha: 'Ka fita ba tare da ajiyewa ba?',
    fr: 'Quitter sans enregistrer ?',
  );
  static const LocalizedText leaveBody = LocalizedText(
    'Your answers so far will be lost.',
    ha: 'Za a rasa amsoshin da ka bayar.',
    fr: 'Vos réponses seront perdues.',
  );
  static const LocalizedText stay =
      LocalizedText('Stay', ha: 'Ci gaba', fr: 'Rester');
  static const LocalizedText leave =
      LocalizedText('Leave', ha: 'Fita', fr: 'Quitter');
  static const LocalizedText review =
      LocalizedText('Review', ha: 'Duba', fr: 'Vérifier');

  /// "Step 2 of 6".
  static String stepOf(AppLanguage language, int step, int total) {
    return language.tr(
      en: 'Step $step of $total',
      ha: 'Mataki na $step cikin $total',
      fr: 'Étape $step sur $total',
    );
  }
}
