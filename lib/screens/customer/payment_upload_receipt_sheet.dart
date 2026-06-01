import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/bill.dart';
import '../../providers/customer_portal_provider.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/app_theme.dart';

class PaymentUploadReceiptSheet extends StatefulWidget {
  final Bill bill;
  const PaymentUploadReceiptSheet({super.key, required this.bill});

  @override
  State<PaymentUploadReceiptSheet> createState() => _PaymentUploadReceiptSheetState();
}

class _PaymentUploadReceiptSheetState extends State<PaymentUploadReceiptSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();
  
  String _selectedMethod = 'easypaisa';
  File? _selectedImage;
  bool _isUploading = false;
  final _picker = ImagePicker();
  final _cloudinaryService = CloudinaryService();

  @override
  void initState() {
    super.initState();
    // Prefill the remaining amount for the bill
    _amountController.text = widget.bill.remaining.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final pn = Theme.of(context).extension<PnColors>()!;
        return Container(
          decoration: BoxDecoration(
            color: pn.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Receipt Image Source',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: pn.text,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pn.accent,
                      foregroundColor: pn.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pn.accent,
                      foregroundColor: pn.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or capture a payment receipt image.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final portalProvider = Provider.of<CustomerPortalProvider>(context, listen: false);

    setState(() {
      _isUploading = true;
    });

    final amount = double.tryParse(_amountController.text) ?? 0.0;

    // 1. Upload to Cloudinary
    final imageUrl = await _cloudinaryService.uploadReceipt(_selectedImage!.path);

    if (imageUrl == null) {
      setState(() {
        _isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cloudinary upload failed. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // 2. Submit record to Supabase
    final success = await portalProvider.submitPaymentVerification(
      billId: widget.bill.id,
      customerId: widget.bill.customerId,
      amount: amount,
      method: _selectedMethod,
      receiptUrl: imageUrl,
      remarks: _remarksController.text,
    );

    if (!mounted) return;

    setState(() {
      _isUploading = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment receipt submitted successfully! Pending verification.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(portalProvider.error ?? 'Submission failed.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pn = Theme.of(context).extension<PnColors>()!;
    return AnimatedPadding(
      padding: MediaQuery.of(context).viewInsets,
      duration: const Duration(milliseconds: 100),
      child: Container(
        decoration: BoxDecoration(
          color: pn.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pay Now - Upload Receipt',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: pn.text,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const Divider(),
                const SizedBox(height: 10),

                // Method Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedMethod,
                  decoration: InputDecoration(
                    labelText: 'Payment Method',
                    labelStyle: TextStyle(color: pn.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: pn.background,
                  ),
                  dropdownColor: pn.surface,
                  items: const [
                    DropdownMenuItem(value: 'easypaisa', child: Text('Easypaisa')),
                    DropdownMenuItem(value: 'jazzcash', child: Text('JazzCash')),
                    DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'other', child: Text('Other Online Method')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedMethod = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Amount Field
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount Paid (Rs.)',
                    labelStyle: TextStyle(color: pn.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: pn.background,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter payment amount';
                    final parsed = double.tryParse(val);
                    if (parsed == null || parsed <= 0) return 'Please enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Remarks Field
                TextFormField(
                  controller: _remarksController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Optional Remarks (e.g. Transaction ID)',
                    labelStyle: TextStyle(color: pn.textMuted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: pn.background,
                  ),
                ),
                const SizedBox(height: 20),

                // Selected Image Preview / Upload Button
                if (_selectedImage != null) ...[
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: pn.border),
                          image: DecorationImage(
                            image: FileImage(_selectedImage!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withValues(alpha: 0.6),
                          radius: 18,
                          child: IconButton(
                            icon: const Icon(Icons.delete, size: 16, color: Colors.white),
                            onPressed: () {
                              setState(() {
                                _selectedImage = null;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  InkWell(
                    onTap: _showImageSourceDialog,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: pn.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: pn.cyan.withValues(alpha: 0.35), style: BorderStyle.solid),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload_outlined, size: 38, color: pn.cyan),
                          const SizedBox(height: 8),
                          Text(
                            'Click to select receipt (Camera/Gallery)',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: pn.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: _isUploading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pn.accent,
                    foregroundColor: pn.primary,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isUploading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Text('Uploading to Cloudinary...', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
                          ],
                        )
                      : Text('Submit Payment Receipt', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
