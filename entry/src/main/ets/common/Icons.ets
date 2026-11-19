function argCount(c: string): number {
  switch (c) {
    case 'm':
    case 'l':
    case 't':
      return 2;
    case 'h':
    case 'v':
      return 1;
    case 'c':
      return 6;
    case 's':
    case 'q':
      return 4;
    case 'a':
      return 7;
    default:
      return 0;
  }
}

function round3(v: number): string {
  const r: number = Math.round(v * 1000) / 1000;
  return `${r}`;
}

function isAlpha(ch: string): boolean {
  return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z');
}

function tokenize(d: string): string[] {
  const tokens: string[] = [];
  let i: number = 0;
  while (i < d.length) {
    const ch: string = d.charAt(i);
    if (isAlpha(ch)) {
      tokens.push(ch);
      i++;
      continue;
    }
    if (ch === ' ' || ch === ',' || ch === '\n' || ch === '\t') {
      i++;
      continue;
    }
    const start: number = i;
    if (ch === '-' || ch === '+') {
      i++;
    }
    while (i < d.length) {
      const c2: string = d.charAt(i);
      if ((c2 >= '0' && c2 <= '9') || c2 === '.') {
        i++;
      } else {
        break;
      }
    }
    if (i === start) {
      i++;
      continue;
    }
    tokens.push(d.substring(start, i));
  }
  return tokens;
}

function appendArc(c: CanvasRenderingContext2D, x1: number, y1: number, rxIn: number, ryIn: number,
  rot: number, large: number, sweep: number, x2: number, y2: number, k: number): void {
  if (x1 === x2 && y1 === y2) {
    return;
  }
  if (rxIn === 0 || ryIn === 0) {
    c.lineTo(x2 * k, y2 * k);
    return;
  }
  let rx: number = Math.abs(rxIn);
  let ry: number = Math.abs(ryIn);
  const phi: number = rot * Math.PI / 180;
  const cosP: number = Math.cos(phi);
  const sinP: number = Math.sin(phi);
  const hx: number = (x1 - x2) / 2;
  const hy: number = (y1 - y2) / 2;
  const xp: number = cosP * hx + sinP * hy;
  const yp: number = -sinP * hx + cosP * hy;
  const check: number = xp * xp / (rx * rx) + yp * yp / (ry * ry);
  if (check > 1) {
    const grow: number = Math.sqrt(check);
    rx = rx * grow;
    ry = ry * grow;
  }
  const rx2: number = rx * rx;
  const ry2: number = ry * ry;
  const xp2: number = xp * xp;
  const yp2: number = yp * yp;
  const den: number = rx2 * yp2 + ry2 * xp2;
  const num: number = rx2 * ry2 - rx2 * yp2 - ry2 * xp2;
  const sign: number = large === sweep ? -1 : 1;
  const coef: number = den === 0 ? 0 : sign * Math.sqrt(Math.max(0, num / den));
  const cxp: number = coef * (rx * yp / ry);
  const cyp: number = coef * (-ry * xp / rx);
  const ccx: number = cosP * cxp - sinP * cyp + (x1 + x2) / 2;
  const ccy: number = sinP * cxp + cosP * cyp + (y1 + y2) / 2;
  const ux: number = (xp - cxp) / rx;
  const uy: number = (yp - cyp) / ry;
  const vx: number = (-xp - cxp) / rx;
  const vy: number = (-yp - cyp) / ry;
  const start: number = Math.atan2(uy, ux);
  let delta: number = Math.atan2(ux * vy - uy * vx, ux * vx + uy * vy);
  if (sweep === 1 && delta < 0) {
    delta += Math.PI * 2;
  } else if (sweep === 0 && delta > 0) {
    delta -= Math.PI * 2;
  }
  const count: number = Math.max(1, Math.ceil(Math.abs(delta) / (Math.PI / 2)));
  const step: number = delta / count;
  const tan: number = 4 / 3 * Math.tan(step / 4);
  let theta: number = start;
  for (let index: number = 0; index < count; index++) {
    const cosA: number = Math.cos(theta);
    const sinA: number = Math.sin(theta);
    const cosB: number = Math.cos(theta + step);
    const sinB: number = Math.sin(theta + step);
    const px: number = ccx + rx * cosP * cosA - ry * sinP * sinA;
    const py: number = ccy + rx * sinP * cosA + ry * cosP * sinA;
    const qx: number = ccx + rx * cosP * cosB - ry * sinP * sinB;
    const qy: number = ccy + rx * sinP * cosB + ry * cosP * sinB;
    const dx1: number = -rx * cosP * sinA - ry * sinP * cosA;
    const dy1: number = -rx * sinP * sinA + ry * cosP * cosA;
    const dx2: number = -rx * cosP * sinB - ry * sinP * cosB;
    const dy2: number = -rx * sinP * sinB + ry * cosP * cosB;
    c.bezierCurveTo((px + tan * dx1) * k, (py + tan * dy1) * k,
      (qx - tan * dx2) * k, (qy - tan * dy2) * k, qx * k, qy * k);
    theta += step;
  }
}

