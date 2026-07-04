class ComplaintTypeOption {
  final String value;
  final String label;
  const ComplaintTypeOption({required this.value, required this.label});
}

const internetComplaintTypeOptions = [
  ComplaintTypeOption(value: 'fiber_issue', label: 'Fiber Issue'),
  ComplaintTypeOption(value: 'no_internet', label: 'Connected, No Internet'),
  ComplaintTypeOption(value: 'device_issue', label: 'Device Issue'),
  ComplaintTypeOption(value: 'payment_issue', label: 'Payment Issue'),
  ComplaintTypeOption(value: 'other', label: 'Other Concern'),
];

const cableComplaintTypeOptions = [
  ComplaintTypeOption(value: 'cable_issue', label: 'Cable Issue'),
  ComplaintTypeOption(value: 'cable_down', label: 'Cable Down'),
];

const complaintTypeOptions = [
  ...internetComplaintTypeOptions,
  ...cableComplaintTypeOptions,
];

const _cableTypeValues = {
  'cable_issue',
  'cable_down',
  'signal_issue',
  'onu_fault',
  'no_signal',
};

bool isCableComplaintType(String? type) =>
    type != null && _cableTypeValues.contains(type);

List<ComplaintTypeOption> complaintTypesForCustomer({
  bool hasInternet = true,
  bool hasCable = false,
}) {
  if (hasInternet && hasCable) return complaintTypeOptions;
  if (hasCable) return cableComplaintTypeOptions;
  return internetComplaintTypeOptions;
}

String formatComplaintTypeLabel(String? type) {
  if (type == null || type.isEmpty) return '—';
  for (final option in complaintTypeOptions) {
    if (option.value == type) return option.label;
  }
  const legacy = {
    'connectivity': 'Connected, No Internet',
    'speed': 'Connected, No Internet',
    'hardware': 'Fiber Issue',
    'billing': 'Payment Issue',
    'upgrade': 'Other Concern',
    'cable_issue': 'Cable Issue',
    'cable_down': 'Cable Down',
    'signal_issue': 'Cable Issue',
    'onu_fault': 'Cable Issue',
    'no_signal': 'Cable Down',
  };
  return legacy[type] ?? type.replaceAll('_', ' ');
}

String formatServiceLineLabel(String? serviceLine, {String? type}) {
  if (serviceLine == 'cable' || isCableComplaintType(type)) return 'Cable';
  return 'Internet';
}

String complaintTypeDropdownLabel(
  ComplaintTypeOption option, {
  bool hasInternet = true,
  bool hasCable = false,
}) {
  final both = hasInternet && hasCable;
  if (!both) return option.label;
  final prefix = isCableComplaintType(option.value) ? 'Cable' : 'Internet';
  return '$prefix — ${option.label}';
}