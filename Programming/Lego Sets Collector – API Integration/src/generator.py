#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Module Generator - Generation des pages HTML
"""

import webbrowser
import urllib.request
from datetime import datetime
from config import DOSSIER_DATA, DOSSIER_TEMPLATE


def initialiser():
    """
    Cree le dossier DATA s'il n'existe pas.
    """
    DOSSIER_DATA.mkdir(exist_ok=True)


def charger_template() -> str:
    """
    Lit le squelette HTML (base.html) qui contient les zones à remplacer {...}.
    """"
    chemin = DOSSIER_TEMPLATE / "base.html"
    with open(chemin, "r", encoding="utf-8") as f:
        return f.read()


def generer_page(titre: str, sous_titre: str, contenu: str) -> str:
    """
    Genere une page HTML complete.

    Args:
        titre (str): Le titre principal.
        sous_titre (str): Le sous-titre.
        contenu (str): Le code HTML généré pour les cartes ou le détail.

    Returns:
        str: Le code HTML complet de la page.
    """
    template = charger_template()
    date = datetime.now().strftime('%d/%m/%Y %H:%M')
    # Remplacement simple des balises {{...}} par les vraies données
    html = template.replace("{{TITRE}}", titre)
    html = html.replace("{{SOUS_TITRE}}", sous_titre)
    html = html.replace("{{CONTENU}}", contenu)
    html = html.replace("{{DATE}}", date)
    return html


def ouvrir_html(nom: str, html: str):
    """
    Sauvegarde et ouvre le fichier HTML.

    Args:
        nom (str): Le nom du fichier HTML à créer (sans l'extension .html)
        html (str): Le contenu HTML complet à écrire.
    """
    initialiser()
    chemin = DOSSIER_DATA / f"{nom}.html"
    with open(chemin, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"[OK] {chemin}")
    # Encodage de l'URL pour gérer les espaces et caractères spéciaux (Mac/Windows).
    url = "file://" + urllib.request.pathname2url(str(chemin.absolute()))
    webbrowser.open(url) # Ouvre le navigateur par défaut


def html_liste_sets(sets: list, titre: str) -> str:
    """
    Genere la page HTML pour une liste de sets.

    Args:
        sets (list): Liste des dictionnaires de sets.
        titre (str): Le titre de la page.

    Returns:
        str: Le HTML de la page complète.
    """
    cartes = ""
    for s in sets:
        # Logique pour construire chaque carte dans la grille
        img = s.get("image", {}).get("thumbnailURL", "")
        img_html = f'<img src="{img}" alt="">' if img else ""
        pieces = s.get("pieces")
        pieces_html = f'<span class="badge badge-bleu">{pieces} pcs</span>' if pieces else ""
        # injection de données dans la structure html
        cartes += f"""
        <div class="carte">
            {img_html}
            <p class="numero-set">{s.get('number', '')}-{s.get('numberVariant', 1)}</p>
            <h2>{s.get('name', 'Sans nom')}</h2>
            <span class="badge">{s.get('year', '?')}</span>
            {pieces_html}
            <p style="margin-top: 20px;">
            <a href="{s.get('bricksetURL', '#')}" target="_blank">Voir sur Brickset</a>
            </p>
        </div>"""

    contenu = f'<div class="grille">{cartes}</div>'
    return generer_page(titre, f"{len(sets)} sets", contenu)


def html_detail_set(s: dict) -> str:
    """
    Construit le HTML pour afficher la fiche détaillée d'un set unique

    Args:
        s (dict): Le dictionnaire détaillé du set

    Returns:
        str: Le HTML de la page complète.
    """
    # Logique pour extraire les données complexes (description, note, images)
    img = s.get("image", {}).get("imageURL", "")
    img_html = f'<img src="{img}" alt="">' if img else ""

    desc = s.get("extendedData", {}).get("description", "")
    desc_html = f'<div class="description">{desc}</div>' if desc else ""

    note = int(s.get('rating') or 0)
    etoiles = '*' * note + '-' * (5 - note)

    numero = f"{s.get('number', '')}-{s.get('numberVariant', 1)}"

    contenu = f"""
    <div class="detail">
        {img_html}
        <div class="grille-infos">
            <div class="info-item">
                <label>Theme</label>
                <span>{s.get('theme', 'N/A')}</span>
            </div>
            <div class="info-item">
                <label>Sous-theme</label>
                <span>{s.get('subtheme', 'N/A')}</span>
            </div>
            <div class="info-item">
                <label>Annee</label>
                <span>{s.get('year', 'N/A')}</span>
            </div>
            <div class="info-item">
                <label>Pieces</label>
                <span>{s.get('pieces', 'N/A')}</span>
            </div>
            <div class="info-item">
                <label>Minifigs</label>
                <span>{s.get('minifigs', 0)}</span>
            </div>
            <div class="info-item">
                <label>Note</label>
                <span>{etoiles} ({s.get('rating', 'N/A')})</span>
            </div>
        </div>
        {desc_html}
        <p style="margin-top: 20px;">
            <a href="{s.get('bricksetURL', '#')}" target="_blank">Voir sur Brickset</a>
        </p>
    </div>"""

    return generer_page(s.get('name', 'Set'), numero, contenu)