export function drawGlyph(c: CanvasRenderingContext2D, name: string, k: number): void {
  const tokens: string[] = tokenize(iconPath(name));
  let cx: number = 0;
  let cy: number = 0;
  let sx: number = 0;
  let sy: number = 0;
  let cur: string = '';
  let buf: number[] = [];
  let idx: number = 0;

  c.beginPath();
  for (let t = 0; t < tokens.length; t++) {
    const tk: string = tokens[t];
    if (isAlpha(tk)) {
      cur = tk;
      buf = [];
      idx = 0;
      if (cur.toLowerCase() === 'z') {
        c.closePath();
        cx = sx;
        cy = sy;
      }
      continue;
    }
    const low: string = cur.toLowerCase();
    const cnt: number = argCount(low);
    if (cnt === 0) {
      continue;
    }
    buf.push(Number.parseFloat(tk));
    idx++;
    if (idx % cnt !== 0) {
      continue;
    }
    const p: number[] = buf;
    const rel: boolean = cur === low;
    if (low === 'm') {
      const x: number = rel ? cx + p[0] : p[0];
      const y: number = rel ? cy + p[1] : p[1];
      c.moveTo(x * k, y * k);
      cx = x;
      cy = y;
      sx = x;
      sy = y;
      cur = rel ? 'l' : 'L';
    } else if (low === 'l') {
      const x: number = rel ? cx + p[0] : p[0];
      const y: number = rel ? cy + p[1] : p[1];
      c.lineTo(x * k, y * k);
      cx = x;
      cy = y;
    } else if (low === 'h') {
      const x: number = rel ? cx + p[0] : p[0];
      c.lineTo(x * k, cy * k);
      cx = x;
    } else if (low === 'v') {
      const y: number = rel ? cy + p[0] : p[0];
      c.lineTo(cx * k, y * k);
      cy = y;
    } else if (low === 'c') {
      const x1: number = rel ? cx + p[0] : p[0];
      const y1: number = rel ? cy + p[1] : p[1];
      const x2: number = rel ? cx + p[2] : p[2];
      const y2: number = rel ? cy + p[3] : p[3];
      const x: number = rel ? cx + p[4] : p[4];
      const y: number = rel ? cy + p[5] : p[5];
      c.bezierCurveTo(x1 * k, y1 * k, x2 * k, y2 * k, x * k, y * k);
      cx = x;
      cy = y;
    } else if (low === 's' || low === 'q') {
      const x: number = rel ? cx + p[2] : p[2];
      const y: number = rel ? cy + p[3] : p[3];
      c.quadraticCurveTo((rel ? cx + p[0] : p[0]) * k, (rel ? cy + p[1] : p[1]) * k, x * k, y * k);
      cx = x;
      cy = y;
    } else if (low === 'a') {
      const ex: number = rel ? cx + p[5] : p[5];
      const ey: number = rel ? cy + p[6] : p[6];
      appendArc(c, cx, cy, p[0], p[1], p[2], p[3], p[4], ex, ey, k);
      cx = ex;
      cy = ey;
    }
    buf = [];
  }
}

