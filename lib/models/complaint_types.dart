class ComplaintTypeOption {
  final String value;
  final String label;
  const ComplaintTypeOption({required this.value, required this.label});
}

const complaintTypeOptions = [
  ComplaintTypeOption(value: 'fiber_issue', label: 'Fiber Issue'),
  ComplaintTypeOption(value: 'no_internet', label: 'Connected, No Internet'),
  ComplaintTypeOption(value: 'device_issue', label: 'Device Issue'),
  ComplaintTypeOption(value: 'payment_issue', label: 'Payment Issue'),
  ComplaintTypeOption(value: 'other', label: 'Other Concern'),
];

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
  };
  return legacy[type] ?? type.replaceAll('_', ' ');
}