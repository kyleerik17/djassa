/// Chaînes de texte de l'écran Profil, extraites du code en dur.
///
/// Ceci est une étape intermédiaire avant une vraie localisation
/// (flutter_localizations + fichiers .arb). Migrer vers l10n plus tard
/// consistera juste à remplacer `ProfileStrings.xxx` par
/// `AppLocalizations.of(context)!.xxx` — la structure reste identique.
class ProfileStrings {
  const ProfileStrings._();

  static const title = 'Profil';
  static const sectionTitle = 'Mon espace client';

  static const defaultRoleLabel = 'Client Djassa';
  static const defaultRole = 'Client';
  static const defaultAccount = 'Compte e-commerce';

  static const backofficeTitle = 'Backoffice articles';
  static const backofficeSubtitle = 'Ajouter, modifier et publier le catalogue';

  static const paymentTitle = 'Moyen de paiement';
  static const paymentSubtitleEmpty = 'Enregistrer votre Mobile Money par défaut';

  static const ordersTitle = 'Mes commandes';
  static const ordersSubtitle = 'Suivi, paiement des commandes en attente';
  static const ordersSubtitlePending = 'Un paiement est en attente';

  static const addressTitle = 'Adresse de livraison';
  static const addressSubtitleEmpty = 'Enregistrer le point de livraison';
  static const addressDialogTitle = 'Adresse de livraison';
  static const addressDialogDescription =
      'Enregistrez votre adresse pour la réutiliser directement au moment de commander.';
  static const addressCityLabel = 'Ville';
  static const addressCommuneLabel = 'Commune';
  static const addressCommuneHintNoCity = 'Choisir une ville d\u2019abord';
  static const addressCommuneHint = 'Sélectionner une commune';
  static const addressValidationError =
      'Veuillez sélectionner une ville et une commune.';
  static const addressSaved = 'Adresse de livraison enregistrée.';
  static const cancel = 'Annuler';
  static const save = 'Enregistrer';


  static const favoritesSubtitle = 'Articles sauvegardés';

  static const devTitle = 'Dev: Ange Erik';
  static const devSubtitle = 'Portfolio et CV';
  static const devBio = 'Développeur Flutter & full-stack basé en Côte d\'Ivoire.';
  static const devPortfolio = 'Portfolio';
  static const devGithub = 'GitHub';
  static const devLinkError = 'Impossible d\'ouvrir le lien.';

  static const supportTitle = 'Assistance';
  static const supportSubtitle = 'Aide pour choisir un article';

  static const paymentSaved = 'Moyen de paiement enregistré.';
  static const paymentNoSession =
      'Votre session a expiré, veuillez vous reconnecter.';

  static const logout = 'Déconnexion';
  static const logoutConfirmTitle = 'Se déconnecter ?';
  static const logoutConfirmBody =
      'Vous devrez vous reconnecter pour\naccéder à votre compte.';
  static const logoutStay = 'Rester connecté';

  static const editProfileTooltip = 'Modifier mon profil';
  static const closeTooltip = 'Fermer';
  static const revealPhoneTooltip = 'Afficher le numéro complet';
  static const hidePhoneTooltip = 'Masquer le numéro';
  static const copyPhoneTooltip = 'Copier le numéro';
  static const phoneCopied = 'Numéro copié.';
}