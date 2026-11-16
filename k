
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="theme-color" content="#101827">
<title>GB Visual Lab</title>

<style>
:root {
  color-scheme: dark;
  --bg: #101827;
  --panel: #1b2638;
  --line: #334155;
  --text: #edf2f7;
  --muted: #9fb0c5;
  --accent: #65d6ad;
}

* { box-sizing: border-box; }

body {
  margin: 0;
  background: var(--bg);
  color: var(--text);
  font: 15px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}

main {
  max-width: 760px;
  margin: auto;
  padding: 16px 14px 30px;
}

h1 { font-size: 23px; margin: 6px 0 4px; }

p {
  color: var(--muted);
  line-height: 1.45;
  margin: 6px 0 12px;
}

.panel {
  background: var(--panel);
  border: 1px solid var(--line);
  border-radius: 16px;
  padding: 13px;
  margin: 12px 0;
}

.stage {
  position: relative;
  overflow: hidden;
  background: #05080d;
  border-radius: 12px;
  aspect-ratio: 4/3;
  margin-top: 10px;
}

video, canvas {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: contain;
}

canvas { touch-action: manipulation; }

button {
  border: 0;
  border-radius: 11px;
  padding: 12px 14px;
  background: #2c3b52;
  color: white;
  font-weight: 650;
}

button.primary {
  background: var(--accent);
  color: #082019;
}

button:disabled { opacity: .45; }

.row {
  display: flex;
  gap: 9px;
  flex-wrap: wrap;
  margin-top: 10px;
}

.hint {
  color: var(--muted);
  font-size: 12px;
  line-height: 1.4;
}

label {
  display: block;
  color: var(--muted);
  font-size: 13px;
  margin: 13px 0 5px;
}

input[type=range] {
  width: 100%;
  accent-color: var(--accent);
}

.value { float: right; color: var(--text); }

.status {
  font-size: 13px;
  color: #f5c76a;
  min-height: 18px;
  margin-top: 8px;
}

.stats {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 8px;
}

.stat {
  background: #111c2b;
  border-radius: 10px;
  padding: 10px;
}

.stat b { display: block; font-size: 17px; }
.stat span { color: var(--muted); font-size: 11px; }
</style>
</head>

<body>
<main>

<h1>GB Visual Lab</h1>
<p>Laboratorio visual experimental para GunBound clásico · cámara, puntos de referencia y trayectoria orientativa.</p>

<section class="panel">
<b>1. Vista de cámara</b>

<div class="stage">
<video id="video" autoplay playsinline muted></video>
<canvas id="canvas"></canvas>
</div>

<div class="row">
<button class="primary" id="start">Activar cámara</button>
<button id="flip" disabled>Cambiar cámara</button>
<button id="reset">Reiniciar puntos</button>
</div>

<div class="status" id="status">
Activa la cámara y toca la imagen: primero tu móvil y después el objetivo.
</div>

<p class="hint">
La cámara requiere permiso de Safari. La imagen se procesa localmente y no se envía a un servidor.
</p>
</section>

<section class="panel">
<b>2. Referencias</b>

<p>
Primer toque: posición de tu móvil.
Segundo toque: centro del enemigo.
Toca de nuevo para mover el punto más cercano.
</p>

<div class="stats">
<div class="stat">
<b id="origin">—</b>
<span>Tu móvil (%)</span>
</div>

<div class="stat">
<b id="target">—</b>
<span>Objetivo (%)</span>
</div>

<div class="stat">
<b id="distance">—</b>
<span>Distancia visual</span>
</div>
</div>
</section>

<section class="panel">
<b>3. Parámetros</b>

<label>Ángulo <span class="value" id="av">45°</span></label>
<input id="angle" type="range" min="5" max="85" value="45">

<label>Potencia <span class="value" id="pv">70%</span></label>
<input id="power" type="range" min="10" max="100" value="70">

<label>Viento horizontal <span class="value" id="wv">0</span></label>
<input id="wind" type="range" min="-10" max="10" value="0">

<p class="hint">
Modelo visual experimental: no representa todavía la física exacta de cada móvil o mapa.
</p>
</section>

<section class="panel">
<b>4. Simulación</b>

<p id="result">
Marca tu móvil y el objetivo para dibujar una trayectoria orientativa.
</p>

<div class="row">
<button class="primary" id="solve">Estimar ángulo</button>
<button id="clear">Ocultar trayectoria</button>
</div>

<p class="hint">
Esta herramienta no lee memoria, no controla el juego ni ejecuta disparos.
</p>
</section>

</main>

