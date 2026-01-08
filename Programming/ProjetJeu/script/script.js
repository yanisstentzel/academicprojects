const canvas = document.getElementById('gameCanvas');
const ctx = canvas.getContext('2d');
const particlesCanvas = document.getElementById('particles');
const particlesCtx = particlesCanvas.getContext('2d');

canvas.width = 900;
canvas.height = 700;
particlesCanvas.width = window.innerWidth;
particlesCanvas.height = window.innerHeight;

// Particules de fond
const bgParticles = [];
for (let i = 0; i < 100; i++) {
    bgParticles.push({
        x: Math.random() * particlesCanvas.width,
        y: Math.random() * particlesCanvas.height,
        vx: (Math.random() - 0.5) * 0.5,
        vy: (Math.random() - 0.5) * 0.5,
        size: Math.random() * 2 + 1
    });
}

function animateBackground() {
    particlesCtx.fillStyle = 'rgba(0, 0, 0, 0.05)';
    particlesCtx.fillRect(0, 0, particlesCanvas.width, particlesCanvas.height);

    bgParticles.forEach(p => {
        p.x += p.vx;
        p.y += p.vy;

        if (p.x < 0 || p.x > particlesCanvas.width) p.vx *= -1;
        if (p.y < 0 || p.y > particlesCanvas.height) p.vy *= -1;

        particlesCtx.fillStyle = `rgba(138, 43, 226, ${Math.random() * 0.5 + 0.3})`;
        particlesCtx.beginPath();
        particlesCtx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
        particlesCtx.fill();
    });

    requestAnimationFrame(animateBackground);
}
animateBackground();

// Variables du jeu
let score = 0;
let level = 1;
let lives = 3;
let gameStarted = false;
let ballLaunched = false;

const paddle = {
    x: canvas.width / 2 - 75,
    y: canvas.height - 40,
    width: 150,
    height: 20,
    speed: 8
};

const ball = {
    x: canvas.width / 2,
    y: paddle.y - 15,
    radius: 10,
    dx: 0,
    dy: 0,
    speed: 6,
    trail: []
};

const bricks = [];
const particles = [];
const powerups = [];

const colors = [
    { gradient: ['#ff1493', '#ff6b9d'], points: 70 },
    { gradient: ['#8a2be2', '#b968f5'], points: 60 },
    { gradient: ['#00d4ff', '#64e2ff'], points: 50 },
    { gradient: ['#ffd700', '#ffe44d'], points: 40 },
    { gradient: ['#00ff88', '#64ffaa'], points: 30 }
];

function createBricks() {
    bricks.length = 0;
    const rows = 5 + level;
    const cols = 10;
    const brickWidth = (canvas.width - 40) / cols;
    const brickHeight = 25;

    for (let row = 0; row < rows; row++) {
        for (let col = 0; col < cols; col++) {
            const colorIndex = Math.min(row, colors.length - 1);
            bricks.push({
                x: col * brickWidth + 20,
                y: row * brickHeight + 80,
                width: brickWidth - 4,
                height: brickHeight - 4,
                color: colors[colorIndex],
                visible: true,
                hits: Math.floor(level / 3) + 1,
                maxHits: Math.floor(level / 3) + 1,
                scale: 0,
                targetScale: 1
            });
        }
    }
}

function drawPaddle() {
    const gradient = ctx.createLinearGradient(paddle.x, 0, paddle.x + paddle.width, 0);
    gradient.addColorStop(0, '#00d4ff');
    gradient.addColorStop(0.5, '#8a2be2');
    gradient.addColorStop(1, '#ff1493');

    ctx.shadowBlur = 20;
    ctx.shadowColor = '#8a2be2';
    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.roundRect(paddle.x, paddle.y, paddle.width, paddle.height, 10);
    ctx.fill();
    ctx.shadowBlur = 0;
}

