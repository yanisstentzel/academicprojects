#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Configuration de l'application Brickset Explorer.
"""

import os
from pathlib import Path
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
chemin_env = BASE_DIR / ".env"
# Lit le fichier .env et place les variables dans l'environnement système
load_dotenv(chemin_env)

# Définition des dossiers principaux du projet pour que les autres modules
# (generator par exemple) sachent où écrire et où lire.
DOSSIER_DATA = BASE_DIR / "DATA"
DOSSIER_ASSETS = BASE_DIR / "assets"
DOSSIER_TEMPLATE = DOSSIER_ASSETS / "templates"

# Récupère la clé API de l'environnement (chargé juste avant par load_dotenv)
CLE_API = os.getenv("BRICKSET_API_KEY")

if not CLE_API:
    print("[ATTENTION] Clé API non trouvée dans .env")
    CLE_API = ""

URL_API = "https://brickset.com/api/v3.asmx"
PAGE_SIZE = 60

LISTE_THEMES = [
    "Friends", "Star Wars", "Minecraft", "Marvel Super Heroes",
    "City", "Ideas", "Icons", "Ninjago", "Jurassic World", "Disney"
]

LISTE_SETS = [
    ("70010", "The Lion CHI Temple"),
    ("10179", "Ultimate Collector's Millennium Falcon"),
    ("8487", "Flo's V8 Cafe"),
    ("75367", "Venator-class Republic Attack Cruiser"),
    ("9493", "X-wing Starfighter"),
    ("71395", "Super Mario 64 Question Mark Block"),
    ("77092", "Great Deku Tree 2-in-1"),
    ("10333", "The Lord of the Rings: Barad-dur"),
    ("21024", "Louvre"),
    ("42172", "McLaren P1")
]