export function scalePath(d: string, k: number): string {
  const tokens: string[] = [];
  let i: number = 0;
  while (i < d.length) {
    const ch: string = d.charAt(i);
    if (isAlpha(ch)) {
      tokens.push(ch);
      i++;
      continue;
    }
    if (ch === ' ' || ch === ',' || ch === '\n' || ch === '\t') {
      i++;
      continue;
    }
    const start: number = i;
    if (ch === '-' || ch === '+') {
      i++;
    }
    while (i < d.length) {
      const c2: string = d.charAt(i);
      if ((c2 >= '0' && c2 <= '9') || c2 === '.') {
        i++;
      } else {
        break;
      }
    }
    if (i === start) {
      i++;
      continue;
    }
    tokens.push(d.substring(start, i));
  }

  let out: string = '';
  let cur: string = '';
  let first: boolean = true;
  let buf: number[] = [];
  let idx: number = 0;

  for (let t = 0; t < tokens.length; t++) {
    const tk: string = tokens[t];
    if (isAlpha(tk)) {
      if (cur.toLowerCase() === 'z') {
        out += 'z';
      }
      cur = tk;
      first = true;
      buf = [];
      idx = 0;
      continue;
    }
    const cnt: number = argCount(cur.toLowerCase());
    if (cnt === 0) {
      continue;
    }
    let v: number = Number.parseFloat(tk);
    const slot: number = idx % cnt;
    const isFlag: boolean = cur.toLowerCase() === 'a' && (slot === 3 || slot === 4);
    if (!isFlag) {
      v = v * k;
    }
    buf.push(v);
    idx++;
    if (buf.length === cnt) {
      let emit: string = cur;
      if (!first) {
        if (cur === 'M') {
          emit = 'L';
        } else if (cur === 'm') {
          emit = 'l';
        }
      }
      let seg: string = emit;
      for (let b = 0; b < buf.length; b++) {
        const s: string = round3(buf[b]);
        seg += s.charAt(0) === '-' ? s : ` ${s}`;
      }
      out += seg;
      buf = [];
      first = false;
    }
  }
  if (cur.toLowerCase() === 'z') {
    out += 'z';
  }
  return out;
}

