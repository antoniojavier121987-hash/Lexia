import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/contract.dart';
import '../services/api_service.dart';
import '../widgets/risk_badge.dart';
import '../widgets/clause_card.dart';
import 'chat_screen.dart';
import 'simulate_screen.dart';
import 'compare_screen.dart';

class ContractDetailScreen extends StatefulWidget {
  final int contractId;
  const ContractDetailScreen({super.key, required this.contractId});

  @override
  State<ContractDetailScreen> createState() => _ContractDetailScreenState();
}

class _ContractDetailScreenState extends State<ContractDetailScreen> {
  Contract? _contract;
  bool _loading = true;
  bool _analyzing = false;
  bool _downloadingReport = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final contract = await ApiService.getContract(widget.contractId);
      setState(() => _contract = contract);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _analyze() async {
    setState(() {
      _analyzing = true;
      _error = null;
    });
    try {
      final contract = await ApiService.analyzeContract(widget.contractId);
      setState(() => _contract = contract);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _downloadReport() async {
    setState(() => _downloadingReport = true);
    try {
      final bytes = await ApiService.downloadReport(widget.contractId);
      await Printing.layoutPdf(
  onLayout: (format) async => Uint8List.fromList(bytes),
);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar el reporte: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_contract?.originalFilename ?? 'Contrato'),
        backgroundColor: const Color(0xFF2E8B57),
        foregroundColor: Colors.white,
        actions: [
          if (_contract?.status == 'analizado') ...[
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Preguntarle a LEXIA sobre este contrato',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChatScreen(contractId: widget.contractId)),
                );
              },
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'simulate') {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SimulateScreen(contractId: widget.contractId)),
                  );
                } else if (value == 'compare') {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CompareScreen(currentContractId: widget.contractId)),
                  );
                } else if (value == 'report') {
                  _downloadReport();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'simulate',
                  child: ListTile(
                    leading: Icon(Icons.timeline_outlined),
                    title: Text('Simular escenarios'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'compare',
                  child: ListTile(
                    leading: Icon(Icons.compare_arrows_outlined),
                    title: Text('Comparar con otro contrato'),
                  ),
                ),
                PopupMenuItem(
                  value: 'report',
                  child: ListTile(
                    leading: _downloadingReport
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                    title: const Text('Descargar reporte PDF'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _buildBody(),
      floatingActionButton: (_contract != null && _contract!.status != 'analizado')
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF2E8B57),
              foregroundColor: Colors.white,
              icon: _analyzing
                  ? const SizedBox(
                      height: 16, width: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_analyzing ? 'Analizando...' : 'Analizar con IA'),
              onPressed: _analyzing ? null : _analyze,
            )
          : null,
    );
  }

  Widget _buildBody() {
    final c = _contract!;
    if (c.status != 'analizado') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_empty, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                c.status == 'error'
                    ? 'Hubo un error al analizar este contrato. Intenta de nuevo.'
                    : 'Este contrato aún no ha sido analizado.\nToca "Analizar con IA" para comenzar.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRiskScoreCard(c),
        const SizedBox(height: 16),
        if (c.summaryExecutive != null) ...[
          const Text('Resumen ejecutivo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(c.summaryExecutive!),
          const SizedBox(height: 16),
        ],
        if (c.summaryGeneral != null) ...[
          const Text('Resumen general', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(c.summaryGeneral!),
          const SizedBox(height: 20),
        ],
        if (c.riskBreakdown != null) ...[
          const Text('Riesgo por categoría', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: c.riskBreakdown!.entries.map((e) {
              return Chip(
                avatar: RiskBadge(riskLevel: e.value, size: 10),
                label: Text('${_categoryLabel(e.key)}'),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
        const Text('Cláusulas detectadas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ...c.clauses.map((clause) => ClauseCard(clause: clause)),
        const SizedBox(height: 24),
        const Card(
          color: Color(0xFFFFF8E1),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'LEXIA es una herramienta de apoyo y no sustituye el asesoramiento '
              'de un abogado. Para decisiones legales importantes, consulta con un profesional.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ),
        const SizedBox(height: 80), // espacio para el botón flotante de chat
      ],
    );
  }

  Widget _buildRiskScoreCard(Contract c) {
    return Card(
      color: const Color(0xFF2E8B57),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Riesgo general', style: TextStyle(color: Colors.white70)),
                Text(
                  '${c.riskScore?.toInt() ?? '--'} / 100',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                Text(c.riskLevel ?? '', style: const TextStyle(color: Colors.white)),
              ],
            ),
            const Spacer(),
            if (c.contractType != null)
              Flexible(
                child: Text(
                  c.contractType!,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(String key) {
    const labels = {
      'financiero': 'Financiero',
      'legal': 'Legal',
      'laboral': 'Laboral',
      'tributario': 'Tributario',
      'privacidad': 'Privacidad',
      'permanencia': 'Permanencia',
    };
    return labels[key] ?? key;
  }
}