<script>
(() => {
const $ = id => document.getElementById(id);
const video = $('video');
const canvas = $('canvas');
const ctx = canvas.getContext('2d');

let stream = null;
let facing = 'environment';
let origin = null;
let target = null;
let show = true;

function resize() {
  const r = canvas.getBoundingClientRect();
  const d = Math.min(devicePixelRatio || 1, 2);

  canvas.width = r.width * d;
  canvas.height = r.height * d;

  ctx.setTransform(d, 0, 0, d, 0, 0);
  draw();
}

function point(p, color, label, w, h) {
  if (!p) return;

  ctx.beginPath();
  ctx.arc(p.x * w, p.y * h, 8, 0, 7);
  ctx.fillStyle = color;
  ctx.fill();

  ctx.lineWidth = 2;
  ctx.strokeStyle = '#07111c';
  ctx.stroke();

  ctx.font = 'bold 12px sans-serif';
  ctx.fillStyle = color;
  ctx.fillText(label, p.x * w + 11, p.y * h - 10);
}

function draw() {
  const r = canvas.getBoundingClientRect();
  const w = r.width;
  const h = r.height;

  ctx.clearRect(0, 0, w, h);

  point(origin, '#65d6ad', 'M', w, h);
  point(target, '#ff7777', 'OBJ', w, h);

  if (origin && target && show) {
    const dx = target.x - origin.x;
    const angle = Number($('angle').value) * Math.PI / 180;
    const power = Number($('power').value) / 100;
    const wind = Number($('wind').value);

    let xx = origin.x * w;
    let yy = origin.y * h;

    let vx = Math.cos(angle) * (.35 + power * .7) * (dx < 0 ? -1 : 1);
    let vy = -Math.sin(angle) * (.35 + power * .7);

    ctx.beginPath();
    ctx.moveTo(xx, yy);

    for (let i = 0; i < 180; i++) {
      vx += wind * .00004;
      vy += .009;

      xx += vx * w * .018;
      yy += vy * h * .018;

      ctx.lineTo(xx, yy);

      if (xx < 0 || xx > w || yy < 0 || yy > h) break;
    }

    ctx.strokeStyle = '#65d6ad';
    ctx.lineWidth = 2.5;
    ctx.setLineDash([5, 4]);
    ctx.stroke();
    ctx.setLineDash([]);
  }
}

function updateStats() {
  $('origin').textContent = origin
    ? Math.round(origin.x * 100) + ', ' + Math.round(origin.y * 100)
    : '—';

  $('target').textContent = target
    ? Math.round(target.x * 100) + ', ' + Math.round(target.y * 100)
    : '—';

  $('distance').textContent = origin && target
    ? Math.round(Math.hypot(target.x - origin.x, target.y - origin.y) * 100) + '%'
    : '—';
}

canvas.addEventListener('pointerdown', e => {
  const r = canvas.getBoundingClientRect();

  const p = {
    x: (e.clientX - r.left) / r.width,
    y: (e.clientY - r.top) / r.height
  };

  if (!origin) {
    origin = p;
    $('status').textContent = 'Móvil marcado. Ahora toca el objetivo.';
  } else if (!target) {
    target = p;
    $('status').textContent = 'Objetivo marcado. Ajusta los parámetros.';
  } else {
    const da = Math.hypot(p.x - origin.x, p.y - origin.y);
    const db = Math.hypot(p.x - target.x, p.y - target.y);

    if (da < db) origin = p;
    else target = p;
  }

  updateStats();
  draw();
});

async function camera() {
  try {
    if (!navigator.mediaDevices?.getUserMedia) {
      throw Error('La cámara requiere HTTPS y un navegador compatible');
    }

    if (stream) stream.getTracks().forEach(t => t.stop());

    stream = await navigator.mediaDevices.getUserMedia({
      audio: false,
      video: { facingMode: { ideal: facing } }
    });

    video.srcObject = stream;
    await video.play();

    $('flip').disabled = false;
    $('status').textContent = 'Cámara activa. Marca tu móvil y el objetivo.';

  } catch (e) {
    $('status').textContent = 'No se pudo abrir la cámara: ' + e.message;
  }
}

$('start').onclick = camera;

$('flip').onclick = () => {
  facing = facing === 'environment' ? 'user' : 'environment';
  camera();
};

$('reset').onclick = () => {
  origin = null;
  target = null;
  updateStats();
  draw();

  $('status').textContent = 'Puntos reiniciados.';
  $('result').textContent = 'Marca tu móvil y el objetivo para dibujar una trayectoria orientativa.';
};

$('clear').onclick = () => {
  show = false;
  draw();
};

['angle', 'power', 'wind'].forEach(id => {
  $(id).oninput = () => {
    $('av').textContent = $('angle').value + '°';
    $('pv').textContent = $('power').value + '%';
    $('wv').textContent = $('wind').value;

    show = true;
    draw();
  };
});

$('solve').onclick = () => {
  if (!origin || !target) {
    $('status').textContent = 'Primero marca los dos puntos.';
    return;
  }

  const ang = Math.max(8, Math.min(82,
    Math.round(
      25 + Math.atan2(
        Math.max(0, origin.y - target.y),
        Math.max(.01, Math.abs(target.x - origin.x))
      ) * 180 / Math.PI * .55
    )
  ));

  $('angle').value = ang;
  $('av').textContent = ang + '°';

  show = true;
  draw();

  $('result').textContent =
    'Ángulo inicial orientativo: ' + ang +
    '°. La potencia debe calibrarse con pruebas reales.';
};

window.addEventListener('resize', resize);

window.addEventListener('pagehide', () => {
  if (stream) stream.getTracks().forEach(t => t.stop());
});

resize();
})();
</script>

</body>
</html>
