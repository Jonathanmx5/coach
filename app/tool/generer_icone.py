"""Dessine l'icône Vyta (monogramme : un V blanc et un point rose sur violet).

Produit, dans assets/icone/ :
  - icone.png : icône complète 1024 px (anciens Android) ;
  - avant.png : premier plan transparent de l'icône adaptative ;
  - play-store-512.png : icône du Play Store.
Puis : dart run flutter_launcher_icons
Usage : python tool/generer_icone.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

VIOLET = (106, 63, 181, 255)
ROSE = (242, 135, 184, 255)
BLANC = (255, 255, 255, 255)
SUR = 4  # suréchantillonnage, pour des bords lisses
DOSSIER = Path(__file__).resolve().parent.parent / 'assets' / 'icone'


def trait(d, a, b, epaisseur, couleur):
    """Segment à bouts ronds."""
    d.line([a, b], fill=couleur, width=epaisseur)
    for x, y in (a, b):
        r = epaisseur / 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=couleur)


def monogramme(taille, echelle, fond):
    """V et point, centrés ; [echelle] : part de l'image occupée par le dessin."""
    t = taille * SUR
    img = Image.new('RGBA', (t, t), VIOLET if fond else (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Dessin conçu dans un carré de 130, comme la maquette proposée.
    k = t * echelle / 130
    o = (t - 130 * k) / 2

    def p(x, y):
        return (o + x * k, o + y * k)

    e = round(16 * k)
    trait(d, p(34, 36), p(65, 100), e, BLANC)
    trait(d, p(65, 100), p(96, 36), e, BLANC)
    r = 12 * k
    cx, cy = p(96, 36)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=ROSE)
    return img.resize((taille, taille), Image.LANCZOS)


DOSSIER.mkdir(parents=True, exist_ok=True)
monogramme(1024, 1.0, fond=True).save(DOSSIER / 'icone.png')
# Android rogne l'icône adaptative en cercle ou en carré arrondi : le dessin
# reste dans la zone centrale (l'inset de 16 % est ajouté par le manifeste).
monogramme(1024, 1.0, fond=False).save(DOSSIER / 'avant.png')
monogramme(512, 1.0, fond=True).save(DOSSIER / 'play-store-512.png')
print('icônes écrites dans', DOSSIER)
