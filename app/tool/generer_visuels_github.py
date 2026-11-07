"""Fabrique les visuels de la page GitHub : banniere, planche d'ecrans, teintes.

Attend des captures d'ecran brutes du telephone (portrait) dans un dossier,
nommees : accueil.png  seance.png  idees.png  semaine.png  accueil_aurore.png
Les prendre avec : adb exec-out screencap -p > accueil.png

Usage : python tool/generer_visuels_github.py <dossier_des_captures>
Ecrit dans docs/images/ : banniere.png, ecrans.png, themes.png
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

RACINE = Path(__file__).resolve().parent.parent.parent
SORTIE = RACINE / "docs" / "images"
CAPTURES = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()

VIOLET = (106, 63, 181)
VIOLET_FONCE = (46, 20, 92)
ROSE = (242, 135, 184)
BLANC = (255, 255, 255)
POLICES = Path(r"C:\Windows\Fonts")

# Barre d'etat et barre de gestes, retirees des captures.
HAUT, BAS = 118, 64


def police(nom, taille):
    return ImageFont.truetype(str(POLICES / nom), taille)


def trait(d, a, b, epaisseur, couleur):
    """Segment a bouts ronds."""
    d.line([a, b], fill=couleur, width=epaisseur)
    for x, y in (a, b):
        r = epaisseur / 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=couleur)


def logo(taille):
    """Le V blanc et son point rose, sur fond transparent."""
    t = taille * 4
    img = Image.new("RGBA", (t, t), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    k = t / 130
    trait(d, (34 * k, 36 * k), (65 * k, 100 * k), round(16 * k), BLANC)
    trait(d, (65 * k, 100 * k), (96 * k, 36 * k), round(16 * k), BLANC)
    r = 12 * k
    d.ellipse([96 * k - r, 36 * k - r, 96 * k + r, 36 * k + r], fill=ROSE)
    return img.resize((taille, taille), Image.LANCZOS)


def degrade(largeur, hauteur, haut, bas):
    img = Image.new("RGB", (largeur, hauteur), haut)
    d = ImageDraw.Draw(img)
    for y in range(hauteur):
        f = y / max(hauteur - 1, 1)
        d.line(
            [(0, y), (largeur, y)],
            fill=tuple(round(haut[i] + (bas[i] - haut[i]) * f) for i in range(3)),
        )
    return img


def halo(img, centre, rayon, couleur, force):
    """Tache de lumiere coloree, fondue dans l'image."""
    c = Image.new("RGB", img.size, (0, 0, 0))
    x, y = centre
    ImageDraw.Draw(c).ellipse(
        [x - rayon, y - rayon, x + rayon, y + rayon], fill=couleur
    )
    return Image.blend(img, c.filter(ImageFilter.GaussianBlur(rayon / 2)), force)


def coins_arrondis(img, rayon):
    masque = Image.new("L", img.size, 0)
    ImageDraw.Draw(masque).rounded_rectangle(
        [0, 0, img.size[0] - 1, img.size[1] - 1], rayon, fill=255
    )
    out = img.convert("RGBA")
    out.putalpha(masque)
    return out


def ombre(img, flou, decalage, opacite):
    """Pose l'image sur son ombre portee ; rend une image plus grande."""
    marge = flou * 3
    toile = Image.new(
        "RGBA", (img.width + marge * 2, img.height + marge * 2), (0, 0, 0, 0)
    )
    o = Image.new("RGBA", toile.size, (0, 0, 0, 0))
    o.paste(
        Image.new("RGBA", img.size, (0, 0, 0, opacite)),
        (marge, marge + decalage),
        img.split()[3],
    )
    toile = Image.alpha_composite(toile, o.filter(ImageFilter.GaussianBlur(flou)))
    toile.paste(img, (marge, marge), img)
    return toile


def telephone(nom, largeur):
    """Une capture, rognee, aux coins arrondis et avec son ombre."""
    im = Image.open(CAPTURES / f"{nom}.png").convert("RGB")
    im = im.crop((0, HAUT, im.width, im.height - BAS))
    h = round(im.height * largeur / im.width)
    return ombre(
        coins_arrondis(im.resize((largeur, h), Image.LANCZOS), 27), 15, 11, 150
    )


def planche(noms, legendes, couleurs, largeur, ecart, fichier):
    """Des telephones alignes, chacun sous sa legende."""
    marge, hauteur_legende = 42, 56
    tels = [telephone(n, largeur) for n in noms]
    ht = tels[0].height
    img = degrade(
        marge * 2 + largeur * len(tels) + ecart * (len(tels) - 1),
        marge * 2 + ht + hauteur_legende,
        (247, 244, 251),
        (234, 228, 246),
    )
    d = ImageDraw.Draw(img)
    pol = police("segoeuib.ttf", 26)
    for k, (tel, leg, coul) in enumerate(zip(tels, legendes, couleurs)):
        gauche = marge + k * (largeur + ecart)
        img.paste(
            tel,
            (gauche - (tel.width - largeur) // 2, marge - (tel.height - ht) // 2),
            tel,
        )
        d.text(
            (gauche + largeur // 2, marge + ht + 15),
            leg,
            font=pol,
            fill=coul,
            anchor="ma",
        )
    img.save(SORTIE / fichier)


def banniere():
    img = degrade(1280, 440, VIOLET, VIOLET_FONCE)
    img = halo(img, (980, 90), 420, (150, 90, 230), 0.55)
    img = halo(img, (120, 420), 360, (190, 70, 150), 0.30)
    d = ImageDraw.Draw(img)

    lg = logo(150)
    img.paste(lg, (118, 108), lg)
    d.text((300, 120), "Vyta", font=police("segoeuib.ttf", 112), fill=BLANC)
    d.text(
        (306, 258),
        "Ton coach nutrition et sport, dans ta poche.",
        font=police("segoeui.ttf", 34),
        fill=(228, 215, 250),
    )
    d.text(
        (306, 310),
        "Photographie ton assiette. Suis ta séance. Avance.",
        font=police("segoeui.ttf", 27),
        fill=(196, 176, 230),
    )

    # Les trois anneaux du tableau de bord, en filigrane, debordant a droite.
    an = Image.new("RGBA", (300, 300), (0, 0, 0, 0))
    da = ImageDraw.Draw(an)
    for i, (coul, part) in enumerate(
        ((BLANC, 0.78), (ROSE, 0.62), ((176, 142, 255), 0.45))
    ):
        ep = 19
        r = 140 - i * ep * 1.5
        boite = [150 - r, 150 - r, 150 + r, 150 + r]
        da.arc(boite, 0, 360, fill=coul + (40,), width=ep)
        da.arc(boite, -90, -90 + 360 * part, fill=coul + (165,), width=ep)
    img.paste(an, (1045, 70), an)
    img.save(SORTIE / "banniere.png")


SORTIE.mkdir(parents=True, exist_ok=True)
banniere()
planche(
    ["accueil", "seance", "idees", "semaine"],
    ["Ton tableau de bord", "Séance guidée", "Idées de repas", "Repas de la semaine"],
    [(70, 50, 110)] * 4,
    268,
    36,
    "ecrans.png",
)
planche(
    ["accueil", "accueil_aurore"],
    ["Forêt", "Aurore"],
    [(15, 110, 86), VIOLET],
    300,
    60,
    "themes.png",
)
print("visuels écrits dans", SORTIE)
