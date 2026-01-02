#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Module Client - Menu console.
"""

from config import LISTE_THEMES, LISTE_SETS
from api import obtenir_sets_theme, obtenir_detail_set
from generator import ouvrir_html, html_liste_sets, html_detail_set


def afficher_menu():
    """Affiche le menu principal dans la console."""
    print("\n" + "=" * 35)
    print("       BRICKSET EXPLORER")
    print("=" * 35)
    print("  1. Choisir un theme")
    print("  2. Choisir un set")
    print("  Q. Quitter")
    print("=" * 35)


def afficher_liste_themes():
    """Affiche la liste des thèmes disponibles à l'utilisateur."""
    print("\nThemes disponibles :")
    for i, theme in enumerate(LISTE_THEMES, 1):
        print(f"  {i}. {theme}")
    print("  Q. Retour")


def afficher_liste_sets():
    """Affiche la liste des sets présélectionnés disponibles."""
    print("\nSets disponibles :")
    for i, (numero, nom) in enumerate(LISTE_SETS, 1):
        print(f"  {i}. {numero} - {nom}")
    print("  Q. Retour")


def action_theme():
    """
    Gère la sélection d'un thème :
    1. Demande le choix.
    2. Récupère les sets via l'API.
    3. Génère et ouvre la page HTML (avec le suffixe '-theme').
    """
    from datetime import datetime
    annee_courante = str(datetime.now().year)
    afficher_liste_themes()
    choix = input("\nVotre choix : ").strip()
    if choix == "Q":
        return

    if choix.isdigit() and 1 <= int(choix) <= len(LISTE_THEMES):
        theme = LISTE_THEMES[int(choix) - 1]
        sets = obtenir_sets_theme(theme, annee_courante)
        if sets:
            titre = f"{theme} {annee_courante}"
            # Logique de nommage du fichier pour les thèmes : NOM_THEME-theme.html
            nom_fichier = f"{theme.replace(' ', '_')}-theme"
            ouvrir_html(nom_fichier, html_liste_sets(sets, titre))
        else:
            print("[ERREUR] Aucun set trouve")
    else:
        print("[ERREUR] Choix invalide")


def action_set():
    """
    Gère la sélection d'un set :
    1. Demande le choix.
    2. Récupère les détails via l'API (avec données étendues).
    3. Génère et ouvre la page HTML (avec le suffixe '-set').
    """
    afficher_liste_sets()
    choix = input("\nVotre choix : ").strip()
    if choix == "Q":
        return

    if choix.isdigit() and 1 <= int(choix) <= len(LISTE_SETS):
        numero, nom = LISTE_SETS[int(choix) - 1]
        detail = obtenir_detail_set(numero)
        if detail:
            nom_propre = nom.replace(" ", "_").replace(":", "").replace("'", "")
            # Logique de nommage du fichier pour les sets : NOM_SET-set.html
            nom_fichier = f"{nom_propre}-set"
            ouvrir_html(nom_fichier, html_detail_set(detail))
        else:
            print("[ERREUR] Set non trouve")
    else:
        print("[ERREUR] Choix invalide")


def lancer_menu():
    """Lance la boucle principale de l'application. Tourne tant que l'utilisateur ne quitte pas."""
    print("\nBienvenue dans Brickset Explorer")
    while True:
        afficher_menu()
        choix = input("Votre choix : ").strip()
        match choix:
            case "Q":
                print("\nA bientot")
                break
            case "1":
                action_theme()
            case "2":
                action_set()
            case _: print("[ERREUR] Choix invalide")
