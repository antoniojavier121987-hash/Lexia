import 'package:flutter/material.dart';
import '../services/api_service.dart';

class _SimResult {
  final String question;
  String? answer;
  bool loading;
  _SimResult(this.question, {this.answer, this.loading = true});
}

class SimulateScreen extends StatefulWidget {
  final int contractId;
  const SimulateScreen({super.key, required this.contractId});

  @override
  State<SimulateScreen> createState() => _SimulateScreenState();
}

class _SimulateScreenState extends State<SimulateScreen> {
  final _controller = TextEditingController();
  final List<_SimResult> _results = [];

  final List<String> _suggestedScenarios = [
    '¿Qué pasa si pierdo mi trabajo?',
    '¿Qué pasa si dejo de pagar?',
    '¿Qué pasa si quiero cancelar dentro de seis meses?',
    '¿Qué pasa si vendo mi empresa?',
    '¿Qué pasa si fallezco?',
    '¿Qué pasa si cierro mi negocio?',
    '¿Qué ocurre si incumplo una cláusula?',
    '¿Qué pasa si cambia la ley?',
  ];

  Future<void> _runScenario(String question) async {
    final result = _SimResult(question);
    setState(() => _results.insert(0, result));

    try {
      final answer = await ApiService.simulateScenario(widget.contractId, question);
      setState(() {
        result.answer = answer;
        result.loading = false;
      });
    } catch (e) {
      setState(() {
        result.answer = 'Error: $e';
        result.loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulador de escenarios'),
        backgroundColor: const Color(0xFF2E8B57),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestedScenarios.map((q) {
                return ActionChip(label: Text(q), onPressed: () => _runScenario(q));
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _results.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Elige un escenario de arriba, o escribe el tuyo abajo',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final r = _results[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.question, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              r.loading
                                  ? const SizedBox(
                                      height: 16, width: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(r.answer ?? ''),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: '¿Qué pasa si...?',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (text) {
                        if (text.trim().isNotEmpty) {
                          _runScenario(text);
                          _controller.clear();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF2E8B57),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                      onPressed: () {
                        final text = _controller.text;
                        if (text.trim().isNotEmpty) {
                          _runScenario(text);
                          _controller.clear();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
