/*
 * ECE HERO — Interface graphique Processing
 * Projet d'électronique ING1 S2 — ECE Paris
 * Auteurs : Jules PAULIAC, Tristan PERE-RASSAT, Mathieu BONHEUR
 *
 * Dépendances : Processing 4.x + librairie Serial (incluse)
 * Port : COM5 (Arduino Nano)
 *
 * Fréquences réelles mesurées à l'oscilloscope (Ra=Rb=1kΩ, C=0.1µF) :
 *   Do  = 1284.7 Hz | Ré  = 1454.4 Hz | Mi  = 1676.3 Hz | Fa  = 1971.0 Hz
 *   Sol = 2410.9 Hz | La  = 3075.9 Hz | Si  = 4287.7 Hz | Do+ = 7045.8 Hz
 */

import processing.serial.*;

// ── CONFIGURATION ──────────────────────────────────────────────────────────
final String PORT_COM  = "COM5";
final int    BAUDRATE  = 9600;
final int    BPM       = 120;
final int    NB_PISTES = 8;
final int    HAUTEUR_NOTE = 50;
final float  VITESSE   = 3.5;

// ── FRÉQUENCES RÉELLES (Hz) — mesurées à l'oscilloscope ──────────────────
// Ces valeurs sont utilisées côté Arduino pour identifier les notes.
// Elles sont rappelées ici pour documentation.
// Do=1284.7 | Ré=1454.4 | Mi=1676.3 | Fa=1971.0 | Sol=2410.9 | La=3075.9 | Si=4287.7 | Do+=7045.8

// ── NOMS DES NOTES ────────────────────────────────────────────────────────
String[] NOM_NOTES = {"DO", "RE", "MI", "FA", "SOL", "LA", "SI", "DO2"};

// ── COULEURS PISTES ───────────────────────────────────────────────────────
color[] COULEURS = {
  color(220, 50,  50),   // Do    — rouge
  color(220, 130, 50),   // Ré    — orange
  color(220, 210, 50),   // Mi    — jaune
  color(80,  200, 80),   // Fa    — vert
  color(50,  200, 200),  // Sol   — cyan
  color(80,  120, 220),  // La    — bleu
  color(160, 80,  220),  // Si    — violet
  color(220, 80,  180)   // Do+   — rose
};

// ── VARIABLES JEU ─────────────────────────────────────────────────────────
Serial port;
boolean portOuvert = false;

int score = 0;
int combo = 0;
String noteAffichee = "";

ArrayList<int[]> notesActives = new ArrayList<int[]>();
long dernierGenerationNote = 0;
int intervalleNotes = 900;

boolean menuActif = true;
int selectionMenu = 0;
String[] optionsMenu = {"  JOUER  ", "  QUITTER  "};

String feedbackTexte = "";
long feedbackTimer = 0;
color feedbackCouleur;

int largeurPiste;
int zoneHit;

// ── HIT FLASH PAR PISTE ───────────────────────────────────────────────────
long[] hitFlashTimer = new long[8];

// ─────────────────────────────────────────────────────────────────────────
// SETUP
// ─────────────────────────────────────────────────────────────────────────
void setup() {
  size(900, 700);
  frameRate(60);
  textFont(createFont("Arial Bold", 18));

  largeurPiste = width / NB_PISTES;
  zoneHit = height - 80;

  // Connexion Arduino sur COM5
  try {
    println("Ports disponibles :");
    printArray(Serial.list());
    port = new Serial(this, PORT_COM, BAUDRATE);
    port.bufferUntil('\n');
    portOuvert = true;
    println("Arduino connecte sur " + PORT_COM);
  } catch (Exception e) {
    println("ATTENTION : Arduino non detecte sur " + PORT_COM + ". Mode demo clavier actif.");
    portOuvert = false;
  }

  if (portOuvert) {
    port.write("BPM:" + BPM + "\n");
  }
}

// ─────────────────────────────────────────────────────────────────────────
// DRAW
// ─────────────────────────────────────────────────────────────────────────
void draw() {
  background(15, 15, 25);

  if (menuActif) {
    dessinerMenu();
  } else {
    dessinerJeu();
  }
}

