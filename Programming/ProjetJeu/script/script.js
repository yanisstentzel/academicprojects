document.addEventListener("DOMContentLoaded", () => {
    const canvas = document.getElementById("gameCanvas");
    const ctx = canvas.getContext("2d");
    const scoreSpan = document.getElementById("score");
    const highScoreSpan = document.getElementById("high-score"); 
    const startScreen = document.getElementById("start-screen");
    const startBtn = document.getElementById("start-btn");

    // --- VARIABLES ---
    let x = canvas.width / 2;
    let y = canvas.height - 30;
    let dx = 4;
    let dy = -4;
    let paddleX = (canvas.width - 100) / 2;
    let score = 0;
    let enJeu = false;

    // Récupérer le meilleur score sauvegardé au chargement (ou 0 si rien n'existe)
    let highScore = localStorage.getItem("meilleurScore") || 0;
    highScoreSpan.innerText = highScore;

    const bricks = [];
    for (let c = 0; c < 8; c++) {
        bricks[c] = [];
        for (let r = 0; r < 4; r++) {
            bricks[c][r] = { x: 0, y: 0, status: 1 };
        }
    }

    // --- CONTRÔLES ---
    document.addEventListener("mousemove", (e) => {
        const relativeX = e.clientX - canvas.offsetLeft;
        if (relativeX > 0 && relativeX < canvas.width) {
            paddleX = relativeX - 50;
        }
    });

    startBtn.addEventListener("click", () => {
        startScreen.style.display = "none";
        enJeu = true;
        draw();
    });

    // Fonction pour gérer la fin de partie et le record
    function finDePartie(message) {
        enJeu = false;
        
        // On vérifie si le score actuel bat le record
        if (score > highScore) {
            highScore = score;
            localStorage.setItem("meilleurScore", highScore); // On sauvegarde
            alert("NOUVEAU RECORD ! " + message);
        } else {
            alert(message);
        }
        
        document.location.reload();
    }

    // --- MOTEUR DU JEU ---
    function draw() {
        if (!enJeu) return;

        ctx.clearRect(0, 0, canvas.width, canvas.height);

        // Dessin Raquette
        ctx.beginPath();
        ctx.rect(paddleX, canvas.height - 15, 100, 15);
        ctx.fillStyle = "#34495e";
        ctx.fill();
        ctx.closePath();

        // Dessin Balle
        ctx.beginPath();
        ctx.arc(x, y, 10, 0, Math.PI * 2);
        ctx.fillStyle = "#e74c3c";
        ctx.fill();
        ctx.closePath();

        // Briques et Collisions
        for (let c = 0; c < 8; c++) {
            for (let r = 0; r < 4; r++) {
                const b = bricks[c][r];
                if (b.status === 1) {
                    let brickX = (c * (85 + 10)) + 35;
                    let brickY = (r * (20 + 10)) + 40;
                    b.x = brickX; b.y = brickY;

                    ctx.beginPath();
                    ctx.rect(brickX, brickY, 85, 20);
                    ctx.fillStyle = "#4a90e2";
                    ctx.fill();
                    ctx.closePath();

                    if (x > b.x && x < b.x + 85 && y > b.y && y < b.y + 20) {
                        dy = -dy;
                        b.status = 0;
                        score++;
                        scoreSpan.innerText = score;
                        
                        if (score === 32) {
                            finDePartie("Tu as gagné !");
                        }
                    }
                }
            }
        }

        // Rebonds Murs
        if (x + dx > canvas.width - 10 || x + dx < 10) dx = -dx;
        if (y + dy < 10) {
            dy = -dy;
        } else if (y + dy > canvas.height - 10) {
            if (x > paddleX && x < paddleX + 100) {
                dy = -dy;
            } else {
                finDePartie("Perdu... Score : " + score);
            }
        }

        x += dx;
        y += dy;
        requestAnimationFrame(draw);
    }
});