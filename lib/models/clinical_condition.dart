/// Clinical condition that can be applied to patients.
class ClinicalCondition {
  final String code;
  final String displayName;
  final List<String>? subtypes;

  const ClinicalCondition({
    required this.code,
    required this.displayName,
    this.subtypes,
  });
}

/// Clinical conditions available for Labor and Postpartum patients.
class ClinicalConditions {
  // Hypertensive conditions
  static const ghtn = ClinicalCondition(
    code: 'GHTN',
    displayName: 'Gestational Hypertension',
  );

  static const chtn = ClinicalCondition(
    code: 'CHTN',
    displayName: 'Chronic Hypertension',
  );

  static const preE = ClinicalCondition(
    code: 'Pre-E',
    displayName: 'Preeclampsia',
    subtypes: ['SF'], // Severe Features
  );

  // Diabetes
  static const dm = ClinicalCondition(
    code: 'DM',
    displayName: 'Diabetes Mellitus',
    subtypes: ['A1', 'A2', 'T1', 'T2'],
  );

  // Group B Strep
  static const gbs = ClinicalCondition(
    code: 'GBS',
    displayName: 'Group B Strep',
    subtypes: ['-', '+', '?'],
  );

  // GYN Conditions
  static const hyperemesis = ClinicalCondition(
    code: 'Hyperemesis',
    displayName: 'Hyperemesis',
  );

  static const menorrhagia = ClinicalCondition(
    code: 'Menorrhagia',
    displayName: 'Menorrhagia',
  );

  static const toa = ClinicalCondition(
    code: 'TOA',
    displayName: 'Tubo-Ovarian Abscess',
    subtypes: ['s/p IR Drainage'],
  );

  static const postOp = ClinicalCondition(
    code: 'Post-op',
    displayName: 'Post-operative',
    subtypes: [
      'TLH',
      'TAH',
      'l/s LSO',
      'l/s L-Salp',
      'l/s RSO',
      'l/s R-Salp',
      'D&C',
      'Ex-Lap',
    ],
  );

  // Consult Conditions
  static const dvtPe = ClinicalCondition(
    code: 'DVT/PE',
    displayName: 'DVT/PE',
  );

  static const trauma = ClinicalCondition(
    code: 'Trauma',
    displayName: 'Trauma',
  );

  static const cyst = ClinicalCondition(
    code: 'Cyst',
    displayName: 'Cyst',
  );

  static const prolapse = ClinicalCondition(
    code: 'Prolapse',
    displayName: 'Prolapse',
  );

  static const other = ClinicalCondition(
    code: 'Other',
    displayName: 'Other',
  );

  /// Conditions applicable to Labor patients
  static const List<ClinicalCondition> laborConditions = [
    ghtn,
    chtn,
    preE,
    dm,
    gbs,
  ];

  /// Conditions applicable to Postpartum patients
  static const List<ClinicalCondition> postpartumConditions = [
    ghtn,
    chtn,
    preE,
    dm,
    gbs,
  ];

  /// Conditions applicable to GYN patients
  static const List<ClinicalCondition> gynConditions = [
    hyperemesis,
    menorrhagia,
    toa,
    postOp,
  ];

  /// Conditions applicable to Consult patients
  static const List<ClinicalCondition> consultConditions = [
    dvtPe,
    trauma,
    cyst,
    prolapse,
    other,
  ];
}
