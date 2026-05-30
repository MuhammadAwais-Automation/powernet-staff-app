import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
  final _formKeyPersonal = GlobalKey<FormState>();
  final _formKeyConnection = GlobalKey<FormState>();

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
  final _customSpeed = TextEditingController();

  List<Area> _areas = [];
  List<PackagePlan> _packages = [];
  String? _areaId;
  String? _packageId;
  String? _gender = 'male';
  bool _isCustomPackage = false;
  bool _loadingLookups = true;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  // Custom Stepper Index (0: Personal, 1: Connection, 2: Package, 3: Review)
  int _currentStep = 0;

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
      _customSpeed,
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

      // Default selection to first hot package (4, 10 or 20 Mbps)
      final hot = packages
          .where(
            (p) => p.speedMbps == 4 || p.speedMbps == 10 || p.speedMbps == 20,
          )
          .toList();
      if (hot.isNotEmpty) {
        _packageId = hot.first.id;
      } else if (_packages.isNotEmpty) {
        _packageId = _packages.first.id;
      }

      if (_packageId != null) {
        final currentPkg = _packages.firstWhere(
          (p) => p.id == _packageId,
          orElse: () =>
              PackagePlan(id: '', name: '', speedMbps: -1, isActive: false),
        );
        _isCustomPackage =
            currentPkg.speedMbps == 0 ||
            currentPkg.name.toLowerCase().contains('custom');
      }
    } catch (e) {
      _error =
          'Signup options could not be loaded. Please check your internet connection.';
    } finally {
      _loadingLookups = false;
      if (mounted) setState(() {});
    }
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (value.trim().length < 3) return 'Must be at least 3 characters';
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
      return 'Only letters and spaces are allowed';
    }
    return null;
  }

  String? _validateCnic(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final cleaned = value.replaceAll('-', '');
    if (cleaned.length != 13 || int.tryParse(cleaned) == null) {
      return 'CNIC must have exactly 13 digits';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (value.length != 11 || !value.startsWith('03')) {
      return 'Must be exactly 11 digits starting with 03';
    }
    return null;
  }

  String? _validateWhatsapp(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Optional
    if (value.length != 11 || !value.startsWith('03')) {
      return 'Must be exactly 11 digits starting with 03';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Optional
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_formKeyPersonal.currentState!.validate()) return;
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (!_formKeyConnection.currentState!.validate()) return;
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      if (_packageId == null) {
        setState(() => _error = 'Select a package to continue.');
        return;
      }
      if (_isCustomPackage && _customSpeed.text.trim().isEmpty) {
        setState(() => _error = 'Please enter custom speed in Mbps.');
        return;
      }
      setState(() {
        _error = null;
        _currentStep = 3;
      });
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _submit() async {
    if (_areaId == null || _packageId == null) {
      setState(() => _error = 'Please select both an area and a package plan.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final finalStreet = _isCustomPackage
          ? '${_street.text}\n[Requested Custom Speed: ${_customSpeed.text} Mbps]'
          : _street.text;

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
          streetAddress: finalStreet,
          email: _email.text,
        ),
      );
      setState(() => _submitted = true);
    } catch (e) {
      setState(
        () => _error =
            'Signup submission failed. A duplicate house ID or network connectivity issue may have occurred.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;

    // Check if request is submitted successfully
    if (_submitted) {
      return Scaffold(
        backgroundColor: pn.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: pn.softGreen,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: pn.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.mark_email_read_outlined,
                    color: pn.success,
                    size: 46,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Signup Request Submitted!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: pn.text,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your request is pending company verification. After approval, a verified system agent will contact you on call or WhatsApp with your temporary house ID credentials.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: pn.textSoft,
                    height: 1.5,
                    fontSize: 13.5,
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('BACK TO PORTAL LOGIN'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: pn.background,
      appBar: AppBar(
        title: const Text('New Connection'),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: pn.text),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: _loadingLookups
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Clean step indicator bar matching CSS .stepper
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: pn.surfaceMuted.withValues(alpha: 0.4),
                    border: Border(bottom: BorderSide(color: pn.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStepTab(pn, 'Personal', 0),
                      _buildStepTab(pn, 'Connection', 1),
                      _buildStepTab(pn, 'Package', 2),
                      _buildStepTab(pn, 'Review', 3),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: pn.softRed,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: pn.danger.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  color: pn.danger,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: pn.danger,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Active Stepper Panel Builder
                        _buildActiveStepPanel(pn),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStepTab(PnColors pn, String label, int stepIndex) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? pn.accent : (isDone ? pn.softCyan : pn.surface),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: isActive ? pn.accent : pn.border, width: 1),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: isActive ? pn.primary : (isDone ? pn.cyan : pn.textSoft),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveStepPanel(PnColors pn) {
    switch (_currentStep) {
      case 0:
        return _buildPersonalForm(pn);
      case 1:
        return _buildConnectionForm(pn);
      case 2:
        return _buildPackageForm(pn);
      case 3:
      default:
        return _buildReviewForm(pn);
    }
  }

  Widget _buildPersonalForm(PnColors pn) {
    return Form(
      key: _formKeyPersonal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFieldHeader(pn, 'FULL NAME'),
          TextFormField(
            controller: _name,
            validator: _validateName,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
              LengthLimitingTextInputFormatter(50),
            ],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Customer full name'),
          ),
          const SizedBox(height: 16),
          _buildFieldHeader(pn, 'FATHER NAME'),
          TextFormField(
            controller: _fatherName,
            validator: _validateName,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
              LengthLimitingTextInputFormatter(50),
            ],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Father full name'),
          ),
          const SizedBox(height: 16),
          _buildFieldHeader(pn, 'CNIC NUMBER'),
          TextFormField(
            controller: _cnic,
            validator: _validateCnic,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
              LengthLimitingTextInputFormatter(15),
            ],
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'e.g. 42101-XXXXXXX-X'),
          ),
          const SizedBox(height: 16),
          _buildFieldHeader(pn, 'GENDER'),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            items: const [
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (value) => setState(() => _gender = value),
            validator: (value) => value == null ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          _buildFieldHeader(pn, 'PROFESSION'),
          TextFormField(
            controller: _profession,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'e.g. Businessman, Engineer, Soldier',
            ),
          ),
          const SizedBox(height: 16),
          _buildFieldHeader(pn, 'RANK / POSITION (OPTIONAL)'),
          TextFormField(
            controller: _rank,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'e.g. Captain, Manager, Assistant',
            ),
          ),
          const SizedBox(height: 16),
          _buildFieldHeader(pn, 'UNIT / DEPARTMENT (OPTIONAL)'),
          TextFormField(
            controller: _unit,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'e.g. Signal Battalion, IT Dept',
            ),
          ),
          const SizedBox(height: 16),
          _buildFieldHeader(pn, 'MOBILE NUMBER'),
          TextFormField(
            controller: _phone,
            validator: _validatePhone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'e.g. 0300-XXXXXXX'),
          ),
          const SizedBox(height: 16),
          _buildFieldHeader(pn, 'WHATSAPP NUMBER'),
          TextFormField(
            controller: _whatsapp,
            validator: _validateWhatsapp,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'e.g. 0300-XXXXXXX (Same or other)',
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _nextStep,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('CONTINUE TO CONNECTION'),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionForm(PnColors pn) {
    return Form(
      key: _formKeyConnection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFieldHeader(pn, 'ASSIGNED SERVICE AREA'),
          DropdownButtonFormField<String>(
            initialValue: _areaId,
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
          const SizedBox(height: 16),
          _buildFieldHeader(pn, 'HOUSE ID'),
          TextFormField(
            controller: _houseId,
            validator: _required,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'e.g. House 14-B / Street 2',
            ),
          ),
          const SizedBox(height: 16),
          _buildFieldHeader(pn, 'STREET ADDRESS'),
          TextFormField(
            controller: _street,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Complete physical street address & landmarks',
            ),
          ),
          const SizedBox(height: 16),
          _buildFieldHeader(pn, 'EMAIL ADDRESS (OPTIONAL)'),
          TextFormField(
            controller: _email,
            validator: _validateEmail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'e.g. name@example.com',
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _prevStep,
                  child: const Text('BACK'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('SELECT PACKAGE'),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<PackagePlan> _getHotPackages() {
    return _packages.where((pkg) {
      return pkg.speedMbps == 4 || pkg.speedMbps == 10 || pkg.speedMbps == 20;
    }).toList();
  }

  Widget _buildPackageForm(PnColors pn) {
    final hotPackages = _getHotPackages();
    final customPkg = _packages.firstWhere(
      (p) => p.speedMbps == 0 || p.name.toLowerCase().contains('custom'),
      orElse: () => PackagePlan(
        id: '',
        name: 'Custom Package',
        speedMbps: 0,
        isActive: true,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Select Internet Package',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: pn.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose the speed package that fits your daily bandwidth needs.',
          style: TextStyle(fontSize: 12, color: pn.textMuted),
        ),
        const SizedBox(height: 20),

        // Grid of package card selectors matching HTML designs
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.3,
          ),
          itemCount: hotPackages.length + 1,
          itemBuilder: (context, index) {
            final isCustomCard = index == hotPackages.length;
            final pkg = isCustomCard ? customPkg : hotPackages[index];
            final isSelected = isCustomCard
                ? _isCustomPackage
                : (_packageId == pkg.id && !_isCustomPackage);

            return InkWell(
              onTap: () {
                setState(() {
                  _packageId = pkg.id;
                  _isCustomPackage = isCustomCard;
                  _error = null;
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? pn.softOrange : pn.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? pn.accent : pn.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? pn.accent.withValues(alpha: 0.08)
                          : Colors.transparent,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PowerNet',
                      style: TextStyle(
                        color: pn.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isCustomCard ? 'Custom' : pkg.name,
                      style: GoogleFonts.manrope(
                        color: pn.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isCustomCard
                          ? 'Flex Speed'
                          : (pkg.defaultPrice == null
                                ? '—'
                                : 'Rs. ${pkg.defaultPrice!.toStringAsFixed(0)}'),
                      style: TextStyle(
                        color: isSelected ? pn.accent : pn.textSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        if (_isCustomPackage) ...[
          const SizedBox(height: 20),
          _buildFieldHeader(pn, 'REQUESTED SPEED (MBPS)'),
          TextFormField(
            controller: _customSpeed,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: const InputDecoration(
              hintText: 'e.g. 3, 6, 15, 25',
              suffixText: 'Mbps',
            ),
            onChanged: (_) {
              setState(() {
                _error = null;
              });
            },
          ),
        ],

        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _prevStep,
                child: const Text('BACK'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _nextStep,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('REVIEW SUMMARY'),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewForm(PnColors pn) {
    final selectedArea = _areas.firstWhere(
      (a) => a.id == _areaId,
      orElse: () => Area(id: '', name: '—', code: '', type: '', isActive: true),
    );
    final selectedPackage = _packages.firstWhere(
      (p) => p.id == _packageId,
      orElse: () =>
          PackagePlan(id: '', name: '—', speedMbps: 0, isActive: true),
    );

    final packageDisplay = _isCustomPackage
        ? 'Custom Package (${_customSpeed.text} Mbps)'
        : selectedPackage.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Confirm Request Details',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: pn.text,
          ),
        ),
        const SizedBox(height: 16),

        // Beautiful summary overview card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: pn.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: pn.border),
          ),
          child: Column(
            children: [
              _buildReviewRow('Full Name', _name.text, pn),
              const Divider(height: 20),
              _buildReviewRow('CNIC Number', _cnic.text, pn),
              const Divider(height: 20),
              _buildReviewRow(
                'Gender',
                _gender == 'male'
                    ? 'Male'
                    : (_gender == 'female' ? 'Female' : 'Other'),
                pn,
              ),
              const Divider(height: 20),
              if (_profession.text.trim().isNotEmpty) ...[
                _buildReviewRow('Profession', _profession.text, pn),
                const Divider(height: 20),
              ],
              if (_rank.text.trim().isNotEmpty) ...[
                _buildReviewRow('Rank / Position', _rank.text, pn),
                const Divider(height: 20),
              ],
              if (_unit.text.trim().isNotEmpty) ...[
                _buildReviewRow('Unit / Dept', _unit.text, pn),
                const Divider(height: 20),
              ],
              _buildReviewRow('Phone Number', _phone.text, pn),
              const Divider(height: 20),
              _buildReviewRow('House ID', _houseId.text, pn),
              const Divider(height: 20),
              _buildReviewRow('Service Area', selectedArea.name, pn),
              const Divider(height: 20),
              _buildReviewRow('Bandwidth Package', packageDisplay, pn),
              const Divider(height: 20),
              _buildReviewRow(
                'Package Price',
                _isCustomPackage
                    ? 'Flex Speed'
                    : (selectedPackage.defaultPrice != null
                          ? 'Rs. ${selectedPackage.defaultPrice!.toStringAsFixed(0)}'
                          : '—'),
                pn,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: pn.accent,
            foregroundColor: pn.primary,
            elevation: 6,
          ),
          child: _submitting
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(pn.primary),
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('SUBMIT REQUEST'),
                    SizedBox(width: 8),
                    Icon(Icons.check_circle_outline_rounded, size: 18),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _prevStep,
          child: const Text('EDIT REGISTRATION DETAILS'),
        ),
      ],
    );
  }

  Widget _buildFieldHeader(PnColors pn, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: pn.textSoft,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildReviewRow(String label, String value, PnColors pn) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: pn.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: pn.text,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
