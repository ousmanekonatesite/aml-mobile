import 'package:flutter/material.dart';

/// Message lisible pour un achat de billet refusé (jamais d'erreur technique à l'écran).
String ticketPurchaseMessage(Object error) {
  final lower = error.toString().toLowerCase();
  if (lower.contains('insuffisant') && (lower.contains('crédit') || lower.contains('credit'))) {
    return 'Ton solde AML est insuffisant pour acheter ce billet. Recharge tes crédits ou convertis tes XP dans « Solde AML ».';
  }
  if (lower.contains('stock')) return 'Il n’y a plus assez de billets disponibles pour cette offre.';
  if (lower.contains('pas en vente')) return 'Cette offre n’est plus en vente.';
  if (lower.contains('connexion requise') || lower.contains('authentification')) return 'Connecte-toi pour acheter un billet.';
  if (lower.contains('socketexception') || lower.contains('failed host lookup') || lower.contains('clientexception')) {
    return 'Connexion impossible. Vérifie ton Internet et réessaie.';
  }
  return 'Achat impossible pour le moment. Réessaie dans un instant.';
}

Future<void> showTicketPurchaseError(BuildContext context, Object error) async {
  final lower = error.toString().toLowerCase();
  final noCredit = lower.contains('insuffisant') && (lower.contains('crédit') || lower.contains('credit'));
  final message = ticketPurchaseMessage(error);
  if (noCredit) {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Solde insuffisant'),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
