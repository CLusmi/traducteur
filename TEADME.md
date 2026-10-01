# Traducteur

Petit outil Windows pour **écrire et lire dans une autre langue, dans n'importe quelle application** : messagerie, navigateur, mails…

- **Ctrl+Entrée** : ton message est traduit dans la langue choisie, puis envoyé.
- **Triple-clic** sur un texte : sa traduction s'affiche dans une petite bulle.
- Une **pastille** déplaçable rappelle la paire de langues active, par exemple `FR → EN : CTRL + ENTER`.
- L'**interface s'affiche dans ta langue** (9 langues disponibles).

Le script ne modifie aucune application : il agit simplement comme ton clavier (copier, coller, Entrée).

---

## Installation

1. **Installe AutoHotkey v2** : va sur [autohotkey.com](https://www.autohotkey.com), clique sur *Download* puis choisis **v2.0**. Installe-le avec les options par défaut.
2. **Télécharge `Traducteur.ahk`** depuis ce dépôt (ouvre le fichier puis *Download raw file*).
3. **Range-le dans un dossier fixe**, par exemple `Documents\Traducteur`.
4. **Double-clique sur `Traducteur.ahk`**. La pastille apparaît en bas à droite de l'écran, et une icône **H** verte s'ajoute près de l'horloge.
5. Au premier lancement, la paire est **Français → Anglais**. Pour la changer : **clic droit sur la pastille** → **Ma langue est :** et **Langue traduite en :**.
6. *(Optionnel)* Clic droit sur la pastille → **Lancer au démarrage de Windows**.

---

## Premiers pas

### Écrire dans une autre langue

1. Ouvre une conversation, dans n'importe quelle appli.
2. Écris ton message dans ta langue, par exemple : `Salut, on joue ce soir ?`
3. Appuie sur **Ctrl+Entrée**.
4. Le texte est remplacé par sa traduction (`Hey, are we playing tonight?`) puis envoyé.

**Entrée seule** envoie toujours le message tel quel, sans traduction.

### Lire un texte dans une autre langue

1. **Triple-clique** sur un message reçu dans une autre langue.
2. Une bulle affiche la traduction dans ta langue, près de la souris.
3. Pour la fermer : **Échap**, ou un clic ailleurs. **Copier** copie la traduction.

Si le texte est déjà dans ta langue, rien ne s'affiche et le triple-clic garde son rôle habituel.

### Le menu de la pastille

Clic droit sur la pastille :

| Menu | Rôle |
|---|---|
| **Écrire et traduire** · **Lire et traduire** · **Déplacer la pastille** | Lignes grisées : rappel des gestes (Ctrl+Entrée, triple-clic, glisser) |
| **Traduction au triple-clic** | Active ou coupe la lecture au triple-clic |
| **Ma langue est :** | La langue dans laquelle tu lis (bulle), et celle de l'interface |
| **Langue traduite en :** | La langue dans laquelle Ctrl+Entrée traduit |
| **Inverser les deux langues** | Échange les deux langues |
| Afficher / replacer la pastille | Masque la pastille, ou la remet en bas à droite |
| Lancer au démarrage de Windows | Lance le traducteur avec Windows |
| Quitter | Ferme le traducteur |

**Le menu, la bulle et les messages s'affichent dans « Ma langue ».** Si tu choisis *English*, tout passe en anglais. Si tu choisis *Deutsch*, tout passe en allemand, etc.

Pour **déplacer la pastille**, fais-la glisser avec le clic gauche. Le même menu s'ouvre aussi par un clic droit sur l'icône **H** près de l'horloge.

---

## Langues disponibles

| Langue | Nom dans le menu |
|---|---|
| Allemand | Deutsch |
| Anglais | English |
| Espagnol | Español |
| Français | Français |
| Néerlandais | Nederlands |
| Norvégien | Norsk |
| Polonais | Polski |
| Portugais | Português |
| Roumain | Română |

Chaque langue apparaît dans le menu sous son propre nom.

**Ajouter une langue** : ouvre `Traducteur.ahk` avec le Bloc-notes, puis :

1. Ajoute une ligne `["code", "Nom"]` dans la liste `LANGUES`, en haut du fichier, par exemple `["it", "Italiano"]`. Les codes sont ceux de Google Traduction ([liste des codes](https://cloud.google.com/translate/docs/languages)).
2. *(Optionnel)* Pour avoir l'interface dans cette langue, copie un bloc `AjouterTextes(...)` en bas du fichier, remplace le code et traduis les phrases. Sans ce bloc, l'interface s'affiche en anglais.

---

## Réglages

Tous les réglages sont en haut de `Traducteur.ahk`. Relance le script après une modification.

| Réglage | Par défaut | Rôle |
|---|---|---|
| `LANGUES` | 9 langues | Langues proposées dans le menu (les phrases de l'interface sont en bas du fichier) |
| `APPS_EXCLUES` | vide | Applis où Ctrl+Entrée garde son rôle normal, ex. `"WINWORD.EXE,OUTLOOK.EXE"` |
| `LONGUEUR_MAX` | `2000` | Taille maxi d'un message traduit avec Ctrl+Entrée |
| `LONGUEUR_MAX_LECTURE` | `4000` | Taille maxi d'un texte lu (au-delà, seul le début est traduit) |
| `DELAI_COLLAGE` | `200` | Pause (ms) entre le collage de la traduction et l'envoi. À augmenter si le message part avant d'être traduit |
| `LARGEUR_BULLE` | `420` | Largeur maxi de la bulle |
| `COULEUR_PASTILLE` | `5865F2` | Couleur de la pastille |

Tes choix (langues, position de la pastille, triple-clic activé ou non) sont enregistrés dans `%APPDATA%\Traducteur\reglages.ini`.

---

## Créer un .exe

Un `.exe` se lance sans avoir AutoHotkey installé.

1. Fais un clic droit sur `Traducteur.ahk` → **Compile Script** (sous Windows 11, clique d'abord sur *Afficher d'autres options*). Si l'option n'apparaît pas, ouvre **AutoHotkey Dash** depuis le menu Démarrer → **Compile**.
2. La première fois, AutoHotkey propose de télécharger le compilateur **Ahk2Exe** : accepte.
3. `Traducteur.exe` apparaît à côté du script.

Pour choisir les options (icône, version), lance **Convert .ahk to .exe** depuis le menu Démarrer : *Source* = `Traducteur.ahk`, *Base File* = une version **v2** 64-bit, puis **Convert**.

Certains antivirus se méfient des `.exe` créés avec AutoHotkey (faux positif). Dans ce cas, garde la version `.ahk`.

---

## Bon à savoir

- **La traduction passe par Google Traduction**, sans compte ni clé personnelle, via un accès gratuit non officiel. Il peut cesser de fonctionner un jour. Les textes traduits sont envoyés à Google.
- **Le presse-papiers est utilisé** pour copier et coller les textes, puis il est remis comme avant.
- **Ctrl+Entrée marche partout.** Dans Word, il traduirait tout le document (Ctrl+Z annule) : ajoute les applis concernées dans `APPS_EXCLUES`.
- **Les terminaux sont ignorés** (Invite de commandes, PowerShell, Windows Terminal, PuTTY…), parce que Ctrl+C y arrêterait le programme en cours.
- **Le triple-clic sélectionne un paragraphe.** Sur un message de plusieurs lignes, il arrive que seule la ligne visée soit traduite.
- **Un triple-clic sur un lien ouvre le lien**, comme d'habitude : vise le texte.
- **Si tu as besoin du triple-clic pour autre chose** (sélectionner un paragraphe dans Word, un jeu…), décoche *Traduction au triple-clic* dans le menu. Ctrl+Entrée continue de fonctionner.
- Les messages qui commencent par `/` (commandes) partent sans traduction.
- En cas de souci (pas d'internet…), la pastille clignote en rouge et **le message n'est pas envoyé**.

---

## Désinstaller

1. Clic droit sur la pastille → décoche **Lancer au démarrage de Windows**, puis **Quitter**.
2. Supprime `Traducteur.ahk` (ou le `.exe`) et le dossier `%APPDATA%\Traducteur`.