// ─────────────────────────────────────────────────────────────────────────
// MENU
// ─────────────────────────────────────────────────────────────────────────
void dessinerMenu() {
  // Titre
  textAlign(CENTER, CENTER);
  fill(255);
  textSize(58);
  text("ECE HERO", width/2, 130);

  textSize(16);
  fill(150);
  text("Instrument : jouer Do = monter  |  Do+ = selectionner", width/2, 195);

  // Statut connexion
  textSize(13);
  if (portOuvert) {
    fill(80, 220, 80);
    text("Arduino connecte — " + PORT_COM, width/2, 230);
  } else {
    fill(220, 80, 80);
    text("Arduino non detecte — mode demo clavier (1-8)", width/2, 230);
  }

  // Boutons menu
  for (int i = 0; i < optionsMenu.length; i++) {
    float yOpt = 320 + i * 110;
    boolean sel = (i == selectionMenu);

    rectMode(CENTER);
    if (sel) {
      fill(COULEURS[i == 0 ? 0 : 4]);
      rect(width/2, yOpt, 320, 65, 14);
      fill(255);
    } else {
      fill(55);
      rect(width/2, yOpt, 280, 58, 12);
      fill(170);
    }
    textSize(24);
    textAlign(CENTER, CENTER);
    text(optionsMenu[i], width/2, yOpt);
  }

  textSize(13);
  fill(90);
  textAlign(CENTER, CENTER);
  text("Ou appuyez sur ESPACE pour jouer", width/2, height - 35);
}

// ─────────────────────────────────────────────────────────────────────────
// JEU
// ─────────────────────────────────────────────────────────────────────────
void dessinerJeu() {
  // Fond pistes alternées
  for (int i = 0; i < NB_PISTES; i++) {
    fill(i % 2 == 0 ? color(20, 20, 30) : color(25, 25, 38));
    noStroke();
    rectMode(CORNER);
    rect(i * largeurPiste, 0, largeurPiste, height);
    stroke(50);
    strokeWeight(1);
    line(i * largeurPiste, 0, i * largeurPiste, height);
  }

  // Génération automatique de notes
  if (millis() - dernierGenerationNote > intervalleNotes) {
    int piste = (int) random(NB_PISTES);
    notesActives.add(new int[]{piste, -HAUTEUR_NOTE, 1});
    dernierGenerationNote = millis();
  }

  // Défilement et dessin notes
  for (int i = notesActives.size() - 1; i >= 0; i--) {
    int[] n = notesActives.get(i);
    n[1] += (int) VITESSE;

    int x = n[0] * largeurPiste + largeurPiste / 2;
    int y = n[1];
    color c = COULEURS[n[0]];

    // Note principale
    fill(c);
    noStroke();
    rectMode(CENTER);
    rect(x, y, largeurPiste - 10, HAUTEUR_NOTE, 8);

    // Halo lumineux
    fill(red(c), green(c), blue(c), 50);
    rect(x, y, largeurPiste - 4, HAUTEUR_NOTE + 8, 10);

    // Supprimer si manquée
    if (y > height + 60) {
      notesActives.remove(i);
      combo = 0;
    }
  }

  // Zone de frappe (bas)
  for (int i = 0; i < NB_PISTES; i++) {
    int x = i * largeurPiste + largeurPiste / 2;
    color c = COULEURS[i];

    // Flash si hit récent
    boolean flash = (millis() - hitFlashTimer[i] < 150);
    if (flash) {
      fill(red(c), green(c), blue(c), 180);
    } else {
      fill(red(c), green(c), blue(c), 70);
    }
    noStroke();
    rectMode(CENTER);
    rect(x, zoneHit, largeurPiste - 10, 30, 6);

    // Contour
    stroke(c);
    strokeWeight(flash ? 2.5 : 1.5);
    noFill();
    rect(x, zoneHit, largeurPiste - 10, 30, 6);

    // Nom note
    fill(c);
    noStroke();
    textSize(11);
    textAlign(CENTER, CENTER);
    text(NOM_NOTES[i], x, zoneHit + 28);
  }

  // HUD score
  fill(255);
  textSize(26);
  textAlign(LEFT, TOP);
  text("SCORE : " + score, 15, 15);

  if (combo > 1) {
    fill(255, 220, 50);
    textSize(18);
    text("x" + combo + " COMBO", 15, 50);
  }

  // Note Arduino reçue
  if (!noteAffichee.isEmpty()) {
    textSize(14);
    fill(100, 220, 255);
    textAlign(RIGHT, TOP);
    text("Arduino : " + noteAffichee, width - 12, 15);
  }

  // Feedback hit
  if (millis() - feedbackTimer < 500 && !feedbackTexte.isEmpty()) {
    textSize(38);
    fill(feedbackCouleur);
    textAlign(CENTER, CENTER);
    text(feedbackTexte, width / 2, height / 2 - 60);
  }

  // Instructions
  fill(70);
  textSize(12);
  textAlign(CENTER, BOTTOM);
  text("Touches clavier 1-8 ou instrument | ECHAP = menu", width / 2, height - 5);
}

