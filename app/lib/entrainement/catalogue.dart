import 'modele.dart';

/// Exercices connus. Chaque exercice à matériel ou de salle a une
/// alternative ; la chaîne finit toujours par un exercice au poids du corps.
const catalogueExercices = <Exercice>[
  // Jambes
  Exercice(
    id: 'squat',
    nom: 'Squat',
    groupe: Groupe.jambes,
    consigne: 'Pieds écartés comme tes épaules, assieds-toi en arrière en gardant le dos droit.',
  ),
  Exercice(
    id: 'squat_halteres',
    nom: 'Squat avec haltères',
    groupe: Groupe.jambes,
    requis: {Materiel.halteres},
    alternative: 'squat',
    consigne:
        'Un haltère dans chaque main le long du corps, descends en squat.',
  ),
  Exercice(
    id: 'presse_cuisses',
    nom: 'Presse à cuisses',
    groupe: Groupe.jambes,
    salleSeulement: true,
    alternative: 'squat',
    consigne:
        'Pousse la plateforme avec les talons sans verrouiller les genoux.',
  ),
  Exercice(
    id: 'fentes',
    nom: 'Fentes',
    groupe: Groupe.jambes,
    consigne: 'Un grand pas en avant, descends le genou arrière vers le sol, puis reviens.',
  ),
  Exercice(
    id: 'fentes_halteres',
    nom: 'Fentes avec haltères',
    groupe: Groupe.jambes,
    requis: {Materiel.halteres},
    alternative: 'fentes',
    consigne: 'Comme les fentes, un haltère dans chaque main.',
  ),
  Exercice(
    id: 'pont_fessier',
    nom: 'Pont fessier',
    groupe: Groupe.jambes,
    consigne:
        'Sur le dos, genoux pliés, monte le bassin en serrant les fessiers.',
  ),
  Exercice(
    id: 'souleve_terre_halteres',
    nom: 'Soulevé de terre roumain',
    groupe: Groupe.jambes,
    requis: {Materiel.halteres},
    alternative: 'pont_fessier',
    consigne: 'Haltères devant les cuisses, penche le buste dos droit, jambes presque tendues.',
  ),
  Exercice(
    id: 'swing_kettlebell',
    nom: 'Swing kettlebell',
    groupe: Groupe.jambes,
    requis: {Materiel.kettlebell},
    alternative: 'pont_fessier',
    consigne: 'Pousse les hanches vers l\'avant pour propulser la kettlebell à hauteur de poitrine.',
  ),
  // Pousser
  Exercice(
    id: 'pompes_genoux',
    nom: 'Pompes sur les genoux',
    groupe: Groupe.pousser,
    consigne: 'Genoux au sol, corps aligné, descends la poitrine vers le sol.',
  ),
  Exercice(
    id: 'pompes',
    nom: 'Pompes',
    groupe: Groupe.pousser,
    consigne: 'Corps gainé de la tête aux talons, descends la poitrine au sol.',
  ),
  Exercice(
    id: 'developpe_halteres',
    nom: 'Développé avec haltères',
    groupe: Groupe.pousser,
    requis: {Materiel.halteres},
    alternative: 'pompes',
    consigne: 'Allongé, pousse les haltères vers le plafond puis redescends.',
  ),
  Exercice(
    id: 'developpe_couche',
    nom: 'Développé couché',
    groupe: Groupe.pousser,
    salleSeulement: true,
    alternative: 'pompes',
    consigne: 'Barre à hauteur de poitrine, pousse sans cambrer le dos.',
  ),
  Exercice(
    id: 'dips_chaise',
    nom: 'Dips sur chaise',
    groupe: Groupe.pousser,
    consigne: 'Mains sur le bord d\'une chaise stable, plie les coudes puis repousse.',
  ),
  // Tirer
  Exercice(
    id: 'superman',
    nom: 'Superman',
    groupe: Groupe.tirer,
    consigne: 'À plat ventre, décolle bras et jambes en contractant le dos, tiens une seconde.',
  ),
  Exercice(
    id: 'tirage_elastique',
    nom: 'Tirage avec élastique',
    groupe: Groupe.tirer,
    requis: {Materiel.elastiques},
    alternative: 'superman',
    consigne: 'Élastique fixé devant toi, tire les coudes vers l\'arrière en serrant les omoplates.',
  ),
  Exercice(
    id: 'rowing_halteres',
    nom: 'Rowing avec haltères',
    groupe: Groupe.tirer,
    requis: {Materiel.halteres},
    alternative: 'superman',
    consigne: 'Buste penché, dos plat, tire l\'haltère vers la hanche.',
  ),
  Exercice(
    id: 'tractions',
    nom: 'Tractions',
    groupe: Groupe.tirer,
    requis: {Materiel.barreTraction},
    alternative: 'tirage_elastique',
    consigne: 'Suspendu à la barre, monte le menton au-dessus de la barre.',
  ),
  Exercice(
    id: 'tirage_vertical',
    nom: 'Tirage vertical',
    groupe: Groupe.tirer,
    salleSeulement: true,
    alternative: 'tirage_elastique',
    consigne: 'Tire la barre vers le haut de la poitrine, coudes vers le bas.',
  ),
  // Tronc
  Exercice(
    id: 'planche',
    nom: 'Planche',
    groupe: Groupe.tronc,
    duree: true,
    consigne: 'Sur les avant-bras, corps droit, ventre serré, respire.',
  ),
  Exercice(
    id: 'gainage_lateral',
    nom: 'Gainage latéral',
    groupe: Groupe.tronc,
    duree: true,
    consigne: 'Sur un avant-bras, hanches hautes, corps aligné. Change de côté à mi-parcours.',
  ),
  Exercice(
    id: 'crunch',
    nom: 'Crunch',
    groupe: Groupe.tronc,
    consigne: 'Sur le dos, genoux pliés, décolle les épaules sans tirer sur la nuque.',
  ),
  Exercice(
    id: 'dead_bug',
    nom: 'Dead bug',
    groupe: Groupe.tronc,
    consigne: 'Sur le dos, bras et jambes en l\'air, étends un bras et la jambe opposée, bas du dos collé au sol.',
  ),
  // Cardio
  Exercice(
    id: 'jumping_jacks',
    nom: 'Jumping jacks',
    groupe: Groupe.cardio,
    duree: true,
    consigne: 'Saute en écartant bras et jambes, puis reviens.',
  ),
  Exercice(
    id: 'corde',
    nom: 'Corde à sauter',
    groupe: Groupe.cardio,
    duree: true,
    requis: {Materiel.cordeASauter},
    alternative: 'jumping_jacks',
    consigne: 'Petits sauts réguliers sur la pointe des pieds.',
  ),
  Exercice(
    id: 'montees_genoux',
    nom: 'Montées de genoux',
    groupe: Groupe.cardio,
    duree: true,
    consigne: 'Sur place, monte les genoux à hauteur de hanche, rythme vif.',
  ),
];

Exercice exerciceParId(String id) =>
    catalogueExercices.firstWhere((e) => e.id == id);
