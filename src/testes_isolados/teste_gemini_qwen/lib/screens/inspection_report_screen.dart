import 'package:flutter/material.dart';

import '../models/inspection_plan.dart';
import '../models/inspection_result.dart';

class InspectionReportScreen extends StatelessWidget {
  const InspectionReportScreen({
    super.key,
    required this.plan,
    required this.results,
  });

  final InspectionPlan plan;
  final List<InspectionResult> results;

  @override
  Widget build(BuildContext context) {
    final approvedCount = results.where((result) => result.approved).length;
    final rejectedCount = results.length - approvedCount;
    final allApproved = rejectedCount == 0 && results.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Relatorio final')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Card(
                color: allApproved
                    ? const Color(0xFFEAF7EE)
                    : const Color(0xFFFFF0EE),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Peca: ${plan.partName}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        allApproved
                            ? 'Resultado geral: APROVADO'
                            : 'Resultado geral: REPROVADO',
                      ),
                      Text(
                        'Etapas aprovadas: $approvedCount / ${results.length}',
                      ),
                      if (plan.notes.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Text('Notas: ${plan.notes}'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final result = results[index];
                    return ListTile(
                      tileColor: result.approved
                          ? const Color(0xFFEFFAF2)
                          : const Color(0xFFFFF2F1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Icon(
                        result.approved ? Icons.check_circle : Icons.cancel,
                        color: result.approved
                            ? const Color(0xFF1B7F3B)
                            : const Color(0xFFB3261E),
                      ),
                      title: Text(result.step.title),
                      subtitle: Text(
                        'Esperado ${result.step.expectedValue.toStringAsFixed(3)} ${result.step.unit} | '
                        'Medido ${result.measuredValue.toStringAsFixed(3)} ${result.unit} | '
                        'Delta ${result.delta.toStringAsFixed(3)} ${result.unit}',
                      ),
                    );
                  },
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.home),
                label: const Text('Voltar ao inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