// ─────────────────────────────────────────────────────────────────────────
// SERIAL — réception depuis Arduino
// ─────────────────────────────────────────────────────────────────────────
void serialEvent(Serial p) {
  String ligne = p.readStringUntil('\n');
  if (ligne == null) return;
  ligne = trim(ligne);
  if (ligne.length() == 0) return;

  println("Recu Arduino : [" + ligne + "]");

  // Ignorer message de boot
  if (ligne.equals("ECE_HERO_READY")) return;

  noteAffichee = ligne;

  // Navigation menu via instrument
  if (menuActif) {
    if (ligne.equals("DO")) {
      selectionMenu = (selectionMenu + 1) % optionsMenu.length;
    } else if (ligne.equals("DO2")) {
      validerMenu();
    }
    return;
  }

  // En jeu : jouer la note
  jouerNote(ligne);
}

// ─────────────────────────────────────────────────────────────────────────
// LOGIQUE JEU
// ─────────────────────────────────────────────────────────────────────────
void jouerNote(String note) {
  int pisteNote = -1;
  for (int i = 0; i < NOM_NOTES.length; i++) {
    if (NOM_NOTES[i].equals(note)) {
      pisteNote = i;
      break;
    }
  }
  if (pisteNote < 0) return;

  hitFlashTimer[pisteNote] = millis();

  // Chercher note active dans la zone de frappe (±55px)
  for (int i = notesActives.size() - 1; i >= 0; i--) {
    int[] n = notesActives.get(i);
    if (n[0] == pisteNote && abs(n[1] - zoneHit) < 55) {
      notesActives.remove(i);
      score += 10 * (1 + combo / 5);
      combo++;
      feedbackTexte = combo > 5 ? "PERFECT! x" + combo : "GOOD!";
      feedbackCouleur = combo > 5 ? color(255, 220, 50) : color(80, 255, 120);
      feedbackTimer = millis();
      return;
    }
  }

  // Note jouée mais rien à frapper
  combo = 0;
  feedbackTexte = "MISS";
  feedbackCouleur = color(255, 80, 80);
  feedbackTimer = millis();
}

void validerMenu() {
  if (selectionMenu == 0) {
    menuActif = false;
    score = 0;
    combo = 0;
    notesActives.clear();
  } else {
    exit();
  }
}

// ─────────────────────────────────────────────────────────────────────────
// CLAVIER — fallback et navigation
// ─────────────────────────────────────────────────────────────────────────
void keyPressed() {
  // Neutraliser fermeture Processing par ECHAP
  if (key == ESC) {
    key = 0;
    menuActif = true;
    return;
  }

  // ESPACE → démarrer
  if (key == ' ' && menuActif) {
    validerMenu();
    return;
  }

  // Navigation menu clavier
  if (menuActif) {
    if (keyCode == DOWN || keyCode == RIGHT)
      selectionMenu = (selectionMenu + 1) % optionsMenu.length;
    if (keyCode == UP || keyCode == LEFT)
      selectionMenu = (selectionMenu - 1 + optionsMenu.length) % optionsMenu.length;
    if (keyCode == ENTER || keyCode == RETURN)
      validerMenu();
    return;
  }

  // Touches 1-8 en jeu (fallback clavier)
  if (key >= '1' && key <= '8') {
    int piste = key - '1';
    String note = NOM_NOTES[piste];
    noteAffichee = note + " (clavier)";
    jouerNote(note);
  }
}
