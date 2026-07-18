import 'package:flutter/material.dart';
import '../models/contract.dart';
import '../services/api_service.dart';

class CompareScreen extends StatefulWidget {
  final int currentContractId;
  const CompareScreen({super.key, required this.currentContractId});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  List<Contract> _otherContracts = [];
  int? _selectedId;
  bool _loadingList = true;
  bool _comparing = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContracts();
  }

  Future<void> _loadContracts() async {
    try {
      final all = await ApiService.listContracts();
      setState(() {
        _otherContracts = all
            .where((c) => c.id != widget.currentContractId && c.status == 'analizado')
            .toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  Future<void> _compare() async {
    if (_selectedId == null) return;
    setState(() {
      _comparing = true;
      _error = null;
    });
    try {
      final result = await ApiService.compareContracts(widget.currentContractId, _selectedId!);
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _comparing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparar contratos'),
        backgroundColor: const Color(0xFF2E8B57),
        foregroundColor: Colors.white,
      ),
      body: _loadingList
          ? const Center(child: CircularProgressIndicator())
          : _otherContracts.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Necesitas al menos otro contrato ya analizado para poder comparar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Elige la otra versión del contrato para comparar:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._otherContracts.map((c) => RadioListTile<int>(
                          title: Text(c.originalFilename),
                          subtitle: Text('${c.contractType ?? ""} · Riesgo: ${c.riskScore?.toInt() ?? "--"}'),
                          value: c.id,
                          groupValue: _selectedId,
                          onChanged: (val) => setState(() => _selectedId = val),
                        )),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: (_selectedId == null || _comparing) ? null : _compare,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E8B57),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _comparing
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(color: Colors.white),
                            )
                          : const Text('Comparar'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    ],
                    if (_result != null) ...[
                      const SizedBox(height: 20),
                      _buildResult(_result!),
                    ],
                  ],
                ),
    );
  }

  Widget _buildResult(Map<String, dynamic> result) {
    Widget section(String title, List<dynamic>? items) {
      if (items == null || items.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 6),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('•  $item'),
                )),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resultado de la comparación', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(result['summary'] ?? ''),
            if (result['risk_score_change'] != null) ...[
              const SizedBox(height: 8),
              Text('Cambio en el riesgo: ${result['risk_score_change']}',
                  style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 16),
            section('Cláusulas nuevas', result['new_clauses']),
            section('Cláusulas eliminadas', result['removed_clauses']),
            section('Obligaciones que aumentaron', result['obligations_increased']),
            section('Riesgos que aumentaron', result['risks_increased']),
            section('Riesgos que disminuyeron', result['risks_decreased']),
          ],
        ),
      ),
    );
  }
}
