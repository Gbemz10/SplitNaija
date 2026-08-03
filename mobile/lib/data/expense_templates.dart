import 'package:flutter/material.dart';

/// Nigeria-specific expense templates: owambe/aso-ebi contributions, ajo/esusu
/// rounds, shared subscriptions, rent — plus a generic fallback.
class ExpenseTemplateInfo {
  const ExpenseTemplateInfo(this.label, this.icon);
  final String label;
  final IconData icon;
}

const kExpenseTemplates = {
  'GENERIC': ExpenseTemplateInfo('Generic', Icons.receipt_long),
  'OWAMBE_CONTRIBUTION': ExpenseTemplateInfo('Owambe / aso-ebi', Icons.celebration),
  'AJO_ESUSU_ROUND': ExpenseTemplateInfo('Ajo / esusu round', Icons.savings),
  'SHARED_SUBSCRIPTION': ExpenseTemplateInfo('Shared subscription', Icons.subscriptions),
  'RENT': ExpenseTemplateInfo('Rent', Icons.home),
};

ExpenseTemplateInfo templateInfo(String template) =>
    kExpenseTemplates[template] ?? kExpenseTemplates['GENERIC']!;