document.addEventListener('DOMContentLoaded', () => {

    const brickImages = [
        '../assets/images/image_fb9f52.png', // rouge
        '../assets/images/image_fb9f57.png', // bleu
        '../assets/images/image_fb9f75.png', // orange
        '../assets/images/image_fb9f90.png', // jaune
        '../assets/images/image_fb9f5b.png'  // vert
    ];

    const brickSize = 20; // Doit correspondre à la variable CSS

    // 1. D'ABORD : On structure le HTML via JS car le Python est figé
    // On cherche les éléments à encadrer (cartes de la liste OU le détail unique)
    const elementsToFrame = document.querySelectorAll('.carte, .detail');

    elementsToFrame.forEach(element => {
        // Si l'élément n'est pas déjà encadré
        if (!element.parentElement.classList.contains('brick-frame-container')) {
            // Création du wrapper
            const wrapper = document.createElement('div');
            wrapper.className = 'brick-frame-container';
            
            // Insertion du wrapper avant l'élément
            element.parentNode.insertBefore(wrapper, element);
            
            // Déplacement de l'élément DANS le wrapper
            wrapper.appendChild(element);
        }
    });

    // 2. ENSUITE : On active l'observateur pour dessiner les briques
    const observer = new ResizeObserver(entries => {
        for (let entry of entries) {
            // On redessine le cadre dès que la taille change
            drawBricks(entry.target);
        }
    });

    // On observe tous les conteneurs qu'on vient de créer
    document.querySelectorAll('.brick-frame-container').forEach(container => {
        observer.observe(container);
    });

    function drawBricks(container) {
        // Nettoyage des anciennes briques
        container.querySelectorAll('.brick-border').forEach(el => el.remove());

        // Dimensions réelles
        const width = container.offsetWidth;
        const height = container.offsetHeight;

        // Calcul mathématique précis
        const countX = Math.floor(width / brickSize);
        // On retire 2 briques en hauteur pour éviter le chevauchement avec le haut/bas
        const countY = Math.floor((height - (brickSize * 2)) / brickSize); 

        // Création des 4 côtés
        container.appendChild(createRow('top', countX));
        container.appendChild(createRow('bottom', countX));
        
        // Sécurité : au moins 1 brique si l'élément est tout petit
        container.appendChild(createColumn('left', Math.max(1, countY)));
        container.appendChild(createColumn('right', Math.max(1, countY)));
    }

    function createRow(position, count) {
        const div = document.createElement('div');
        div.className = `brick-border ${position}`;
        fillWithBricks(div, count, false);
        return div;
    }

    function createColumn(position, count) {
        const div = document.createElement('div');
        div.className = `brick-border ${position}`;
        fillWithBricks(div, count, true);
        return div;
    }

    function fillWithBricks(element, count, isVertical) {
        for (let i = 0; i < count; i++) {
            const img = document.createElement('img');
            img.src = brickImages[Math.floor(Math.random() * brickImages.length)];
            img.className = 'border-brick';
            element.appendChild(img);
        }
    }
    
    console.log("Structure LEGO injectée et cadres dynamiques activés.");
});