import 'dart:io';

import 'package:flutter/material.dart';
import 'package:bd_nid_ocr/bd_nid_ocr.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

/// Demonstrates using `bd_nid_ocr` from a plain [StatefulWidget] with
/// [setState] — no GetX, Riverpod, Bloc, or Provider anywhere in this app.
/// This is the proof, not just a demo: if `bd_nid_ocr` required a
/// state-management framework, this app could not exist as written.
///
/// Flow: pick front image → pick back image → NidOcr.scan() → show NidCard →
/// dispose NidOcr. See README.md for the equivalent Riverpod/Bloc wiring.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bd_nid_ocr example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const NidScanExamplePage(),
    );
  }
}

class NidScanExamplePage extends StatefulWidget {
  const NidScanExamplePage({super.key});

  @override
  State<NidScanExamplePage> createState() => _NidScanExamplePageState();
}

class _NidScanExamplePageState extends State<NidScanExamplePage> {
  // Plain mutable fields, no Rx/ValueNotifier required — setState is enough.
  final NidOcr _nidOcr = NidOcr();
  final ImagePicker _picker = ImagePicker();

  File? _frontImage;
  File? _backImage;
  NidScanResult? _result;
  String? _errorMessage;
  bool _isScanning = false;

  Future<void> _pickImage({required bool isFront}) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() {
      if (isFront) {
        _frontImage = File(picked.path);
      } else {
        _backImage = File(picked.path);
      }
      _result = null;
      _errorMessage = null;
    });
  }

  Future<void> _scan() async {
    final front = _frontImage;
    final back = _backImage;
    if (front == null || back == null) return;

    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      final result = await _nidOcr.scan(frontImage: front, backImage: back);
      setState(() => _result = result);
    } on NidOcrException catch (e) {
      // The package throws typed exceptions; this app decides how to show
      // them — bd_nid_ocr never shows a snackbar/dialog itself.
      setState(() => _errorMessage = e.message);
    } finally {
      setState(() => _isScanning = false);
    }
  }

  void _reset() {
    setState(() {
      _frontImage = null;
      _backImage = null;
      _result = null;
      _errorMessage = null;
    });
  }

  @override
  void dispose() {
    _nidOcr.dispose(); // release ML Kit recognizers
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = _result?.card;

    return Scaffold(
      appBar: AppBar(title: const Text('bd_nid_ocr example')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ImageSlot(
                    label: 'Front',
                    file: _frontImage,
                    onTap: () => _pickImage(isFront: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ImageSlot(
                    label: 'Back',
                    file: _backImage,
                    onTap: () => _pickImage(isFront: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed:
                  (_frontImage != null && _backImage != null && !_isScanning)
                  ? _scan
                  : null,
              child: _isScanning
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Scan'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _reset, child: const Text('Reset')),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (card != null) _NidCardView(card: card, result: _result!),
          ],
        ),
      ),
    );
  }
}

class _ImageSlot extends StatelessWidget {
  const _ImageSlot({
    required this.label,
    required this.file,
    required this.onTap,
  });

  final String label;
  final File? file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.6,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: file == null
              ? Center(child: Text('Pick $label'))
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(file!, fit: BoxFit.cover),
                ),
        ),
      ),
    );
  }
}

class _NidCardView extends StatelessWidget {
  const _NidCardView({required this.card, required this.result});

  final NidCard card;
  final NidScanResult result;

  @override
  Widget build(BuildContext context) {
    final fields = <String, String?>{
      'NID Number': card.nidNumber,
      'Name': card.name,
      'Name (Bengali)': card.nameLocal,
      'Date of Birth': card.dateOfBirth,
      'Father': card.fatherName,
      'Mother': card.motherName,
      'Address': card.address,
      'Gender': card.gender,
      'Expiry Date': card.expiryDate,
      'Nationality': card.nationality,
      'Blood Group': card.bloodGroup,
      'Place of Birth': card.placeOfBirth,
      'Issue Date': card.issueDate,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in fields.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 120, child: Text(entry.key)),
                    Expanded(child: Text(entry.value ?? '—')),
                  ],
                ),
              ),
            if (result.barcodeData.isNotEmpty) ...[
              const Divider(),
              Text(
                'Barcode data',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final entry in result.barcodeData.entries)
                Text('${entry.key}: ${entry.value}'),
            ],
          ],
        ),
      ),
    );
  }
}
