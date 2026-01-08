# Projet Casse-Briques - R3.01 Technologies Web

Ce projet est le rendu final de mon application de jeu "Casse-Briques" développée dans le cadre du module **R3 - Technologies Web**. 

L'objectif était de concevoir un jeu fonctionnel, fluide et simple d'utilisation en utilisant les technologies standards du Web.

## Étudiant
* **Nom :** STENTZEL
* **Prénom :** Yanis
* **Groupe :** VCOD2
* **Année :** 2025-2026

##  Présentation du Jeu
Le projet est un casse-briques classique revisité avec un design épuré. Le but est de détruire toutes les briques présentes à l'écran à l'aide d'une balle et d'une raquette contrôlée à la souris.

### Fonctionnalités incluses :
* **Contrôle à la souris :** La raquette suit les mouvements horizontaux du curseur.
* **Gestion du score :** Chaque brique détruite rapporte des points.
* **Système de record (High Score) :** Le meilleur score est sauvegardé localement sur le navigateur du joueur (via *localStorage*).
* **Mort subite :** Si la balle touche le bas de l'écran, la partie se termine.
* **Interface intuitive :** Un menu d'accueil simple permet de lancer la partie.

## Structure du projet
```text
ProjetJeu/
├── index.html        # Page principale du jeu
├── script/
│   └── script.js     # Logique et moteur de jeu
└── styles/
    └── style.css     # Design et mise en page