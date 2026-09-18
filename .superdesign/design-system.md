# SRC SCHOOL — charte visuelle MVP

Statut : première proposition issue des 11 captures de `design/`, en attente de validation visuelle.

## Source prioritaire

Le dossier `design/` reste la référence à chaque intervention. Aucune bibliothèque de styles concurrente ne remplace ces captures demandées par l’utilisateur.

- `Screenshot 2026-09-15 at 10.02.19 AM.png` : structure du tableau de bord, quatre indicateurs, cartes et actions.
- `Screenshot 2026-09-15 at 10.00.31 AM (2).png` : pastilles colorées, regroupement et actions contextuelles.
- `Screenshot 2026-09-15 at 10.02.33 AM.png` : rythme des journées et agenda.
- `Screenshot 2026-09-15 at 10.02.41 AM.png` : liste et fiche latérale ; adaptation au dossier élève.
- Captures Inbox : conversation et contexte latéral ; captures Paramètres : formulaires groupés.

Les couleurs ci-dessous sont des choix harmonisés inspirés des captures, pas un prélèvement exact. La police des captures n’est pas identifiable avec certitude : choix proposé, DM Sans.

## Produit et parcours

SaaS francophone multi-écoles SRC DIGITAL. Next.js admin/superadmin, Flutter desktop admin/comptable et mobile enseignant, FastAPI/PostgreSQL partagés. Parents informés par WhatsApp.

Mission du dashboard école : montrer la journée scolaire et les tâches nécessitant une action. Missions principales : inscrire un élève, faire l’appel, saisir les notes, enregistrer un paiement, publier un bulletin, informer les parents.

Navigation école : Tableau de bord, Élèves, Classes, Équipe, Emploi du temps, Présences, Notes et bulletins, Finances, Communications, Paramètres. Regrouper en Scolarité et Gestion, profondeur maximale de deux niveaux.
Superadmin : Vue d’ensemble, Établissements, Abonnements, Journal d’activité. Afficher clairement le périmètre plateforme/école.
Mobile enseignant : Aujourd’hui, Classes, Agenda, Notifications ; notes et appel dans une classe.

## Couleurs par rôle

| Token | Clair | Sombre | Usage |
| --- | --- | --- | --- |
| background | #F8F9F7 | #151817 | Fond global |
| surface | #FFFFFF | #202522 | Cartes, tableaux |
| ink | #202520 | #F3F5F2 | Texte principal et action noire en clair |
| muted | #626960 | #B5BEB6 | Texte secondaire |
| accent | #5B48C8 | #BCB1FF | Liens, sélection, communication |
| positive | #287454 | #8DD6AD | Présent, réglé, validé |
| attention | #A95416 | #FFC18C | En attente, retard, impayé |
| danger | #B63838 | #FFAAAA | Erreur, absent, action destructive |

Surfaces pastel claires : violet #F0ECFF, vert #EAF7EF, orange #FFF1E5, rouge #FFF0F0. Bordure claire #E3E6E0, sombre #414941. En sombre, surfaces de signal teintées très foncées, jamais de texte clair sur pastel clair.
Une couleur accompagne toujours un texte ou une icône de statut. Contrastes à contrôler sur les paires finales ; cible texte normal 4,5:1 et indicateurs/contours interactifs 3:1.

## Typographie et composants

- DM Sans pour le web ; même police embarquée dans Flutter, fallback système. Pas de serif ni de police manuscrite dans les formulaires.
- Corps web 15–16 px / 1,5, titres 28–32 px / 1,2, titres de section 18–20 px, métadonnées 13 px. Chiffres tabulaires pour montants et notes.
- Mobile : texte courant 17 unités logiques, respect intégral du facteur de texte système.
- Espacements : 4, 8, 12, 16, 24, 32, 48. Cartes rayon 20 px, champs 12 px, boutons 12–14 px, badges capsule.
- Carte blanche à bordure légère ; ombre discrète seulement pour les surfaces flottantes. Aucun verre décoratif sur les tableaux.
- Action principale noire en clair ; liens violet, états pastel. Icônes Lucide cohérentes sur web ; famille cohérente équivalente Flutter.
- Champs à labels persistants, erreurs associées, saisies conservées après échec ; bouton enregistrer avec état de progression.
- Cibles tactiles 48×48, focus visible, raccourcis standard et menus accessibles. Réduire les animations si demandé par le système.
- Français naturel, pas de statut « synchronisé » sans confirmation réelle.

## Composition et signature

Desktop : sidebar 248 px, en-tête 76 px, contenu avec marge 32 px. Quatre indicateurs compacts, puis panneau journée/activité sur deux tiers et tâches/agenda sur un tiers. Listes opérationnelles avec recherche et filtres.
Signature : une bande de semaine scolaire à pastilles douces, un repère pour chaque journée et son état d’appel, à côté des tâches du jour. Elle appartient au rythme de l’école.

```text
Desktop                         Mobile enseignant
Navigation | École · Année       École · Aujourd’hui
           | Bonjour + action   Prochain cours
           | 4 indicateurs      Faire l’appel
           | Semaine scolaire   Classes du jour
           | Activité | À faire  Statuts de synchronisation
           | Tableau | Agenda   4 onglets persistants
```

Sur petit écran web : navigation en tiroir, cartes empilées, table défilante localement ou lignes adaptatives. Sur Flutter : NavigationRail sur grand écran, NavigationBar sur mobile, SafeArea et retour propre à la plateforme. Clair/sombre selon le système. Préserver le contraste en mode contraste renforcé.

## Maquette initiale

Un tableau de bord administrateur école, format desktop et adaptation responsive. Établissement fictif « Groupe scolaire Horizon », année 2026–2027, devise FCFA. Indicateurs de démonstration clairement indiqués comme tels dans la maquette. Aucun contenu personnel des captures.

Éviter des images décoratives lourdes, un bandeau marketing ou des graphiques sans usage. Une transition douce de 150 ms suffit. Les écrans détaillés suivront cette direction après revue.
