/*
 * ECE HERO — Code Arduino Nano
 * Projet d'électronique ING1 S2 — ECE Paris
 * Auteurs : Jules PAULIAC, Tristan PERE-RASSAT, Mathieu BONHEUR
 *
 * Fonctions :
 *   - Mesure de la fréquence du signal NE555 (interruption Timer1, fenêtre 100ms)
 *   - Identification de la note jouée (±10% de tolérance)
 *   - Envoi de la note via Serial vers Processing
 *   - Métronome sur Timer2 (buzzer, fréquence réglable via Serial)
 */

#include <avr/interrupt.h>

// ── PINS ───────────────────────────────────────────────────────────────────
#define PIN_NE555   2     // Signal NE555 en entrée (INT0)
#define PIN_BUZZER  9     // Buzzer métronome (PWM Timer2 non utilisé, toggle manuel)
#define PIN_LED     13    // LED de debug optionnelle

// ── FRÉQUENCES CIBLES (Hz) ────────────────────────────────────────────────
// Octave jouée réellement avec Ra=1kΩ, Rb=1kΩ, C=0.1µF
// f = 1.44 / ((Ra + 2*Rb) * C) ≈ 4800 Hz pour toutes les touches identiques
// Les fréquences réelles mesurées varient selon les Rb utilisées
const float FREQ_NOTES[] = {
  1284.7,   // Do  (touche 1) — mesuré à l'oscilloscope
  1500.0,   // Ré  (touche 2) — valeur estimée
  1800.0,   // Mi  (touche 3)
  2000.0,   // Fa  (touche 4)
  2200.0,   // Sol (touche 5)
  2410.9,   // La  (touche 6) — mesuré à l'oscilloscope
  3500.0,   // Si  (touche 7)
  7045.8    // Do+ (touche 8) — mesuré à l'oscilloscope
};
const char* NOM_NOTES[] = {"DO", "RE", "MI", "FA", "SOL", "LA", "SI", "DO2"};
const int NB_NOTES = 8;
const float TOLERANCE = 0.10; // ±10%

// ── VARIABLES VOLATILES (modifiées dans interruptions) ─────────────────────
volatile unsigned long compteurFronts = 0;  // fronts montants comptés
volatile bool fenetre100ms = false;          // flag levé par Timer1
volatile bool bip = false;                   // flag levé par Timer2
volatile unsigned int metronomeCompteur = 0;
volatile unsigned int metronomeMax = 1;

// ── VARIABLES GLOBALES ────────────────────────────────────────────────────
float frequenceMesuree = 0.0;
int bpmMetronome = 120;    // BPM reçu depuis Processing (défaut 120)
unsigned long dernierEnvoi = 0;

// ─────────────────────────────────────────────────────────────────────────
// SETUP
// ─────────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(9600);

  pinMode(PIN_NE555,  INPUT);
  pinMode(PIN_BUZZER, OUTPUT);
  pinMode(PIN_LED,    OUTPUT);

  // Interruption externe INT0 (pin 2) sur front montant → compte les fronts
  attachInterrupt(digitalPinToInterrupt(PIN_NE555), compterFront, RISING);

  // ── Timer1 : fenêtre de mesure 100 ms ──────────────────────────────────
  // Clock 16 MHz, prescaler 256 → tick = 16µs
  // OCR1A = 6250 → 6250 × 16µs = 100 ms
  cli();
  TCCR1A = 0;
  TCCR1B = 0;
  TCNT1  = 0;
  OCR1A  = 6250;
  TCCR1B |= (1 << WGM12);              // Mode CTC
  TCCR1B |= (1 << CS12);               // Prescaler 256
  TIMSK1 |= (1 << OCIE1A);             // Interrupt on compare match

  // ── Timer2 : métronome ────────────────────────────────────────────────
  // Recalculé à chaque changement de BPM via configurerMetronome()
  TCCR2A = 0;
  TCCR2B = 0;
  TCNT2  = 0;
  sei();

  configurerMetronome(bpmMetronome);
  Serial.println("ECE_HERO_READY");
}

