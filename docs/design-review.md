# SRC SCHOOL — revue de direction visuelle

## Synthèse

Les 11 captures utilisateur ont été examinées. Direction retenue : navigation latérale claire, cartes blanches arrondies, typographie sans serif, boutons noirs et signaux pastel. L’adaptation scolaire se distingue par la semaine d’appel et les tâches du jour. Statut : proposition à valider, pas application fonctionnelle.

## Améliorations intégrées dans la charte

- Lisibilité : remplacer les gris très clairs observés par un texte secondaire #626960. Les tailles exactes et la police d’origine ne peuvent pas être certifiées depuis les captures.
- Information : employer présence, classe, bulletin, échéance et encaissement ; aucun contenu personnel ni vocabulaire de cabinet dans SRC SCHOOL.
- Navigation : sidebar sur desktop, quatre onglets enseignants sur mobile, actions dans les pages. Référence `tab-bars.md › Best practices` : « Use a tab bar to support navigation, not to provide actions. »
- Saisie : labels persistants, erreurs proches du champ, choix de classe/matière et état de sauvegarde explicite. Référence `entering-data.md › Best practices` : « Dynamically validate field values. »
- Accessibilité : zoom et texte système, navigation au clavier, cibles tactiles de 48 unités ; les couleurs sont accompagnées de libellés. Référence `accessibility.md › Vision` : « Convey information with more than color alone. »

## Contrastes calculés

Calcul sRGB WCAG exécuté avec Node sur les couleurs proposées, pas mesuré sur les captures. Cible texte courant : 4,5:1.

| Texte / surface | Ratio |
| --- | --- |
| #202520 / #FFFFFF | 15,59:1 |
| #626960 / #FFFFFF | 5,66:1 |
| #5B48C8 / #F0ECFF | 5,66:1 |
| #287454 / #EAF7EF | 5,13:1 |
| #A95416 / #FFF1E5 | 4,78:1 |
| #B63838 / #FFF0F0 | 5,25:1 |
| #F3F5F2 / #202522 | 14,20:1 |
| #B5BEB6 / #202522 | 8,16:1 |
| #BCB1FF / #202522 | 8,06:1 |

Ces paires passent le seuil choisi. Cela ne certifie ni le rendu de tous les états du prototype ni l’accessibilité d’une application encore à construire. Les bordures interactives, focus, erreurs, mode sombre complet et texte agrandi devront être vérifiés sur les clients réels.

## Maquette générée

Version 1 : https://p.superdesign.dev/draft/9255e0cf-2d36-4f3e-bc3b-9a946d1d55bf. Le HTML récupéré confirme les tokens principaux et DM Sans. La revue du code montre des liens de navigation `#` : maquette visuelle statique, pas parcours fonctionnels. Le rendu navigateur, le tiroir mobile, tous les états interactifs et le mode sombre ne sont pas validés. La charte demeure la cible de l’implémentation.

## Retenue visuelle

Pas de grand bandeau promotionnel ni d’illustration sans fonction : la place revient à la journée scolaire. Les espacements, badges et panneaux reprennent les références. Le choix DM Sans est une proposition, pas une identification de la police Denteva.

Références Apple lues : accessibility, layout, typography, color, designing-for-ios, designing-for-macos, sidebars, tab-bars et entering-data, dans le skill apple-design. Les recommandations de plateforme concernent Flutter iOS/macOS ; sur le web, seuls les principes de lisibilité, adaptation et interaction sont transposés.
