import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/contract.dart';
import '../services/api_service.dart';
import '../widgets/risk_badge.dart';
import 'upload_screen.dart';
import 'contract_detail_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Contract>> _contractsFuture;

  @override
  void initState() {
    super.initState();
    _contractsFuture = ApiService.listContracts();
  }

  void _refresh() {
    setState(() => _contractsFuture = ApiService.listContracts());
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis contratos'),
        backgroundColor: const Color(0xFF2E8B57),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Contract>>(
          future: _contractsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final contracts = snapshot.data ?? [];
            if (contracts.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  Icon(Icons.description_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Aún no has analizado ningún contrato',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 4),
                  Text('Toca el botón + para empezar',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                ],
              );
            }
            return ListView.builder(
              itemCount: contracts.length,
              itemBuilder: (context, index) {
                final c = contracts[index];
                return ListTile(
                  leading: RiskBadge(riskLevel: c.riskLevel, size: 16),
                  title: Text(c.originalFilename, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${c.contractType ?? c.status} · ${DateFormat('dd/MM/yyyy').format(c.createdAt)}',
                  ),
                  trailing: c.riskScore != null
                      ? Text('${c.riskScore!.toInt()}/100', style: const TextStyle(fontWeight: FontWeight.bold))
                      : null,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ContractDetailScreen(contractId: c.id)),
                    );
                    _refresh();
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2E8B57),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo contrato'),
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UploadScreen()),
          );
          _refresh();
        },
      ),
    );
  }
}
