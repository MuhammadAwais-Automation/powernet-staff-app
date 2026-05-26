import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/customer_signup_repository.dart';
import '../../models/area.dart';
import '../../models/package_plan.dart';
import '../../theme/app_theme.dart';

class CustomerSignupScreen extends StatefulWidget {
  const CustomerSignupScreen({super.key});

  @override
  State<CustomerSignupScreen> createState() => _CustomerSignupScreenState();
}

class _CustomerSignupScreenState extends State<CustomerSignupScreen> {
  final _repo = CustomerSignupRepository();
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _fatherName = TextEditingController();
  final _cnic = TextEditingController();
  final _profession = TextEditingController();
  final _rank = TextEditingController();
  final _unit = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _houseId = TextEditingController();
  final _street = TextEditingController();
  final _email = TextEditingController();

  List<Area> _areas = [];
  List<PackagePlan> _packages = [];
  String? _areaId;
  String? _packageId;
  String? _gender;
  bool _loadingLookups = true;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _fatherName,
      _cnic,
      _profession,
      _rank,
      _unit,
      _phone,
      _whatsapp,
      _houseId,
      _street,
      _email,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final areas = await _repo.fetchAreas();
      final packages = await _repo.fetchPackages();
      _areas = areas;
      _packages = packages;
      if (_areas.isNotEmpty) _areaId = _areas.first.id;
      if (_packages.isNotEmpty) _packageId = _packages.first.id;
    } catch (e) {
      _error = 'Signup options load nahi ho sakin. Internet check karein.';
    } finally {
      _loadingLookups = false;
      if (mounted) setState(() {});
    }
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_areaId == null || _packageId == null) {
      setState(() => _error = 'Area aur package select karein.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _repo.submit(
        CustomerSignupDraft(
          fullName: _name.text,
          fatherName: _fatherName.text,
          cnic: _cnic.text,
          gender: _gender,
          profession: _profession.text,
          rankOrPosition: _rank.text,
          unit: _unit.text,
          phone: _phone.text,
          whatsapp: _whatsapp.text,
          areaId: _areaId!,
          packageId: _packageId!,
          houseId: _houseId.text,
          streetAddress: _street.text,
          email: _email.text,
        ),
      );
      setState(() => _submitted = true);
    } catch (e) {
      setState(
        () => _error =
            'Signup submit nahi ho saka. Duplicate house ID ya network issue ho sakta hai.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    if (_submitted) {
      return Scaffold(
        appBar: AppBar(title: const Text('Signup submitted')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.mark_email_read_outlined,
                color: primary,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Request pending approval',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: pn.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Company verification ke baad aapko temporary password call/WhatsApp par diya jayega.',
                textAlign: TextAlign.center,
                style: TextStyle(color: pn.textMuted),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Back to login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Customer Signup')),
      body: _loadingLookups
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Personal details',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: pn.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TextField(
                    controller: _name,
                    label: 'Name',
                    validator: _required,
                  ),
                  _TextField(
                    controller: _fatherName,
                    label: 'Father name',
                    validator: _required,
                  ),
                  _TextField(
                    controller: _cnic,
                    label: 'CNIC number',
                    validator: _required,
                    keyboardType: TextInputType.number,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: const InputDecoration(labelText: 'Gender'),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('Male')),
                      DropdownMenuItem(value: 'female', child: Text('Female')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (value) => setState(() => _gender = value),
                  ),
                  const SizedBox(height: 12),
                  _TextField(controller: _profession, label: 'Profession'),
                  _TextField(controller: _rank, label: 'Position / rank'),
                  _TextField(controller: _unit, label: 'Unit (army persons)'),
                  const SizedBox(height: 20),
                  Text(
                    'Contact and connection',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: pn.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TextField(
                    controller: _phone,
                    label: 'Mobile number',
                    validator: _required,
                    keyboardType: TextInputType.phone,
                  ),
                  _TextField(
                    controller: _whatsapp,
                    label: 'WhatsApp number',
                    keyboardType: TextInputType.phone,
                  ),
                  _TextField(
                    controller: _houseId,
                    label: 'House ID',
                    validator: _required,
                  ),
                  _TextField(controller: _street, label: 'Street address'),
                  _TextField(
                    controller: _email,
                    label: 'Email address',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _areaId,
                    decoration: const InputDecoration(labelText: 'Area'),
                    items: _areas
                        .map(
                          (area) => DropdownMenuItem(
                            value: area.id,
                            child: Text('${area.name} (${area.code})'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _areaId = value),
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _packageId,
                    decoration: const InputDecoration(
                      labelText: 'Internet package',
                    ),
                    items: _packages
                        .map(
                          (pkg) => DropdownMenuItem(
                            value: pkg.id,
                            child: Text(
                              pkg.defaultPrice == null
                                  ? pkg.name
                                  : '${pkg.name} - Rs.${pkg.defaultPrice!.toStringAsFixed(0)}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _packageId = value),
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: const TextStyle(color: danger)),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : const Text('Submit request'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  const _TextField({
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
