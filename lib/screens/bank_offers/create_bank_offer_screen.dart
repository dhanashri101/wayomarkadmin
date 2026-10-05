import 'package:flutter/material.dart';

import '../../controllers/admin_controller.dart';
import '../../core/network/wayomark_api.dart';
import '../../core/theme/admin_theme.dart';
import '../../widgets/admin_card.dart';

class CreateBankOfferScreen extends StatefulWidget {
  const CreateBankOfferScreen({super.key, required this.controller});
  final AdminController controller;

  @override
  State<CreateBankOfferScreen> createState() => _CreateBankOfferScreenState();
}

class _CreateBankOfferScreenState extends State<CreateBankOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bank = TextEditingController();
  final _roi = TextEditingController();
  final _emi = TextEditingController();
  final _amount = TextEditingController();
  final _tenure = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _bank.dispose();
    _roi.dispose();
    _emi.dispose();
    _amount.dispose();
    _tenure.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.controller.createBankOffer(
        bankName: _bank.text.trim(),
        roi: double.parse(_roi.text.trim()),
        emi: double.parse(_emi.text.trim()),
        loanAmount: double.parse(_amount.text.trim()),
        tenureMonths: int.parse(_tenure.text.trim()),
      );
      if (!mounted) return;
      _bank.clear();
      _roi.clear();
      _emi.clear();
      _amount.clear();
      _tenure.clear();
      _message('Bank offer created successfully.');
    } on WayomarkApiException catch (e) {
      _message(e.message, error: true);
    } catch (e) {
      _message('$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AdminTheme.danger : AdminTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Create Bank Offer',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AdminTheme.navy),
        ),
        const SizedBox(height: 4),
        const Text('POST /v1/admin/bank-offers', style: TextStyle(color: AdminTheme.muted)),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: AdminCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _bank,
                    decoration: const InputDecoration(labelText: 'Bank name'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  _NumberField(controller: _roi, label: 'ROI (%)', decimal: true),
                  const SizedBox(height: 12),
                  _NumberField(controller: _emi, label: 'EMI', decimal: true),
                  const SizedBox(height: 12),
                  _NumberField(controller: _amount, label: 'Loan amount', decimal: true),
                  const SizedBox(height: 12),
                  _NumberField(controller: _tenure, label: 'Tenure (months)'),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.add_business_rounded),
                      label: Text(_saving ? 'Creating...' : 'Create offer'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Postman example: Demo Bank, ROI 8.5, EMI 21000, loan amount 1000000, tenure 60 months.',
                    style: TextStyle(fontSize: 12, color: AdminTheme.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required.' : null;
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label, this.decimal = false});
  final TextEditingController controller;
  final String label;
  final bool decimal;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return 'Required.';
          if (decimal) {
            if (double.tryParse(value.trim()) == null) return 'Enter a valid number.';
          } else if (int.tryParse(value.trim()) == null) {
            return 'Enter a whole number.';
          }
          return null;
        },
      );
}
