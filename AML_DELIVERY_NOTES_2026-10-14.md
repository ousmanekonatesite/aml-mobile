# AML — notes de préparation livraison (14 octobre 2026)

## Ajouts dans cette archive
- Écran de contrôle des billets avec caméra QR et saisie manuelle de secours.
- Validation serveur par `aml_redeem_event_ticket` ; le client ne décide jamais seul qu'un ticket est valide.
- Registre des tickets filtrable par statut : valide, utilisé, annulé, remboursé.
- Permissions caméra Android et dépendance `mobile_scanner`.
- Migration `20261014_aml_ticket_scan_audit.sql` pour conserver l'heure du scan et l'identité du membre du staff qui l'a effectué.

## Ordre des migrations Supabase
1. `20261013_aml_user_event_tickets.sql`
2. `20261014_aml_xp_credit_conversion.sql`
3. `20261014_aml_ticket_scan_audit.sql`

Appliquer uniquement les migrations qui n'ont pas déjà été exécutées ; les migrations utilisent des `IF NOT EXISTS` quand c'est approprié, mais les fonctions RPC doivent être vérifiées dans le SQL Editor.

## Vérifications requises avant livraison
- Exécuter `flutter pub get`, puis `flutter analyze` et `flutter build apk --release` dans un environnement Flutter.
- Tester l'installation de l'APK de mise à jour sur Android, y compris l'autorisation d'installation depuis cette source.
- Vérifier les politiques RLS des tables de billetterie et les rôles autorisés au scan.
- Tester un billet valide, un billet déjà utilisé, un code inconnu et un compte non autorisé.
- Vérifier les écrans de résultats de combats et de pronostics avec des données réelles.

Cette archive n'est pas certifiée par un build local : l'environnement de préparation ne dispose pas de la commande Flutter.
