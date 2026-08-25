import 'nutrition_i18n.dart';

class DiseaseNutritionPlan {
  final String diseaseName;
  final String headline;
  final String nitrogenRule;
  final String potashPhosphorusRule;
  final String micronutrientSpray;
  final String bioFertilizer;

  const DiseaseNutritionPlan({
    required this.diseaseName,
    required this.headline,
    required this.nitrogenRule,
    required this.potashPhosphorusRule,
    required this.micronutrientSpray,
    required this.bioFertilizer,
  });
}

class NutritionService {
  /// Returns dynamic disease-specific nutritional and fertilizer recovery advice.
  static DiseaseNutritionPlan getDiseaseNutritionAdvice(String label) {
    final l = label.toLowerCase();

    if (l.contains('late_blight') || l.contains('early_blight') || l.contains('leaf_blight')) {
      return const DiseaseNutritionPlan(
        diseaseName: 'Blight Recovery Nutrition',
        headline: 'Potash & Cell-Wall Reinforcement',
        nitrogenRule: '⛔ RESTRICT UREA/NITROGEN: Excess nitrogen produces soft, succulent tissue that accelerates blight fungal spread.',
        potashPhosphorusRule: '🌿 BOOST POTASH (MOP): Apply 15–20 kg/acre MOP (0-0-60). Potassium thickens plant epidermis and enhances natural phytoalexin defense.',
        micronutrientSpray: '💧 FOLIAR SPRAY: Spray Zinc Sulphate (0.5%) + Boron (0.2%) in the morning to repair damaged chloroplasts and improve recovery.',
        bioFertilizer: '🌱 BIO-INPUT: Apply Trichoderma viride (2 kg/acre) enriched with 200 kg decomposed cow dung to eliminate overwintering spores.',
      );
    }

    if (l.contains('rust')) {
      return const DiseaseNutritionPlan(
        diseaseName: 'Rust Resistance Nutrition',
        headline: 'Balanced N-P-K & Silica Booster',
        nitrogenRule: '⚠️ SPLIT NITROGEN: Avoid heavy single-dose urea. Over-fertilized lush foliage attracts rapid rust spore germination.',
        potashPhosphorusRule: '🌿 POTASH + DAP: Ensure adequate basal phosphorus and top-dress 12 kg/acre MOP. Potash speeds up lesion healing.',
        micronutrientSpray: '💧 MICRONUTRIENT: Foliar spray Potassium Silicate (2 ml/L) or Soluble Boron (1 g/L) to create a silica barrier against fungal hyphae.',
        bioFertilizer: '🌱 ORGANIC: Apply Jeevamrutha or enriched vermicompost to rebuild soil beneficial microflora.',
      );
    }

    if (l.contains('mildew') || l.contains('mold') || l.contains('scab')) {
      return const DiseaseNutritionPlan(
        diseaseName: 'Mildew / Mold Nutrition Plan',
        headline: 'Sulfur & Potassium Nutrition',
        nitrogenRule: '⛔ STOP HIGH UREA: High vegetative nitrogen encourages powdery white fungal blooms.',
        potashPhosphorusRule: '🌿 POTASSIUM SULPHATE (0-0-50): Apply 10 kg/acre Sulfate of Potash (SOP) to supply both essential potassium and disease-fighting sulfur.',
        micronutrientSpray: '💧 FOLIAR NUTRITION: Spray Micronutrient mixture (Grade-2) 2.5 g/L with wettable sulfur.',
        bioFertilizer: '🌱 SOIL HEALTH: Drench Pseudomonas fluorescens (10 ml/L) near root zone for biological fungal antagonism.',
      );
    }

    if (l.contains('bacterial')) {
      return const DiseaseNutritionPlan(
        diseaseName: 'Bacterial Spot Immunity Plan',
        headline: 'Calcium Nitrate & Tissue Hardening',
        nitrogenRule: '⚠️ REPLACE UREA: Switch from pure urea to Calcium Nitrate. Calcium binds pectins in plant cell walls, halting bacterial enzymes.',
        potashPhosphorusRule: '🌿 PHOSPHORUS BOOST: Apply DAP to promote new white feeding roots.',
        micronutrientSpray: '💧 FOLIAR: Spray Copper Oxychloride (2.5 g/L) + Streptomycin with Borax (1 g/L).',
        bioFertilizer: '🌱 BIO-CONTROL: Apply Bacillus subtilis culture around root zone with compost.',
      );
    }

    if (l.contains('mite') || l.contains('spider')) {
      return const DiseaseNutritionPlan(
        diseaseName: 'Pest Recovery & Sap Replenishment',
        headline: 'Hydration & Foliar Nitrogen Boost',
        nitrogenRule: '🌿 RECOVERY TOP-DRESS: Apply light urea (10 kg/acre) with irrigation to stimulate replacement of damaged foliage.',
        potashPhosphorusRule: '🌿 ROOT SUPPORT: Ensure optimal soil moisture and balanced NPK to prevent heat and moisture stress.',
        micronutrientSpray: '💧 SUCKING PEST RECOVERY: Spray Magnesium Sulphate (5 g/L) + Urea (10 g/L) foliar feed to restore yellowed mottled leaves.',
        bioFertilizer: '🌱 NEEM BIO-FERTILIZER: Apply Neem cake (100 kg/acre) to deter soil pupating pests and feed roots slowly.',
      );
    }

    if (l.contains('virus') || l.contains('curl') || l.contains('mosaic') || l.contains('greening')) {
      return const DiseaseNutritionPlan(
        diseaseName: 'Viral Stress Compensation Plan',
        headline: 'Immunity & Micronutrient Cocktail',
        nitrogenRule: '⚠️ MODERATE NPK: Apply balanced 19:19:19 soluble fertilizer to maintain plant vigour without causing vegetative spurt.',
        potashPhosphorusRule: '🌿 POTASH & ZINC: High potassium reduces viral replication and improves fruit setting.',
        micronutrientSpray: '💧 IMMUNITY SPRAY: Foliar spray Formula-4 Micronutrients (Zinc, Iron, Manganese, Boron) 2.5 g/L every 12 days.',
        bioFertilizer: '🌱 ROOT IMMUNITY: Apply Humic acid + Seaweed extract (2 ml/L) to strengthen unaffected root vascular bundles.',
      );
    }

    if (l.contains('rot') || l.contains('wilt')) {
      return const DiseaseNutritionPlan(
        diseaseName: 'Root & Stem Rot Drainage Nutrition',
        headline: 'Soil Aeration & Bio-Fertilizer Infusion',
        nitrogenRule: '⛔ NO UREA ON ROTTING ROOTS: Fertilizer salts cause root burning when root tips are decaying.',
        potashPhosphorusRule: '🌿 PHOSPHATE SOLUBILIZERS: Apply PSB (Phosphorus Solubilizing Bacteria) with well-rotted FYM.',
        micronutrientSpray: '💧 CALCIUM-BORON: Foliar spray Chelated Calcium (1 g/L) to strengthen vascular cambium.',
        bioFertilizer: '🌱 BIO-DRENCH: Drench Trichoderma harzianum (5 g/L) + Pseudomonas (5 g/L) directly at root zone.',
      );
    }

    return const DiseaseNutritionPlan(
      diseaseName: 'General Crop Recovery Nutrition',
      headline: 'Balanced Field Nutrition',
      nitrogenRule: '🌿 BALANCED UREA: Apply recommended split doses according to crop calendar in moist soil.',
      potashPhosphorusRule: '🌿 NPK 10:26:26 or DAP+MOP: Feed base nutrients at proper depth away from stems.',
      micronutrientSpray: '💧 FOLIAR BOOST: Spray Multi-micronutrient Grade-4 (2 g/L) during active growth.',
      bioFertilizer: '🌱 ORGANIC MATTER: Incorporate farmyard manure or vermicompost 2 tons/acre annually.',
    );
  }

  static String _categoryOf(String label) {
    final l = label.toLowerCase();
    if (l.contains('late_blight') || l.contains('early_blight') || l.contains('leaf_blight')) return 'blight';
    if (l.contains('rust')) return 'rust';
    if (l.contains('mildew') || l.contains('mold') || l.contains('scab')) return 'mildew';
    if (l.contains('bacterial')) return 'bacterial';
    if (l.contains('mite') || l.contains('spider')) return 'mite';
    if (l.contains('virus') || l.contains('curl') || l.contains('mosaic') || l.contains('greening')) return 'virus';
    if (l.contains('rot') || l.contains('wilt')) return 'rot';
    return 'general';
  }

  static DiseaseNutritionPlan getAdviceLocalized(String label, String lang) {
    final base = getDiseaseNutritionAdvice(label);
    final cat = kNutritionI18n[_categoryOf(label)];
    final t = cat?[lang] ?? cat?['en'];
    if (t == null || t.length < 4) return base;
    return DiseaseNutritionPlan(
      diseaseName: base.diseaseName,
      headline: base.headline,
      nitrogenRule: t[0],
      potashPhosphorusRule: t[1],
      micronutrientSpray: t[2],
      bioFertilizer: t[3],
    );
  }
}
