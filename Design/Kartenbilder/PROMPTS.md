# Rook Raid – Bild-Prompts für die Kartenbilder

20 Bilder: 15 Karten und 5 Ultimates. Jedes Bild bekommt den **Stil-Block** plus die **Szene** der Karte.

## So geht's

1. Prompt = Stil-Block + Szene + Hintergrundfarbe der Rolle. In Midjourney hinten `--ar 4:5` anhängen; in ChatGPT/DALL·E, Firefly oder Ideogram „Hochformat 4:5“ wählen.
2. Bild speichern und nach dem **Schlüssel** benennen (z. B. `shield.png`, `meteor.jpg`). Alle in einen Ordner.
3. Im Ordner `RookRaid` ausführen: `python3 Design/Kartenbilder/einbauen.py <Ordner>` (braucht Pillow: `pip3 install pillow`). Das Skript schneidet auf 4:5 zu (Feinjustierung je Karte in `zuschnitt.json`), verkleinert auf 600 × 750 und legt die Bilder als JPEG nach `RookRaid/Assets.xcassets/CardArtPainted/`.
4. In Xcode neu bauen. Karten ohne gemaltes Bild zeigen weiter das gezeichnete – man kann also Bild für Bild austauschen.

Ohne Skript: Bild selbst auf 4:5 zuschneiden und in Xcode im Asset-Katalog unter `CardArtPainted` als Bildsatz `painted-art-card-<schlüssel>` (Karten) bzw. `painted-art-ult-<schlüssel>` (Ultimates) anlegen.

**Stand v0.9.34:** Alle 20 Bilder sind eingebaut (Rückzug mit Gemini erzeugt).

**Tipps:** Erst 2–3 Karten erzeugen und den Stil festzurren, dann mit demselben Stil-Block (in Midjourney am besten mit `--sref` auf das beste Bild) den Rest. Oben links liegt in der App der Mana-Tropfen, unten rechts das Bonus-Abzeichen – dort sollte nichts Wichtiges sein.

## Stil-Block (für jedes Bild gleich)

> Epic cartoon trading card illustration for a mobile strategy game, chess pieces as heroic characters with expressive faces, bold clean shapes, thick dark navy outlines, cel shading with soft rim light and glow, vibrant saturated colors, dramatic lighting, magical particles, single clear focal subject centered slightly low, dark vignette background tinted {FARBE}, portrait 4:5, no text, no letters, no numbers, no card frame, no border, no watermark, keep the top-left and bottom-right corners calm and empty.

Rollenfarben für {FARBE}:
- Angriff: `warm orange-red (#E0613A)`
- Kontrolle: `icy blue (#5BB5D9)`
- Verteidigung: `emerald green (#6FBF73)`
- Mana: `deep violet (#8B5CF6)`
- Comeback und Ultimates: `radiant gold (#F2C14E)`

Figurenfarben im Spiel: eigene Figuren cremeweiß mit goldenen Akzenten, gegnerische Figuren dunkel-navy.

## Karten

