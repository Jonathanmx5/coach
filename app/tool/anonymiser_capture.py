"""Retire le prenom d'une capture de l'ecran d'accueil, pour la page GitHub.

L'appli affiche « Bonjour <Prenom> ! » et l'initiale dans l'avatar. Sans
prenom enregistre, elle afficherait « Bonjour ! » et une silhouette
(Icons.person_outline) : ce script reproduit exactement cet etat sur une
capture deja prise, pour ne pas avoir a toucher au profil de l'utilisateur.

Le prenom est efface en reconstruisant le fond (degrade vertical par colonne
entre la ligne propre du dessus et celle du dessous, plus le grain), puis le
point d'exclamation d'origine est rapproche, detoure par sa luminance.

Usage : python tool/anonymiser_capture.py accueil.png [accueil_aurore.png ...]
Modifie les fichiers sur place : travailler sur des copies.
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# Reperes mesures sur une capture 1280 x 2772 (densite 2,5).
BANDE = (211, 277)  # lignes occupees par le salut
AVATAR_CENTRE = (143, 283)
AVATAR_RAYON = 75
ICONE_DP = 24
DENSITE = 2.5
MARGE_FOND = 11  # hauteur echantillonnee au-dessus et au-dessous
LISSAGE = 7  # demi-fenetre de lissage horizontal du fond
GRAIN = 4.0  # ecart-type du bruit, mesure sur le fond
BLANC = 238  # luminance du texte de l'en-tete

FONTE_ICONES = Path(
    r"C:\src\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf"
)
PERSON_OUTLINE = "\ue497"


def mots(im, gauche=240, droite=1100, seuil=120):
    """Groupes de colonnes claires de la bande : les mots du salut."""
    px = im.convert("L").crop((gauche, BANDE[0], droite, BANDE[1]))
    cols = [max(px.getpixel((x, y)) for y in range(px.height)) for x in range(px.width)]
    bouts, d = [], None
    for x, v in enumerate(cols):
        if v > seuil and d is None:
            d = x
        elif v <= seuil and d is not None:
            if x - d > 1:
                bouts.append([d + gauche, x + gauche])
            d = None
    if d is not None:
        bouts.append([d + gauche, droite])
    g = []
    for a, b in bouts:
        if g and a - g[-1][1] < 14:
            g[-1][1] = b
        else:
            g.append([a, b])
    return g


def moyenne(px, x, y0, y1):
    s = [0, 0, 0]
    for y in range(y0, y1):
        c = px[x, y]
        for i in range(3):
            s[i] += c[i]
    return [v / (y1 - y0) for v in s]


def lisser(serie, demi):
    return [
        [
            sum(s[k] for s in serie[max(0, i - demi) : i + demi + 1])
            / len(serie[max(0, i - demi) : i + demi + 1])
            for k in range(3)
        ]
        for i in range(len(serie))
    ]


def effacer_prenom(im, px, alea):
    """« Bonjour <Prenom> ! » devient « Bonjour ! »."""
    g = mots(im)
    if len(g) != 3:
        raise SystemExit(f"{len(g)} mots trouves dans la bande, attendu 3 : {g}")
    (_, fin_bonjour), (p0, p1), (e0, e1) = g
    ecart = e0 - p1  # l'espace avant le « ! », a reproduire
    marge = 6
    x0, x1 = fin_bonjour, min(e1 + marge, im.width)

    # Le point d'exclamation : alpha tire de sa luminance sur son propre fond.
    bg = sum(moyenne(px, e0 - marge, BANDE[0], BANDE[0] + 6)) / 3
    point = []
    for x in range(e0 - marge, e1 + marge):
        col = []
        for y in range(BANDE[0], BANDE[1]):
            r, v, b = px[x, y]
            lum = 0.299 * r + 0.587 * v + 0.114 * b
            col.append(max(0.0, min(1.0, (lum - bg) / (BLANC - bg))))
        point.append(col)

    # Fond reconstruit : degrade vertical par colonne, entre dessus et dessous.
    hauts = lisser(
        [moyenne(px, x, BANDE[0] - MARGE_FOND, BANDE[0]) for x in range(x0, x1)], LISSAGE
    )
    bas = lisser(
        [moyenne(px, x, BANDE[1], BANDE[1] + MARGE_FOND) for x in range(x0, x1)], LISSAGE
    )
    h = BANDE[1] - BANDE[0]
    for i, x in enumerate(range(x0, x1)):
        for j in range(h):
            f = (j + 0.5) / h
            bruit = alea.gauss(0, GRAIN)
            px[x, BANDE[0] + j] = tuple(
                max(0, min(255, round(hauts[i][k] + (bas[i][k] - hauts[i][k]) * f + bruit)))
                for k in range(3)
            )

    depart = fin_bonjour + ecart - marge
    for i, col in enumerate(point):
        x = depart + i
        if not x0 <= x < x1:
            continue
        for j, a in enumerate(col):
            if a > 0.004:
                px[x, BANDE[0] + j] = tuple(
                    round(c + (BLANC - c) * a) for c in px[x, BANDE[0] + j]
                )
    return p0, p1


def remplacer_initiale(im, px, alea):
    """L'initiale de l'avatar devient la silhouette d'Icons.person_outline."""
    cx, cy = AVATAR_CENTRE
    ech = []
    for a in range(0, 360, 5):
        x = round(cx + math.cos(math.radians(a)) * (AVATAR_RAYON - 12))
        y = round(cy + math.sin(math.radians(a)) * (AVATAR_RAYON - 12))
        ech.append(px[x, y])
    fond = [sum(c[i] for c in ech) / len(ech) for i in range(3)]
    # La couleur de la silhouette est celle du texte de l'en-tete.
    encre = max(
        (px[x, y] for x in range(cx - 60, cx + 60) for y in range(cy - 60, cy + 60)),
        key=sum,
    )

    r2 = (AVATAR_RAYON - 5) ** 2
    for y in range(cy - AVATAR_RAYON, cy + AVATAR_RAYON + 1):
        for x in range(cx - AVATAR_RAYON, cx + AVATAR_RAYON + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r2:
                b = alea.gauss(0, 3.5)
                px[x, y] = tuple(max(0, min(255, round(c + b))) for c in fond)

    taille, s = round(ICONE_DP * DENSITE), 4
    tuile = Image.new("L", (taille * s, taille * s), 0)
    ImageDraw.Draw(tuile).text(
        (taille * s // 2, taille * s // 2),
        PERSON_OUTLINE,
        font=ImageFont.truetype(str(FONTE_ICONES), taille * s),
        fill=255,
        anchor="mm",
    )
    masque = tuile.resize((taille, taille), Image.LANCZOS)
    masque = masque.crop(masque.getbbox())  # centre sur le dessin, pas sur la police
    im.paste(
        Image.new("RGB", masque.size, encre),
        (cx - masque.width // 2, cy - masque.height // 2),
        masque,
    )


for nom in sys.argv[1:]:
    chemin = Path(nom)
    img = Image.open(chemin).convert("RGB")
    pixels = img.load()
    hasard = random.Random(7)
    a, b = effacer_prenom(img, pixels, hasard)
    remplacer_initiale(img, pixels, hasard)
    img.save(chemin)
    print(f"{chemin.name} : prenom (x {a}-{b}) et initiale retires")