// ─────────────────────────────────────────────────────────────────────────
// LOOP
// ─────────────────────────────────────────────────────────────────────────
void loop() {

  // ── Mesure de fréquence (toutes les 100 ms) ───────────────────────────
  if (fenetre100ms) {
    fenetre100ms = false;
    // f = nb fronts × 10 (fenêtre de 100ms → ×10 pour avoir Hz)
    frequenceMesuree = compteurFronts * 10.0;
    compteurFronts = 0;

    // Identification de la note
    String noteDetectee = identifierNote(frequenceMesuree);

    // Envoi vers Processing si une note est détectée
    if (noteDetectee != "" && millis() - dernierEnvoi > 100) {
      Serial.println(noteDetectee);
      dernierEnvoi = millis();
      digitalWrite(PIN_LED, HIGH);
      delay(10);
      digitalWrite(PIN_LED, LOW);
    }
  }

  // ── Métronome (bip buzzer) ─────────────────────────────────────────────
  if (bip) {
    bip = false;
    digitalWrite(PIN_BUZZER, !digitalRead(PIN_BUZZER));
  }

  // ── Lecture commandes depuis Processing ───────────────────────────────
  if (Serial.available() > 0) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    if (cmd.startsWith("BPM:")) {
      int nouveauBPM = cmd.substring(4).toInt();
      if (nouveauBPM > 20 && nouveauBPM < 300) {
        bpmMetronome = nouveauBPM;
        configurerMetronome(bpmMetronome);
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// FONCTIONS
// ─────────────────────────────────────────────────────────────────────────

// Identifie la note la plus proche de la fréquence mesurée (±TOLERANCE)
String identifierNote(float f) {
  if (f < 100.0) return ""; // Bruit de fond
  for (int i = 0; i < NB_NOTES; i++) {
    float ecart = abs(f - FREQ_NOTES[i]) / FREQ_NOTES[i];
    if (ecart <= TOLERANCE) {
      return String(NOM_NOTES[i]);
    }
  }
  return "";
}

// Configure Timer2 pour le métronome au BPM donné
// Un bip correspond à un demi-battement (toggle à chaque interrupt)
void configurerMetronome(int bpm) {
  // Période entre deux toggles = 60000ms / bpm / 2
  // On utilise un compteur de débordement avec prescaler 1024
  // Clock 16MHz / 1024 = 15625 Hz → tick = 64µs
  // nb_ticks = (60s / bpm / 2) / 64µs
  unsigned long ticksParDemi = (unsigned long)(60000000UL / bpm / 2 / 64);

  cli();
  TCCR2A = 0;
  TCCR2B = 0;
  TCNT2  = 0;

  // Si ticksParDemi > 255, on utilise un compteur logiciel
  metronomeCompteur = 0;
  metronomeMax = ticksParDemi / 255 + 1;
  OCR2A = 255;

  TCCR2A |= (1 << WGM21);             // Mode CTC
  TCCR2B |= (1 << CS22) | (1 << CS21) | (1 << CS20); // Prescaler 1024
  TIMSK2 |= (1 << OCIE2A);
  sei();
}

// Compteur logiciel pour Timer2 (permet des BPM lents)

// ─────────────────────────────────────────────────────────────────────────
// INTERRUPTIONS
// ─────────────────────────────────────────────────────────────────────────

// INT0 — front montant sur pin 2 (signal NE555)
void compterFront() {
  compteurFronts++;
}

// Timer1 Compare Match A — toutes les 100 ms
ISR(TIMER1_COMPA_vect) {
  fenetre100ms = true;
}

// Timer2 Compare Match A — métronome
ISR(TIMER2_COMPA_vect) {
  metronomeCompteur++;
  if (metronomeCompteur >= metronomeMax) {
    metronomeCompteur = 0;
    bip = true;
  }
}
