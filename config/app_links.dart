/// Liens externes de l'application.
class AppLinks {
  /// Page affichée après le clic sur le lien de confirmation e-mail (au lieu de localhost).
  /// Fichier : docs/auth-confirmed.html (GitHub Pages). Surchargeable avec --dart-define=AUTH_REDIRECT_URL=...
  static const String authRedirectUrl = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'https://idrissjeux1987.github.io/aml-mobile/auth-confirmed.html',
  );
}
