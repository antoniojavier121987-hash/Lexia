import 'package:flutter/material.dart';

class RiskBadge extends StatelessWidget {
  final String? riskLevel; // BAJO | MEDIO | ALTO
  final double size;

  const RiskBadge({super.key, required this.riskLevel, this.size = 12});

  Color get _color {
    switch (riskLevel?.toUpperCase()) {
      case 'ALTO':
        return const Color(0xFFE53935); // rojo
      case 'MEDIO':
        return const Color(0xFFFBC02D); // amarillo
      case 'BAJO':
        return const Color(0xFF43A047); // verde
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
    );
  }
}

/// Versión con etiqueta de texto, usada en tarjetas de resumen.
class RiskChip extends StatelessWidget {
  final String? riskLevel;

  const RiskChip({super.key, required this.riskLevel});

  Color get _bgColor {
    switch (riskLevel?.toUpperCase()) {
      case 'ALTO':
        return const Color(0xFFFFEBEE);
      case 'MEDIO':
        return const Color(0xFFFFF8E1);
      case 'BAJO':
        return const Color(0xFFE8F5E9);
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  Color get _textColor {
    switch (riskLevel?.toUpperCase()) {
      case 'ALTO':
        return const Color(0xFFC62828);
      case 'MEDIO':
        return const Color(0xFFF9A825);
      case 'BAJO':
        return const Color(0xFF2E7D32);
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(
        riskLevel?.toUpperCase() ?? 'SIN EVALUAR',
        style: TextStyle(color: _textColor, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