function drawBall() {
    // Traînée
    ball.trail.forEach((pos, i) => {
        const alpha = (i / ball.trail.length) * 0.5;
        const gradient = ctx.createRadialGradient(pos.x, pos.y, 0, pos.x, pos.y, ball.radius);
        gradient.addColorStop(0, `rgba(138, 43, 226, ${alpha})`);
        gradient.addColorStop(1, `rgba(138, 43, 226, 0)`);
        ctx.fillStyle = gradient;
        ctx.beginPath();
        ctx.arc(pos.x, pos.y, ball.radius, 0, Math.PI * 2);
        ctx.fill();
    });

    // Balle principale
    const gradient = ctx.createRadialGradient(ball.x - 3, ball.y - 3, 0, ball.x, ball.y, ball.radius);
    gradient.addColorStop(0, '#ffffff');
    gradient.addColorStop(0.3, '#00d4ff');
    gradient.addColorStop(1, '#8a2be2');

    ctx.shadowBlur = 30;
    ctx.shadowColor = '#00d4ff';
    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.arc(ball.x, ball.y, ball.radius, 0, Math.PI * 2);
    ctx.fill();
    ctx.shadowBlur = 0;
}

function drawBricks() {
    bricks.forEach(brick => {
        if (!brick.visible) return;

        brick.scale += (brick.targetScale - brick.scale) * 0.1;

        ctx.save();
        ctx.translate(brick.x + brick.width / 2, brick.y + brick.height / 2);
        ctx.scale(brick.scale, brick.scale);
        ctx.translate(-(brick.x + brick.width / 2), -(brick.y + brick.height / 2));

        const gradient = ctx.createLinearGradient(
            brick.x, brick.y,
            brick.x + brick.width, brick.y + brick.height
        );
        gradient.addColorStop(0, brick.color.gradient[0]);
        gradient.addColorStop(1, brick.color.gradient[1]);

        const alpha = brick.hits / brick.maxHits;
        ctx.globalAlpha = 0.3 + (alpha * 0.7);

        ctx.shadowBlur = 15;
        ctx.shadowColor = brick.color.gradient[0];
        ctx.fillStyle = gradient;
        ctx.beginPath();
        ctx.roundRect(brick.x, brick.y, brick.width, brick.height, 5);
        ctx.fill();

        // Bordure brillante
        ctx.strokeStyle = `rgba(255, 255, 255, ${alpha * 0.5})`;
        ctx.lineWidth = 2;
        ctx.stroke();

        ctx.globalAlpha = 1;
        ctx.shadowBlur = 0;
        ctx.restore();
    });
}

function createParticles(x, y, color) {
    for (let i = 0; i < 20; i++) {
        particles.push({
            x,
            y,
            vx: (Math.random() - 0.5) * 8,
            vy: (Math.random() - 0.5) * 8,
            life: 1,
            color,
            size: Math.random() * 4 + 2
        });
    }
}

function updateParticles() {
    for (let i = particles.length - 1; i >= 0; i--) {
        const p = particles[i];
        p.x += p.vx;
        p.y += p.vy;
        p.vy += 0.2;
        p.life -= 0.02;

        if (p.life <= 0) {
            particles.splice(i, 1);
            continue;
        }

        const radius = Math.max(0.1, p.size * p.life);
        ctx.fillStyle = `rgba(${hexToRgb(p.color)}, ${p.life})`;
        ctx.beginPath();
        ctx.arc(p.x, p.y, radius, 0, Math.PI * 2);
        ctx.fill();
    }
}

function hexToRgb(hex) {
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    return result ? 
        `${parseInt(result[1], 16)}, ${parseInt(result[2], 16)}, ${parseInt(result[3], 16)}` : 
        '255, 255, 255';
}

