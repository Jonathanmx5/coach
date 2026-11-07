import 'modele.dart';

/// Routines de mobilité et d'étirements, lancées avec la séance guidée.
enum Routine { apresEffort, reveil, recuperation }

/// [id] : les photos de l'étirement (animation_exercice.dart), ou null
/// quand aucune image libre de droits ne convient.
Etape _etirement(
  String? id,
  String titre,
  String consigne, {
  int secondes = 30,
}) =>
    Etape(titre: titre, consigne: consigne, secondes: secondes, exerciceId: id);

Seance routine(Routine r) => switch (r) {
  Routine.apresEffort => Seance(
    titre: 'Étirements après l\'effort',
    lieu: Lieu.maison,
    etapes: [
      _etirement(
        'etir_quadriceps',
        'Cuisses (avant)',
        'Debout, pose le dessus d\'un pied sur une chaise derrière toi, bassin en avant. Tiens, puis change de jambe.',
      ),
      _etirement(
        'etir_ischios',
        'Arrière des cuisses',
        'Assis, une jambe tendue devant toi, penche le buste dos plat vers le pied. Tiens, puis change de jambe.',
      ),
      _etirement(
        'etir_fessiers',
        'Fessiers',
        'Sur le dos, cheville sur le genou opposé, ramène doucement les jambes vers toi. Tiens, puis change.',
      ),
      _etirement(
        'etir_mollets',
        'Mollets',
        'Mains au mur, une jambe tendue derrière, talon au sol. Tiens, puis change.',
      ),
      _etirement(
        'etir_pectoraux',
        'Pectoraux',
        'Main contre un mur, bras tendu à hauteur d\'épaule, tourne doucement le buste à l\'opposé. Change de bras.',
      ),
      _etirement(
        'etir_epaules',
        'Épaules et dos',
        'Bras croisé devant la poitrine, tire doucement avec l\'autre main. Change de bras.',
      ),
      _etirement(
        'posture_enfant',
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
        'cercles_nuque',
        'Cercles de nuque',
        'Roule doucement la tête, sans forcer, dans un sens puis dans l\'autre.',
        secondes: 30,
      ),
      _etirement(
        'cercles_epaules',
        'Cercles d\'épaules',
        'Bras tendus sur les côtés, petits puis grands cercles vers l\'arrière, puis vers l\'avant.',
      ),
      _etirement(
        'chat_vache',
        'Chat-vache',
        'À quatre pattes, arrondis puis creuse le dos en respirant.',
        secondes: 60,
      ),
      _etirement(
        'rotation_buste',
        'Rotation du buste',
        'Assis, mains derrière la tête, tourne lentement le buste d\'un côté puis de l\'autre.',
        secondes: 60,
      ),
      _etirement(
        'fente_basse',
        'Fente basse',
        'Un genou au sol, avance le bassin pour ouvrir la hanche. Change de jambe à mi-temps.',
        secondes: 60,
      ),
      _etirement(
        'squat_profond',
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
        null,
        'Respiration ventrale',
        'Debout, inspire 4 secondes par le ventre en levant les bras, expire 6 secondes en les baissant.',
        secondes: 90,
      ),
      _etirement(
        'genoux_poitrine',
        'Genoux sur la poitrine',
        'Sur le dos, ramène les genoux contre toi et balance doucement.',
        secondes: 60,
      ),
      _etirement(
        'torsion_allongee',
        'Torsion allongée',
        'Sur le dos, laisse tomber les genoux d\'un côté, bras en croix. Change à mi-temps.',
        secondes: 90,
      ),
      _etirement(
        'posture_enfant',
        'Posture de l\'enfant',
        'À genoux, fesses sur les talons, front au sol, bras devant.',
        secondes: 90,
      ),
      _etirement(
        'etir_ischios',
        'Arrière des cuisses',
        'Assis, une jambe tendue devant toi, penche le buste dos plat vers le pied. Change à mi-temps.',
        secondes: 90,
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
