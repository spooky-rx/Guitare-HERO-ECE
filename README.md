# 🎸 ECE HERO - Instrument de musique électronique

## 📌 Description

ECE HERO est un projet d’électronique consistant à concevoir un instrument de musique inspiré du jeu Guitar Hero.

Le système permet de :
- Générer des notes via un circuit NE555
- Jouer ces notes à l’aide de boutons poussoirs
- Amplifier le signal pour produire un son audible
- Mesurer la fréquence du signal avec un Arduino
- Communiquer avec une interface graphique (Processing)

---

## 🧠 Objectifs

- Appliquer les concepts d’électronique analogique (NE555)
- Implémenter une mesure de fréquence avec un microcontrôleur
- Concevoir un système complet hardware + software
- Travailler en équipe avec des outils de versionning (GitHub)

---

## 🏗️ Architecture du projet

### 🔹 Partie matérielle
- NE555 en mode astable → génération du signal
- Résistances → réglage de la fréquence (notes)
- Condensateur (0.1 µF)
- Potentiomètre → réglage du volume
- Haut-parleur → sortie audio
- Arduino Nano → mesure et communication

### 🔹 Partie logicielle
- Interruptions timer (Arduino)
- Calcul de fréquence
- Communication série avec Processing

---

## ⚙️ Fonctionnement

1. L’utilisateur appuie sur un bouton
2. Le NE555 génère un signal carré
3. La fréquence dépend des résistances associées
4. Le signal est amplifié
5. Le son est émis par le haut-parleur
6. L’Arduino mesure la fréquence
7. La donnée est envoyée à l’interface graphique

---

## 📊 Performances

- ✔ Génération de signaux audibles
- ✔ Volume réglable (potentiomètre)
- ✔ Mesure de fréquence précise (< 3% d’erreur)
- ⚠ Notes approximatives (composants limités)
- ⚠ Présence de bruit dans le signal

---

## ⚠️ Contraintes rencontrées

- Utilisation de résistances majoritairement de 1kΩ
- Condensateur unique (0.1 µF)
- Absence de filtrage → bruit audible
- Précision limitée des fréquences

---

## 🔧 Améliorations possibles

- Ajouter un filtre RC pour réduire le bruit
- Utiliser des résistances plus variées
- Intégrer un amplificateur audio dédié
- Améliorer la précision des notes

---

## 🛠️ Outils utilisés

- Arduino IDE
- Processing
- Oscilloscope
- Breadboard
- GitHub (versionning)

---

## 👥 Organisation du projet

Le projet a été réalisé en utilisant une **méthode Agile** :
- Développement itératif
- Tests réguliers
- Adaptation aux contraintes

### 📅 Planning (Gantt simplifié)

| Tâche         | Semaine 1 | Semaine 2 | Semaine 3 | Semaine 4 |
|--------------|----------|----------|----------|----------|
| Conception   | ███      |          |          |          |
| Montage      |          | ███      |          |          |
| Programmation|          | ███      | ███      |          |
| Tests        |          |          | ███      | ███      |
| Rapport      |          |          |          | ███      |

---

## 🔄 Versionning (GitHub)

GitHub a permis :
- Le suivi des modifications
- Le travail collaboratif
- La sauvegarde du projet
- Le retour en arrière en cas d’erreur

---

## 📷 Résultats expérimentaux

Des oscillogrammes ont été réalisés pour analyser :
- les fréquences générées
- la qualité du signal
- la présence de bruit

👉 Voir dossier `/annexes` ou `/images`

---

## 📚 Bibliographie

- Datasheet NE555
- Documentation Arduino
- https://processing.org/

---

## 📎 Auteurs

- Nom Prénom
- Nom Prénom
- Nom Prénom

---

## ⚠️ Licence

Projet académique – ECE Paris
