import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import 'contract_detail_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _uploading = false;
  String? _error;

  Future<void> _handleFile(File file) async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final contract = await ApiService.uploadContract(file);
      if (!mounted) return;
      // Ya subido, ahora lo mandamos directo a la pantalla de detalle,
      // donde el usuario dispara el análisis con IA.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ContractDetailScreen(contractId: contract.id)),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (photo != null) await _handleFile(File(photo.path));
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (photo != null) await _handleFile(File(photo.path));
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx'],
    );
    if (result != null && result.files.single.path != null) {
      await _handleFile(File(result.files.single.path!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo contrato')),
      body: _uploading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Subiendo y leyendo el documento...'),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.description_outlined, size: 64, color: Color(0xFF2E8B57)),
                  const SizedBox(height: 8),
                  const Text(
                    '¿Cómo quieres agregar el contrato?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 24),
                  _OptionButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Tomar foto',
                    onTap: _takePhoto,
                  ),
                  const SizedBox(height: 12),
                  _OptionButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Elegir de la galería',
                    onTap: _pickFromGallery,
                  ),
                  const SizedBox(height: 12),
                  _OptionButton(
                    icon: Icons.upload_file_outlined,
                    label: 'Subir PDF o Word',
                    onTap: _pickDocument,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OptionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: const Color(0xFF2E8B57)),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: const BorderSide(color: Color(0xFF2E8B57)),
        foregroundColor: const Color(0xFF2E8B57),
      ),
    );
  }
}
