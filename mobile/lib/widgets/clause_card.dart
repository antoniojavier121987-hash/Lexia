import 'package:flutter/material.dart';
import '../models/clause.dart';
import 'risk_badge.dart';

class ClauseCard extends StatelessWidget {
  final Clause clause;

  const ClauseCard({super.key, required this.clause});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        leading: RiskBadge(riskLevel: clause.riskLevel, size: 14),
        title: Text(
          clause.title ?? 'Cláusula ${clause.orderIndex}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: RiskChip(riskLevel: clause.riskLevel),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (clause.plainExplanation != null) ...[
                  const Text('En palabras simples:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(clause.plainExplanation!),
                  const SizedBox(height: 12),
                ],
                if (clause.riskReason != null) ...[
                  const Text('Por qué tiene este riesgo:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(clause.riskReason!),
                  const SizedBox(height: 12),
                ],
                const Text('Texto original:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  clause.originalText,
                  style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