function collisionDetection() {
    bricks.forEach(brick => {
        if (!brick.visible) return;

        if (ball.x + ball.radius > brick.x &&
            ball.x - ball.radius < brick.x + brick.width &&
            ball.y + ball.radius > brick.y &&
            ball.y - ball.radius < brick.y + brick.height) {

            ball.dy *= -1;
            brick.hits--;

            createParticles(ball.x, ball.y, brick.color.gradient[0]);

            if (brick.hits <= 0) {
                brick.visible = false;
                score += brick.color.points * level;
                document.getElementById('score').textContent = score;

                // Vérifier victoire
                if (bricks.every(b => !b.visible)) {
                    level++;
                    document.getElementById('level').textContent = level;
                    ball.speed += 0.5;
                    resetBall();
                    createBricks();
                }
            }
        }
    });
}

function resetBall() {
    ball.x = canvas.width / 2;
    ball.y = paddle.y - 15;
    ball.dx = 0;
    ball.dy = 0;
    ballLaunched = false;
    ball.trail = [];
}

function update() {
    if (!gameStarted) return;

    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // Mouvement de la balle
    if (ballLaunched) {
        ball.x += ball.dx;
        ball.y += ball.dy;

        // Traînée
        ball.trail.push({ x: ball.x, y: ball.y });
        if (ball.trail.length > 10) ball.trail.shift();

        // Collisions murs
        if (ball.x + ball.radius > canvas.width || ball.x - ball.radius < 0) {
            ball.dx *= -1;
            createParticles(ball.x, ball.y, '#00d4ff');
        }
        if (ball.y - ball.radius < 0) {
            ball.dy *= -1;
            createParticles(ball.x, ball.y, '#00d4ff');
        }

        // Collision paddle
        if (ball.y + ball.radius > paddle.y &&
            ball.x > paddle.x &&
            ball.x < paddle.x + paddle.width) {
            
            const hitPos = (ball.x - paddle.x) / paddle.width;
            const angle = (hitPos - 0.5) * Math.PI / 3;
            ball.dx = ball.speed * Math.sin(angle);
            ball.dy = -ball.speed * Math.cos(angle);
            createParticles(ball.x, ball.y, '#8a2be2');
        }

        // Balle perdue
        if (ball.y + ball.radius > canvas.height) {
            lives--;
            document.getElementById('lives').textContent = lives;
            if (lives > 0) {
                resetBall();
            } else {
                gameOver();
            }
        }

        collisionDetection();
    } else {
        ball.x = paddle.x + paddle.width / 2;
        ball.y = paddle.y - 15;
    }

    drawBricks();
    updateParticles();
    drawPaddle();
    drawBall();

    requestAnimationFrame(update);
}

function gameOver() {
    gameStarted = false;
    document.getElementById('finalScore').textContent = score;
    document.getElementById('endTitle').textContent = level > 5 ? 'INCROYABLE!' : 'GAME OVER';
    document.getElementById('gameOverScreen').classList.remove('hidden');
}

function startGame() {
    score = 0;
    level = 1;
    lives = 3;
    ball.speed = 6;
    document.getElementById('score').textContent = score;
    document.getElementById('level').textContent = level;
    document.getElementById('lives').textContent = lives;
    
    createBricks();
    setTimeout(() => {
        bricks.forEach((brick, i) => {
            setTimeout(() => brick.targetScale = 1, i * 5);
        });
    }, 100);
    
    resetBall();
    gameStarted = true;
    document.getElementById('startScreen').classList.add('hidden');
    document.getElementById('gameOverScreen').classList.add('hidden');
    update();
}

// Contrôles
canvas.addEventListener('mousemove', (e) => {
    const rect = canvas.getBoundingClientRect();
    paddle.x = e.clientX - rect.left - paddle.width / 2;
    paddle.x = Math.max(0, Math.min(canvas.width - paddle.width, paddle.x));
});

document.addEventListener('keydown', (e) => {
    if (e.code === 'Space' && gameStarted && !ballLaunched) {
        ballLaunched = true;
        const angle = (Math.random() - 0.5) * Math.PI / 4;
        ball.dx = ball.speed * Math.sin(angle);
        ball.dy = -ball.speed * Math.cos(angle);
    }
});

document.getElementById('startBtn').addEventListener('click', startGame);
document.getElementById('restartBtn').addEventListener('click', startGame);

createBricks();