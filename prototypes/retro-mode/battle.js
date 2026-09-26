/* A tiny, dependency-free battle stage. All battle outcomes are scripted for this demo. */
(() => {
  'use strict';

  const W = 480;
  const H = 280;
  const FLOOR = 226;
  const LENGTH = 9700;
  const FRAMES = {
    lion: [[31, 123, 271, 265], [332, 161, 278, 227], [642, 141, 343, 246], [1000, 121, 223, 284]],
    gorilla: [[20, 499, 279, 294], [321, 545, 298, 248], [633, 525, 378, 264], [1016, 510, 217, 279]],
    mossback: [[20, 907, 293, 249], [332, 921, 301, 234], [636, 934, 322, 231], [964, 890, 277, 275]],
  };
  const CREATURES = {
    lion: { name: 'Lion', row: 0, color: '#d99641', power: 2 },
    gorilla: { name: 'Gorilla', row: 1, color: '#777a71', power: 1 },
    mossback: { name: 'Mossback', row: 2, color: '#82a74d', power: 3 },
  };
  const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
  const ease = (v) => { const t = clamp(v); return t * t * (3 - 2 * t); };
  const noise = (n) => { const v = Math.sin(n * 127.1 + 311.7) * 43758.5453; return v - Math.floor(v); };

  class RetroBattle {
    constructor(canvas, { onEvent, onFinish } = {}) {
      if (!canvas || !canvas.getContext) throw new Error('RetroBattle needs a canvas element.');
      this.canvas = canvas;
      this.ctx = canvas.getContext('2d');
      canvas.width = W;
      canvas.height = H;
      this.ctx.imageSmoothingEnabled = false;
      this.onEvent = typeof onEvent === 'function' ? onEvent : () => {};
      this.onFinish = typeof onFinish === 'function' ? onFinish : () => {};
      this.fighters = ['lion', 'gorilla'];
      this.speed = 1;
      this.reducedMotion = false;
      this.sound = false;
      this.playing = false;
      this.finished = false;
      this.elapsed = 0;
      this.hp = [100, 100];
      this._nextEvent = 0;
      this._destroyed = false;
      this._makeTimeline();
      this._tick = this._tick.bind(this);
      this._render(performance.now());
      this._raf = requestAnimationFrame(this._tick);
    }

    async load(assetsUrl = 'assets/sprites.png') {
      const version = (this._loadVersion || 0) + 1;
      this._loadVersion = version;
      try {
        const atlas = await new Promise((resolve, reject) => {
          const img = new Image();
          img.onload = () => resolve(img);
          img.onerror = reject;
          img.src = assetsUrl;
        });
        if (this._loadVersion !== version || this._destroyed) return false;
        this.atlas = atlas;
        this.cellWidth = atlas.naturalWidth / 4;
        this.cellHeight = atlas.naturalHeight / 3;
        this._render(performance.now());
        if (!this.playing && !this.finished) this._emit('ready', 0, 'The clearing is quiet. Your challengers are ready.');
        return true;
      } catch (_) {
        if (this._loadVersion === version && !this._destroyed) {
          this._emit('ready', 0, 'Your challengers are ready.');
        }
        return false;
      }
    }

    setFighters(leftId, rightId) {
      this.fighters = [CREATURES[leftId] ? leftId : 'lion', CREATURES[rightId] ? rightId : 'gorilla'];
      this._makeTimeline();
      this.reset();
    }

    setSpeed(value) {
      const now = performance.now();
      if (this.playing) this.elapsed = Math.min(LENGTH, (now - this._startedAt) * this.speed);
      this.speed = value === 0.65 ? 0.65 : 1;
      if (this.playing) this._startedAt = now - this.elapsed / this.speed;
    }

    setReducedMotion(value) {
      this.reducedMotion = Boolean(value);
      this._render(performance.now());
    }

    setSound(value) {
      this.sound = Boolean(value);
      if (this.sound) this._audioReady();
    }

    play() {
      if (this._destroyed) return;
      this.elapsed = 0;
      this.hp = [100, 100];
      this._nextEvent = 0;
      this.finished = false;
      this.playing = true;
      this._startedAt = performance.now();
      if (this.sound) this._audioReady();
      this._dispatchEvents();
      this._render(this._startedAt);
    }

    reset() {
      this.playing = false;
      this.finished = false;
      this.elapsed = 0;
      this.hp = [100, 100];
      this._nextEvent = 0;
      this._emit('ready', 0, 'The clearing is quiet. Your challengers are ready.');
      this._render(performance.now());
    }

    destroy() {
      this._destroyed = true;
      this.playing = false;
      cancelAnimationFrame(this._raf);
      if (this._audio) this._audio.close().catch(() => {});
    }

    _makeTimeline() {
      const a = CREATURES[this.fighters[0]];
      const b = CREATURES[this.fighters[1]];
      this.winner = a.power >= b.power ? 0 : 1;
      const winnerName = CREATURES[this.fighters[this.winner]].name;
      this.exchanges = [
        { start: 720, impact: 1370, end: 1970, actor: 0, damage: 22, label: `${a.name} makes the first move.` },
        { start: 2260, impact: 2860, end: 3500, actor: 1, damage: 29, label: `${b.name} answers with a counter!` },
        { start: 3770, impact: 4350, end: 5010, actor: 0, damage: 27, label: `${a.name} finds an opening.` },
        { start: 5250, impact: 5870, end: 6530, actor: 1, damage: 25, label: `${b.name} holds its ground.` },
        { start: 6860, impact: 7630, end: 8430, actor: this.winner, damage: 100, label: `${winnerName} gathers one last burst of energy…`, final: true },
      ];
      this.events = [{ at: 0, phase: 'intro', actor: 0, text: `${a.name} and ${b.name} enter the clearing.` }];
      this.exchanges.forEach((e) => {
        this.events.push({ at: e.start, phase: 'attack', actor: e.actor, text: e.label });
        this.events.push({ at: e.impact, phase: 'impact', actor: e.actor, damage: e.damage, text: e.final ? 'A final flourish — what a finish!' : ['A clean hit! The dust flies.', 'A quick counter catches its mark.', 'Another burst of pixel power!', 'The clearing shakes with that one.'][this.exchanges.indexOf(e)] });
      });
      this.events.push({ at: LENGTH, phase: 'finish', actor: this.winner, text: `${winnerName} takes the clearing!` });
    }

    _emit(phase, actor, text) {
      this.onEvent({ phase, actor, text, leftHP: this.hp[0], rightHP: this.hp[1], progress: clamp(this.elapsed / LENGTH) });
    }

    _dispatchEvents() {
      while (this._nextEvent < this.events.length && this.events[this._nextEvent].at <= this.elapsed) {
        const event = this.events[this._nextEvent++];
        if (event.damage) {
          this.hp[1 - event.actor] = Math.max(0, this.hp[1 - event.actor] - event.damage);
          this._ping(event.damage === 100 ? 'final' : 'hit', event.actor);
        } else if (event.phase === 'attack') this._ping('step', event.actor);
        this._emit(event.phase, event.actor, event.text);
        if (event.phase === 'finish') {
          this.playing = false;
          this.finished = true;
          this.onFinish({ winner: this.winner, name: CREATURES[this.fighters[this.winner]].name });
          this._ping('win', this.winner);
        }
      }
    }

    _tick(now) {
      if (this._destroyed) return;
      if (this.playing) {
        this.elapsed = Math.min(LENGTH, Math.max(0, (now - this._startedAt) * this.speed));
        this._dispatchEvents();
      }
      this._render(now);
      this._raf = requestAnimationFrame(this._tick);
    }

    _rect(x, y, w, h, color) {
      const c = this.ctx;
      c.fillStyle = color;
      c.fillRect(Math.round(x), Math.round(y), Math.round(w), Math.round(h));
    }

    _poly(points, color) {
      const c = this.ctx;
      c.fillStyle = color;
      c.beginPath();
      points.forEach(([x, y], i) => i ? c.lineTo(x, y) : c.moveTo(x, y));
      c.closePath();
      c.fill();
    }

    _pixelEllipse(x, y, rx, ry, color, step = 2) {
      for (let row = -ry; row < ry; row += step) {
        const half = Math.round(rx * Math.sqrt(Math.max(0, 1 - (row / ry) ** 2)));
        this._rect(x - half, y + row, half * 2, step, color);
      }
    }

    _tree(x, y, scale, dark = false) {
      const trunk = dark ? '#365545' : '#627856';
      const leaf = dark ? '#385c4b' : '#728964';
      const highlight = dark ? '#476c51' : '#82976b';
      this._poly([[x - 2 * scale, y], [x + 2 * scale, y], [x + scale, y - 27 * scale], [x + 7 * scale, y - 34 * scale], [x + 5 * scale, y - 36 * scale], [x - scale, y - 28 * scale], [x - 10 * scale, y - 34 * scale], [x - 12 * scale, y - 32 * scale], [x - 3 * scale, y - 25 * scale]], trunk);
      this._poly([[x - 28 * scale, y - 33 * scale], [x - 25 * scale, y - 39 * scale], [x - 16 * scale, y - 39 * scale], [x - 13 * scale, y - 43 * scale], [x + 6 * scale, y - 44 * scale], [x + 11 * scale, y - 40 * scale], [x + 23 * scale, y - 39 * scale], [x + 27 * scale, y - 34 * scale], [x + 21 * scale, y - 31 * scale], [x - 22 * scale, y - 31 * scale]], leaf);
      this._rect(x - 19 * scale, y - 39 * scale, 29 * scale, 3 * scale, highlight);
    }

    _landscape(now) {
      // Repaint every pixel before the layered terrain; gaps between polygons
      // must never retain a sprite or particle from the previous frame.
      this._rect(0, 0, W, H, '#5f7d57');
      const colors = ['#eee4bd', '#f1e6bd', '#f4e8bb', '#f7e9b9', '#f9e8b1', '#f8e3a6', '#f4dda0'];
      colors.forEach((color, i) => this._rect(0, i * 23, W, 24, color));
      this._pixelEllipse(254, 63, 33, 32, '#f8d785');
      this._pixelEllipse(254, 61, 26, 25, '#ffedb6');
      this._rect(0, 103, W, 2, '#edd9a0');
      this._rect(41, 40, 48, 3, '#f9edcc');
      this._rect(52, 37, 22, 3, '#f9edcc');
      this._rect(351, 60, 70, 3, '#fbefd0');
      this._rect(370, 56, 34, 4, '#fbefd0');
      this._rect(134, 75, 40, 2, '#f9ecc9');
      this._poly([[0, 141], [0, 122], [36, 121], [60, 110], [85, 106], [100, 109], [124, 107], [164, 123], [197, 122], [226, 111], [251, 112], [283, 119], [317, 117], [348, 107], [387, 107], [426, 118], [455, 121], [480, 117], [480, 164]], '#b8be87');
      this._poly([[0, 153], [0, 139], [43, 140], [84, 126], [117, 127], [164, 146], [205, 143], [246, 128], [280, 130], [310, 143], [353, 131], [391, 127], [430, 139], [480, 134], [480, 181]], '#92a776');
      this._tree(59, 156, 0.9);
      this._tree(418, 158, 0.63);
      this._tree(401, 154, 0.28);
      this._poly([[0, 173], [0, 163], [41, 159], [82, 161], [135, 151], [177, 152], [226, 165], [269, 163], [312, 151], [369, 155], [411, 165], [480, 151], [480, 211]], '#748e65');
      this._poly([[0, 197], [0, 180], [37, 185], [75, 178], [124, 183], [177, 172], [216, 181], [267, 177], [314, 185], [355, 173], [405, 177], [445, 187], [480, 182], [480, 240]], '#5f7d57');
      this._rect(0, 211, W, 22, '#789251');
      this._poly([[0, 228], [19, 227], [22, 231], [53, 232], [57, 230], [89, 231], [119, 232], [124, 234], [169, 234], [175, 231], [218, 232], [227, 234], [270, 233], [278, 230], [321, 232], [329, 233], [374, 232], [380, 231], [413, 232], [420, 229], [462, 232], [480, 229], [480, 280], [0, 280]], '#b49361');
      this._rect(0, 229, W, 3, '#bdab6b');
      for (let i = 0; i < 72; i++) {
        const x = Math.floor(noise(i + 10) * W);
        const y = 203 + Math.floor(noise(i + 450) * 27);
        this._rect(x, y, 2, 3 + noise(i + 320) * 4, i % 3 ? '#8ea258' : '#b5b36c');
        if (i % 3 === 0) this._rect(x - 2, y + 2, 2, 2, '#9aaa5c');
      }
      for (let i = 0; i < 48; i++) {
        const x = noise(i + 230) * W;
        const y = 240 + noise(i + 720) * 35;
        this._rect(x, y, i % 5 === 0 ? 5 : 2, 1, i % 3 ? '#9f855b' : '#c7ab76');
      }
      this._poly([[0, 252], [15, 254], [22, 257], [35, 256], [45, 262], [65, 263], [77, 272], [101, 272], [115, 280], [0, 280]], '#3e6546');
      this._poly([[480, 248], [465, 253], [450, 252], [438, 260], [412, 261], [394, 267], [377, 267], [360, 280], [480, 280]], '#3e6546');
      for (let i = 0; i < 15; i++) {
        const left = i < 8;
        const x = left ? noise(i + 901) * 84 : 406 + noise(i + 901) * 74;
        const y = 266 + noise(i + 703) * 12;
        this._rect(x, y - 8, 2, 9, '#557a47');
        this._rect(x - 2, y - 5, 2, 3, '#688c4d');
      }
      // Sparse fireflies remain slow and soft; no flashes or strobing.
      for (let i = 0; i < 8; i++) {
        const t = this.reducedMotion ? 0 : now / 3200;
        const x = 25 + noise(i + 37) * 430 + Math.sin(t + i * 2) * 4;
        const y = 124 + noise(i + 85) * 64 + Math.cos(t * 0.7 + i) * 3;
        this.ctx.globalAlpha = 0.35 + (Math.sin(t + i) + 1) * 0.2;
        this._rect(x, y, 2, 2, '#f9e59c');
      }
      this.ctx.globalAlpha = 1;
    }

    _pose(index, now) {
      const pose = { x: index ? 354 : 126, y: FLOOR, frame: 0, lean: 0, squash: 1 };
      const direction = index ? -1 : 1;
      if (!this.playing && !this.finished) {
        if (!this.reducedMotion) pose.y -= Math.floor((Math.sin(now / 520 + index * 2) + 1) * 0.7);
        return pose;
      }
      const t = this.elapsed;
      this.exchanges.forEach((e) => {
        if (t < e.start || t > e.end) return;
        const before = e.impact - e.start;
        const local = t - e.start;
        if (index === e.actor) {
          const anticipation = before * 0.48;
          if (local < anticipation) {
            pose.frame = 1;
            if (!this.reducedMotion) {
              pose.x -= direction * Math.round(ease(local / anticipation) * 7);
              pose.squash = 0.98;
            }
          } else if (t <= e.impact + 105) {
            pose.frame = 2;
            if (!this.reducedMotion) {
              const p = ease((local - anticipation) / (before - anticipation));
              pose.x += direction * Math.round(p * (e.final ? 132 : 122));
              pose.y -= Math.round(Math.sin(p * Math.PI) * (e.final ? 11 : 6));
            }
          } else {
            pose.frame = t < e.impact + 200 ? 2 : 0;
            if (!this.reducedMotion) pose.x += direction * Math.round((1 - ease((t - e.impact - 105) / (e.end - e.impact - 105))) * (e.final ? 132 : 122));
          }
        } else if (t >= e.impact && t < e.impact + (e.final ? 800 : 400)) {
          pose.frame = 3;
          if (!this.reducedMotion) {
            const hit = clamp((t - e.impact - 70) / 350);
            pose.x -= direction * Math.round(Math.sin(Math.PI * hit) * (e.final ? 14 : 8));
            pose.squash = 0.96;
          }
        }
      });
      if (t > 8170) {
        if (index === this.winner) {
          pose.frame = 0;
          if (!this.reducedMotion) {
            const celebration = t - 8380;
            if (celebration > 0 && celebration < 1040) pose.y -= Math.round(Math.abs(Math.sin(celebration / 520 * Math.PI)) * 12);
          }
        } else { pose.frame = 3; pose.squash = 0.93; }
      }
      return pose;
    }

    _fighter(index, pose) {
      const c = this.ctx;
      const creature = CREATURES[this.fighters[index]];
      this._pixelEllipse(pose.x, FLOOR + 1, this.fighters[index] === 'mossback' ? 40 : 33, 5, '#526047');
      c.save();
      c.translate(Math.round(pose.x), Math.round(pose.y));
      c.scale(index ? -1 : 1, pose.squash);
      if (this.atlas) {
        const [sx, sy, sw, sh] = FRAMES[this.fighters[index]][pose.frame];
        const scale = 0.36;
        const dw = Math.round(sw * scale);
        const dh = Math.round(sh * scale);
        c.drawImage(this.atlas, sx, sy, sw, sh, -Math.round(dw / 2), -dh, dw, dh);
      } else {
        // A compact pixel silhouette while the sprite atlas is being fetched.
        this._rect(-34, -47, 57, 34, creature.color);
        this._rect(11, -64, 31, 32, creature.color);
        this._rect(-31, -17, 13, 17, creature.color);
        this._rect(15, -17, 12, 17, creature.color);
        this._rect(29, -55, 3, 3, '#282e27');
      }
      c.restore();
    }

    _star(x, y, size, color) {
      this._rect(x - size / 2, y, size, 2, color);
      this._rect(x, y - size / 2, 2, size, color);
      this._rect(x - 1, y - 1, 3, 3, color);
    }

    _effects(poses) {
      const c = this.ctx;
      const t = this.elapsed;
      if (!this.playing && !this.finished) return;
      this.exchanges.forEach((e, eventIndex) => {
        const local = t - e.impact;
        const direction = e.actor ? -1 : 1;
        const actor = poses[e.actor];
        const target = poses[1 - e.actor];
        const hitX = target.x - direction * 26;
        const hitY = FLOOR - 49;
        if (local >= -250 && local < 370 && !this.reducedMotion) {
          const p = clamp((local + 250) / 620);
          c.globalAlpha = Math.max(0, 1 - p);
          for (let j = 0; j < 5; j++) {
            const offset = j * 8;
            this._pixelEllipse(actor.x - direction * (28 + offset + p * 14), FLOOR - j % 2 * 2 - p * 6, 6 + p * 5, 2 + p * 2, '#d7bd81');
          }
          c.globalAlpha = 1;
        }
        if (local >= -90 && local < 145) {
          c.globalAlpha = local < 70 ? 1 : 0.6;
          const sx = hitX - direction * 12;
          this._poly([[sx - direction * 24, hitY - 27], [sx + direction * 5, hitY - 19], [sx + direction * 17, hitY - 3], [sx + direction * 15, hitY + 10], [sx + direction * 10, hitY - 1], [sx, hitY - 12]], '#ffedba');
          this._poly([[sx - direction * 12, hitY - 21], [sx + direction * 11, hitY - 12], [sx + direction * 21, hitY + 6], [sx + direction * 18, hitY + 16], [sx + direction * 14, hitY + 2], [sx + direction * 4, hitY - 8]], '#e1b467');
          c.globalAlpha = 1;
        }
        if (local >= 0 && local < 520) {
          const p = clamp(local / 520);
          for (let j = 0; j < 9; j++) {
            const angle = j * Math.PI * 2 / 9 + eventIndex;
            const distance = this.reducedMotion ? 14 : 8 + p * (24 + noise(j + eventIndex) * 20);
            const x = hitX + Math.cos(angle) * distance;
            const y = hitY + Math.sin(angle) * distance + (this.reducedMotion ? 0 : p * p * 15);
            c.globalAlpha = 1 - p;
            if (j % 3 === 0) this._star(x, y, 6, '#fff5ce');
            else this._rect(x, y, 3, 3, j % 2 ? '#f9df91' : '#f2b85e');
          }
          c.globalAlpha = 1;
        }
      });
      if (t > 8290) {
        const p = clamp((t - 8290) / 1400);
        const winner = poses[this.winner];
        const loser = poses[1 - this.winner];
        for (let j = 0; j < 15; j++) {
          const x = winner.x - 59 + noise(j + 95) * 118;
          const y = this.reducedMotion ? 92 + noise(j) * 27 : 53 + noise(j) * 62 + p * (25 + noise(j + 49) * 25);
          c.globalAlpha = 0.55 + noise(j + 31) * 0.4;
          if (j % 3) this._rect(x, y, 2, 3, j % 2 ? '#fcdfa1' : '#e9b561');
          else this._star(x, y, 6, '#fff0bb');
        }
        c.globalAlpha = 0.8;
        const orbit = this.reducedMotion ? 0 : t / 390;
        for (let j = 0; j < 3; j++) {
          const a = orbit + j * Math.PI * 2 / 3;
          this._star(loser.x + Math.cos(a) * 15, 120 + Math.sin(a) * 4, 5, '#edcb83');
        }
        c.globalAlpha = 1;
      }
    }

    _render(now) {
      const c = this.ctx;
      c.save();
      c.imageSmoothingEnabled = false;
      this._landscape(now);
      let shakeX = 0;
      let shakeY = 0;
      if (this.playing && !this.reducedMotion) {
        for (const e of this.exchanges) {
          const local = this.elapsed - e.impact;
          if (local >= 75 && local < 230) {
            shakeX = Math.round(Math.sin(local / 18) * (1 - (local - 75) / 155) * (e.final ? 3 : 2));
            shakeY = Math.round(Math.cos(local / 24) * 1.3);
          }
        }
      }
      c.translate(shakeX, shakeY);
      const poses = [this._pose(0, now), this._pose(1, now)];
      const active = this.exchanges.find((e) => this.elapsed >= e.start && this.elapsed <= e.end);
      const front = active ? active.actor : 0;
      this._fighter(1 - front, poses[1 - front]);
      this._fighter(front, poses[front]);
      this._effects(poses);
      c.restore();
    }

    _audioReady() {
      try {
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        if (!AudioContext) return;
        if (!this._audio) this._audio = new AudioContext();
        if (this._audio.state === 'suspended') this._audio.resume().catch(() => {});
      } catch (_) { /* Audio is optional; the arena works without it. */ }
    }

    _ping(kind, actor) {
      if (!this.sound || !this._audio || this._audio.state !== 'running') return;
      try {
        const a = this._audio;
        const notes = kind === 'win' ? [523.25, 659.25, 783.99, 1046.5] : kind === 'final' ? [220, 440, 660] : kind === 'hit' ? [actor ? 196 : 261.63, 98] : [146.83];
        notes.forEach((hz, index) => {
          const oscillator = a.createOscillator();
          const gain = a.createGain();
          const start = a.currentTime + index * (kind === 'win' ? 0.095 : 0.045);
          const duration = kind === 'win' ? 0.16 : 0.09;
          oscillator.type = kind === 'hit' ? 'triangle' : 'square';
          oscillator.frequency.setValueAtTime(hz, start);
          if (kind === 'hit') oscillator.frequency.exponentialRampToValueAtTime(hz / 2, start + duration);
          gain.gain.setValueAtTime(0.0001, start);
          gain.gain.exponentialRampToValueAtTime(0.025, start + 0.005);
          gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);
          oscillator.connect(gain);
          gain.connect(a.destination);
          oscillator.start(start);
          oscillator.stop(start + duration + 0.01);
          oscillator.onended = () => { oscillator.disconnect(); gain.disconnect(); };
        });
      } catch (_) { /* Keep audio failures from affecting animation. */ }
    }
  }

  window.RETRO_FRAMES = FRAMES;
  window.RetroBattle = RetroBattle;
})();
