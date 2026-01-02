#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Module API - Appels a l'API Brickset.
"""

import json
import requests
from config import CLE_API, URL_API, PAGE_SIZE


def appeler_api(methode: str, params: dict = None) -> dict | None:
    """Effectue un appel POST a l'API Brickset.
    Args:
        methode (str): Le nom de la méthode à appeler sur l'API.
        params (dict, optional): Les paramètres spécifiques à la méthode (ex: {'theme': 'Star Wars'}).

    Returns:
        dict | None: Les données JSON reçues de l'API ou None en cas d'erreur.
    """
    url = f"{URL_API}/{methode}"
    donnees = {
        "apiKey": CLE_API,
        # 'userHash' n'est pas utilisé ici mais est souvent requis
        "userHash": "8IZUm3YdJz",
        "params": json.dumps(params) if params else "{}"
    }
    try:
        r = requests.post(url, data=donnees, timeout=30)
        # Lève une exception si le statut HTTP est 4xx ou 5xx
        r.raise_for_status()
        resultat = r.json()
        if resultat.get("status") == "error":
            print(f"[ERREUR] {resultat.get('message')}")
            return None
        return resultat
    except requests.RequestException as e:
        print(f"[ERREUR] {e}")
        return None


def obtenir_sets_theme(theme: str, annee: str = "") -> list:
    """Recupere les sets d'un theme.
    Args:
        theme (str): Nom du thème à chercher.
        annee (str, optional): Année de sortie (si spécifiée).

    Returns:
        list: Une liste de dictionnaires représentant les sets.
    """
    params = {"pageSize": PAGE_SIZE, "theme": theme}
    if annee:
        params["year"] = annee
    print(f"Chargement des sets {theme}...")
    r = appeler_api("getSets", params)
    return r.get("sets", []) if r else []


def obtenir_detail_set(numero: str) -> dict | None:
    """Recupere les details d'un set par son numero.
    Args:
        numero (str): Numéro du set.

    Returns:
        dict | None: Le dictionnaire contenant tous les détails du set.
    """
    if "-" not in numero:
        numero = f"{numero}-1"
    params = {"setNumber": numero, "extendedData": 1}
    print(f"Chargement du set {numero}...")
    r = appeler_api("getSets", params)
    sets = r.get("sets", []) if r else []
    return sets[0] if sets else None # On renvoie le premier (et seul) set trouvé