| Schlüssel | Karte | Rolle | Szene |
|---|---|---|---|
| `shield` | Schild | Verteidigung | A cream-white chess rook hero bracing behind a giant glowing emerald heater shield with a rook emblem, a translucent green energy dome shimmering around it, enemy arrows bouncing off in sparks |
| `freeze` | Frost | Kontrolle | A dark navy enemy chess pawn frozen solid inside a cracked crystal-clear ice block, surprised frozen face, frost creeping over the ground, icy mist and drifting snowflakes |
| `bulwark` | Bollwerk | Verteidigung | Three brave cream chess pawns standing shoulder to shoulder behind a crenellated stone wall, a glowing green protective barrier arching over all of them |
| `sprint` | Sturmlauf | Angriff | A cream chess pawn dashing forward at full speed with a determined grin, speed lines and dust clouds behind it, two glowing golden chevron arrows pointing upward ahead |
| `lightning` | Blitz | Kontrolle | A jagged golden lightning bolt striking down from a dark storm cloud onto a lone dark enemy chess pawn, sparks and shattered fragments flying |
| `knighting` | Ritterschlag | Angriff | A cream chess pawn kneeling while a glowing royal sword touches its shoulder, the pawn transforming into a proud chess knight horse in a burst of golden sparkles |
| `reinforce` | Verstärkung | Verteidigung | A fresh cream chess pawn rising out of a glowing green magic summoning circle on a battlefield, beams of light and floating runes |
| `revive` | Wiederkehr | Comeback | A golden chess knight rising from glowing embers with radiant angel wings and a halo, phoenix-like resurrection, warm god rays |
| `bishopize` | Läuferweihe | Angriff | A small cream pawn transforming into a tall chess bishop inside a column of holy light, ornate mitre with violet accents, glowing glyphs circling |
| `advance` | Vormarsch | Angriff | A row of three cream chess pawns marching forward in formation with tiny war banners, glowing arrows on the ground pointing ahead |
| `swap` | Leibwache | Verteidigung | A cream chess king and an emerald chess rook trading places in a swirl of golden circular arrows, a teleport flash between them |
| `drain` | Manaraub | Kontrolle | A swirling violet-blue vortex sucking glowing purple mana droplets out of the air, a dark crystal at its center draining the energy |
| `focus` | Konzentration | Mana | A glowing violet crystal ball with an open mystical eye on an ornate wooden stand, four purple mana droplets orbiting it, calm magical aura |
| `sacrifice` | Bauernopfer | Mana | A stone altar where a cream chess pawn dissolves into violet flames, the flames turning into glowing purple mana droplets rising upward |
| `retreat` | Rückzug (v0.9.34) | Verteidigung | A clever cream-white chess pawn hero hopping backward two squares on a glowing chessboard with a sly confident grin, a faint ghostly afterimage of the pawn on the square it just left, a dark navy enemy pawn lunging forward and grabbing only empty air, two glowing emerald chevron arrows pointing downward behind the hero, small green protective sparkles |

## Ultimates (alle Gold, noch epischer)

| Schlüssel | Ultimate | Szene |
|---|---|---|
| `meteor` | Meteor | A giant flaming meteor crashing down onto a chessboard battlefield, blazing fiery trail, shockwave rings and flying debris |
| `iceAge` | Eiszeit | A colossal glacier and jagged ice mountains engulfing a chessboard battlefield in a howling snowstorm, everything freezing in cold blue light |
| `fortress` | Festung | A mighty stone castle with a golden shield emblem and a red banner, protected by a shimmering golden energy dome |
| `coronation` | Krönung | A golden jeweled crown descending in a beam of light onto a humble cream chess pawn that starts to glow like a queen |
| `rebirth` | Wiedergeburt | A cream chess queen rising triumphantly from flames with blazing phoenix wings, swirling embers |

## Beispiel, fertig zusammengesetzt (Frost, Midjourney)

> Epic cartoon trading card illustration for a mobile strategy game, chess pieces as heroic characters with expressive faces, bold clean shapes, thick dark navy outlines, cel shading with soft rim light and glow, vibrant saturated colors, dramatic lighting, magical particles, single clear focal subject centered slightly low, dark vignette background tinted icy blue (#5BB5D9), portrait 4:5, no text, no letters, no numbers, no card frame, no border, no watermark, keep the top-left and bottom-right corners calm and empty. A dark navy enemy chess pawn frozen solid inside a cracked crystal-clear ice block, surprised frozen face, frost creeping over the ground, icy mist and drifting snowflakes --ar 4:5

## Fertiger Prompt: Rückzug (Gemini / Nano Banana)

> Epic cartoon trading card illustration for a mobile strategy game, chess pieces as heroic characters with expressive faces, bold clean shapes, thick dark navy outlines, cel shading with soft rim light and glow, vibrant saturated colors, dramatic lighting, magical particles, single clear focal subject centered slightly low, dark vignette background tinted emerald green (#6FBF73), portrait 4:5, no text, no letters, no numbers, no card frame, no border, no watermark, keep the top-left and bottom-right corners calm and empty. A clever cream-white chess pawn hero with golden accents hopping backward two squares on a glowing chessboard with a sly confident grin, a faint ghostly afterimage of the pawn on the square it just left, a dark navy enemy pawn lunging forward and grabbing only empty air, two glowing emerald chevron arrows pointing downward behind the hero, small green protective sparkles.
