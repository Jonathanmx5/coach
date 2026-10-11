import 'modele.dart';

/// Routines de mobilité et d'étirements, lancées avec la séance guidée.
enum Routine { apresEffort, reveil, recuperation }

Etape _etirement(String titre, String consigne, {int secondes = 30}) =>
    Etape(titre: titre, consigne: consigne, secondes: secondes);

Seance routine(Routine r) => switch (r) {
  Routine.apresEffort => Seance(
    titre: 'Étirements après l\'effort',
    lieu: Lieu.maison,
    etapes: [
      _etirement(
        'Cuisses (avant)',
        'Debout, attrape ton pied derrière toi, genoux proches. Tiens 30 secondes, puis change de jambe.',
      ),
      _etirement(
        'Arrière des cuisses',
        'Une jambe tendue devant toi, penche le buste dos plat. Tiens, puis change de jambe.',
      ),
      _etirement(
        'Fessiers',
        'Assis, cheville sur le genou opposé, rapproche la poitrine. Tiens, puis change.',
      ),
      _etirement(
        'Mollets',
        'Mains au mur, une jambe tendue derrière, talon au sol. Tiens, puis change.',
      ),
      _etirement(
        'Pectoraux',
        'Avant-bras contre un mur, tourne doucement le buste à l\'opposé.',
      ),
      _etirement(
        'Épaules et dos',
        'Bras croisé devant la poitrine, tire doucement avec l\'autre main. Change de bras.',
      ),
      _etirement(
        'Posture de l\'enfant',
        'À genoux, fesses sur les talons, bras tendus devant, respire lentement.',
        secondes: 45,
      ),
    ],
  ),
  Routine.reveil => Seance(
    titre: 'Réveil articulaire · 5 min',
    lieu: Lieu.maison,
    etapes: [
      _etirement(
        'Cercles de nuque',
        'Roule doucement la tête, sans forcer, dans un sens puis dans l\'autre.',
        secondes: 30,
      ),
      _etirement(
        'Cercles d\'épaules',
        'Grands cercles vers l\'arrière, puis vers l\'avant.',
      ),
      _etirement(
        'Chat-vache',
        'À quatre pattes, arrondis puis creuse le dos en respirant.',
        secondes: 60,
      ),
      _etirement(
        'Rotation du buste',
        'À quatre pattes, une main derrière la tête, ouvre le coude vers le plafond. Change de côté.',
        secondes: 60,
      ),
      _etirement(
        'Fente basse',
        'Un genou au sol, avance le bassin pour ouvrir la hanche. Change de jambe à mi-temps.',
        secondes: 60,
      ),
      _etirement(
        'Squat profond',
        'Accroupi, talons au sol, coudes qui écartent les genoux.',
        secondes: 45,
      ),
    ],
  ),
  Routine.recuperation => Seance(
    titre: 'Récupération douce · 8 min',
    lieu: Lieu.maison,
    etapes: [
      _etirement(
        'Respiration ventrale',
        'Allongé, une main sur le ventre : inspire 4 secondes, expire 6 secondes.',
        secondes: 90,
      ),
      _etirement(
        'Genoux sur la poitrine',
        'Sur le dos, ramène les genoux contre toi et balance doucement.',
        secondes: 60,
      ),
      _etirement(
        'Torsion allongée',
        'Sur le dos, laisse tomber les genoux d\'un côté, bras en croix. Change à mi-temps.',
        secondes: 90,
      ),
      _etirement(
        'Posture de l\'enfant',
        'À genoux, fesses sur les talons, front au sol, bras devant.',
        secondes: 90,
      ),
      _etirement(
        'Jambes au mur',
        'Allongé, jambes contre un mur, respire calmement.',
        secondes: 120,
      ),
    ],
  ),
};

/// Routine mise en avant : étirements après une séance faite aujourd'hui, du
/// repos actif si la récupération est faible, sinon le réveil articulaire.
Routine routineConseillee({
  required bool seanceAujourdhui,
  required bool recuperationFaible,
}) {
  if (seanceAujourdhui) return Routine.apresEffort;
  if (recuperationFaible) return Routine.recuperation;
  return Routine.reveil;
}