export function iconPath(name: string): string {
  switch (name) {
    case 'home':
      return 'M3 10.5 12 3l9 7.5V21H3zM9 21v-7h6v7';
    case 'library':
      return 'M4 4h4v16H4zM10 4h4v16h-4zM16.5 5l3.5 1-3 14-3.5-1z';
    case 'discover':
      return 'M4 11a7 7 0 1 0 14 0a7 7 0 1 0-14 0M16.5 16.5l4 4';
    case 'local':
      return 'M5 5h14a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2zM3 10h18M8 5v5M12 14h5';
    case 'chart':
      return 'M4 20V10M10 20V4M16 20v-7M22 20H2';
    case 'user':
      return 'M8 8a4 4 0 1 0 8 0a4 4 0 1 0-8 0M4 21c0-4.4 3.6-7 8-7c4.4 0 8 2.6 8 7';
    case 'back':
      return 'm15 18-6-6 6-6';
    case 'next':
      return 'm9 18 6-6-6-6';
    case 'down':
      return 'm6 9 6 6 6-6';
    case 'up':
      return 'm6 15 6-6 6 6';
    case 'search':
      return 'M4 11a7 7 0 1 0 14 0a7 7 0 1 0-14 0M16.5 16.5l4 4';
    case 'filter':
      return 'M3 5h18M6 12h12M10 19h4';
    case 'grid':
      return 'M4 3h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zM15 3h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1h-5a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zM4 14h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1v-5a1 1 0 0 1 1-1zM15 14h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1h-5a1 1 0 0 1-1-1v-5a1 1 0 0 1 1-1z';
    case 'list':
      return 'M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01';
    case 'download':
      return 'M12 3v12m0 0 4-4m-4 4-4-4M4 18v3h16v-3';
    case 'upload':
      return 'M12 17V5m0 0 4 4m-4-4L8 9M4 18v3h16v-3';
    case 'book':
      return 'M4 4h7a3 3 0 0 1 3 3v13a3 3 0 0 0-3-3H4zM20 4h-3a3 3 0 0 0-3 3v13a3 3 0 0 1 3-3h3z';
    case 'bookmark':
      return 'M6 3h12v18l-6-4-6 4z';
    case 'marker':
      return 'm4 20 4-1 11-11-3-3L5 16zM14 6l3 3';
    case 'toc':
      return 'M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01';
    case 'settings':
      return 'M10.53 2.72L13.47 2.72L13.62 5.24L15.63 6.07L17.53 4.4L19.6 6.47L17.93 8.37L18.76 10.38L21.28 10.53L21.28 13.47L18.76 13.62L17.93 15.63L19.6 17.53L17.53 19.6L15.63 17.93L13.62 18.76L13.47 21.28L10.53 21.28L10.38 18.76L8.37 17.93L6.47 19.6L4.4 17.53L6.07 15.63L5.24 13.62L2.72 13.47L2.72 10.53L5.24 10.38L6.07 8.37L4.4 6.47L6.47 4.4L8.37 6.07L10.38 5.24ZM8.8 12a3.2 3.2 0 1 0 6.4 0a3.2 3.2 0 1 0-6.4 0';
    case 'more':
      return 'M3.6 12a1.4 1.4 0 1 0 2.8 0a1.4 1.4 0 1 0-2.8 0M10.6 12a1.4 1.4 0 1 0 2.8 0a1.4 1.4 0 1 0-2.8 0M17.6 12a1.4 1.4 0 1 0 2.8 0a1.4 1.4 0 1 0-2.8 0';
    case 'edit':
      return 'M4 20h4L20 8l-4-4L4 16zM14 6l4 4';
    case 'cover':
      return 'M4 4h16v16H4zM4 15l4-4 3 3 3-3 6 5';
    case 'ext':
      return 'M14 4h6v6M20 4l-9 9M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5';
    case 'close':
      return 'M6 6l12 12M18 6 6 18';
    case 'check':
      return 'm4 12 5 5L20 6';
    case 'sync':
      return 'M20 11a8 8 0 0 0-14-5L4 8m0 5a8 8 0 0 0 14 5l2-2M4 4v4h4M20 20v-4h-4';
    case 'server':
      return 'M5 3h14a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2zM5 14h14a2 2 0 0 1 2 2v3a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2zM7 6.5h.01M7 17.5h.01M11 6.5h6M11 17.5h6';
    case 'shield':
      return 'M12 2 4 5v7c0 5 3.5 8.5 8 10 4.5-1.5 8-5 8-10V5zm-3 10 2 2 4-4';
    case 'eyeOff':
      return 'M3 3l18 18M10.6 6.2A9 9 0 0 1 12 6c5 0 9 6 9 6a15 15 0 0 1-2.2 2.8M6.5 7.6C4.3 9 3 12 3 12c0 0 4 6 9 6a8 8 0 0 0 3-.6M9.9 9.9a3 3 0 0 0 4.2 4.2';
    case 'play':
      return 'M7 4l13 8-13 8z';
    case 'pause':
      return 'M7 4v16M17 4v16';
    case 'type':
      return 'M4 7V4h16v3M12 4v16M9 20h6';
    case 'sun':
      return 'M8 12a4 4 0 1 0 8 0a4 4 0 1 0-8 0M12 2v2m0 16v2M2 12h2m16 0h2M4.9 4.9l1.4 1.4m11.4 11.4 1.4 1.4M19.1 4.9l-1.4 1.4M6.3 17.7l-1.4 1.4';
    case 'moon':
      return 'M20 14A8 8 0 0 1 10 4a8 8 0 1 0 10 10z';
    case 'trash':
      return 'M4 7h16M9 7V4h6v3M6 7l1 14h10l1-14M10 11v6M14 11v6';
    case 'info':
      return 'M3 12a9 9 0 1 0 18 0a9 9 0 1 0-18 0M12 11v6M12 7h.01';
    case 'clock':
      return 'M3 12a9 9 0 1 0 18 0a9 9 0 1 0-18 0M12 7v5l3 2';
    case 'folder':
      return 'M3 6h6l2 2h10v11H3z';
    case 'collection':
      return 'M4 3h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zM15 3h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1h-5a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zM4 14h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1v-5a1 1 0 0 1 1-1zM15 14h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1h-5a1 1 0 0 1-1-1v-5a1 1 0 0 1 1-1z';
    case 'readlist':
      return 'M4 5h16M4 10h16M4 15h10M4 20h7';
    case 'export':
      return 'M12 16V3m0 0L8 7m4-4 4 4M4 17v4h16v-4';
    case 'warn':
      return 'M12 3 2 21h20zM12 9v5M12 17h.01';
    case 'zoom':
      return 'M4 11a7 7 0 1 0 14 0a7 7 0 1 0-14 0M16.5 16.5l4 4M8 11h6M11 8v6';
    case 'thumbs':
      return 'M3 7h3a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V8a1 1 0 0 1 1-1zM10.5 7h3a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1h-3a1 1 0 0 1-1-1V8a1 1 0 0 1 1-1zM18 7h3a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1h-3a1 1 0 0 1-1-1V8a1 1 0 0 1 1-1z';
    case 'tts':
      return 'M4 9v6h4l5 4V5L8 9zM17 9a4 4 0 0 1 0 6M19.5 6a8 8 0 0 1 0 12';
    case 'wifiOff':
      return 'M3 3l18 18M8.5 15.5a5 5 0 0 1 7 0M5 12a10 10 0 0 1 3-2M2 8.5A15 15 0 0 1 6 6.3M12 19h.01';
    default:
      return '';
  }
}
