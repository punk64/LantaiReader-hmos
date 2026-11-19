(function () {
  'use strict';
  var L = window.LantaiI18n || { t: function (k) { return k; }, lang: function () { return 'zh-Hans'; }, langs: function () { return []; }, name: function (c) { return c; } };

  var THEMES = [
    ['paper', L.t('纸白'), '#fbf9f3', '#1f1e1a', '#ffffff', '#f3efe4', '#8a6d2f'],
    ['sepia', L.t('牛皮纸'), '#f0e5cf', '#4a3f2b', '#f8f0de', '#e6d8bd', '#8a5a26'],
    ['green', L.t('护眼'), '#dde8d6', '#2b362a', '#e8f0e2', '#cfdcc6', '#4c6b45'],
    ['ink', L.t('墨黑'), '#0c0d0f', '#9fa6ad', '#15171a', '#1b1e22', '#7a8fa6'],
    ['night', L.t('夜间'), '#14171c', '#b4c0cc', '#1b1f25', '#20252c', '#6f8aa6']
  ];
  var FONTS = [
    ['serif', L.t('宋体'), '"Noto Serif CJK SC","Source Han Serif SC","Songti SC","HarmonyOS Sans SC","SimSun",Georgia,"Times New Roman",serif'],
    ['sans', L.t('黑体'), '"HarmonyOS Sans SC","Noto Sans CJK SC","Source Han Sans SC","PingFang SC","Microsoft YaHei",system-ui,sans-serif'],
    ['kai', L.t('楷体'), '"Kaiti SC",KaiTi,STKaiti,"Songti SC",serif'],
    ['book', L.t('原书'), 'inherit']
  ];
  var COLORS = ['#C9A24B', '#B0402C', '#46523F', '#2F5D8A', '#7B4F6B', '#E3C377'];
  var MARK_CN = { highlight: L.t('高亮'), underline: L.t('下划线'), bookmark: L.t('书签'), comment: L.t('笔记') };
  var TTS_STYLES = [
    { id: 'plain', name: '平实', speed: 1, pitch: 1, volume: 1, gap: 200 },
    { id: 'calm', name: '沉稳', speed: 0.92, pitch: 0.94, volume: 1, gap: 300 },
    { id: 'lively', name: '轻快', speed: 1.1, pitch: 1.06, volume: 1.04, gap: 240 },
    { id: 'story', name: '讲述', speed: 0.96, pitch: 1.1, volume: 1.06, gap: 380 }
  ];
  var TTS_PITCHES = [
    { value: 0.9, name: '低' },
    { value: 1, name: '标准' },
    { value: 1.1, name: '高' }
  ];
  var TTS_GAPS = [
    { id: 'tight', name: '紧', k: 0.8 },
    { id: 'normal', name: '标准', k: 1 },
    { id: 'loose', name: '松', k: 1.25 }
  ];
  var TTS_BREAK = [
    { ch: '、', ms: 60 },
    { ch: '，', ms: 90 }, { ch: ',', ms: 90 },
    { ch: '：', ms: 130 }, { ch: ':', ms: 130 },
    { ch: '；', ms: 150 }, { ch: ';', ms: 150 },
    { ch: '—', ms: 180 },
    { ch: '…', ms: 220 },
    { ch: '」', ms: 60 }, { ch: '”', ms: 60 }
  ];

  var PRE = {
    theme: 'paper', size: 18, lh: 1.85, para: 0.9, font: 'serif', measure: 38, indent: true,
    pubcss: true, wake: false, imm: false, ttsRate: 1, ttsVoice: '', ttsStyle: 'plain', ttsPitch: 1, ttsAuto: true, ttsGap: 'normal', ttsEmph: true, sink: 0,
    layout: 'scroll', dir: 'LTR', tapAny: true
  };
  try { Object.assign(PRE, JSON.parse(localStorage.getItem('lantai-ebook') || '{}')); } catch (e) { }
  if (!localStorage.getItem('lantai-ebook.pub1')) {
    PRE.pubcss = true;
    try { localStorage.setItem('lantai-ebook.pub1', '1'); } catch (e) { }
  }
  if (!localStorage.getItem('lantai-ebook.tts1')) {
    PRE.ttsAuto = true;
    PRE.ttsEmph = true;
    try { localStorage.setItem('lantai-ebook.tts1', '1'); } catch (e) { }
  }
  PRE.ttsAuto = !!PRE.ttsAuto;
  PRE.ttsEmph = !!PRE.ttsEmph && PRE.ttsAuto;
  if (!PRE.ttsStyle || ttsStyleOf().id !== PRE.ttsStyle) PRE.ttsStyle = 'plain';
  var ttsPitchInit = ttsPitchOf();
  PRE.ttsPitch = (ttsPitchInit === 0.9 || ttsPitchInit === 1 || ttsPitchInit === 1.1) ? ttsPitchInit : 1;
  if (PRE.ttsGap !== 'tight' && PRE.ttsGap !== 'normal' && PRE.ttsGap !== 'loose') PRE.ttsGap = 'normal';

  var EB = {
    open: false, bookId: '', book: null, total: 0, ch: 1, seen: 1,
    chs: new Map(), secs: new Map(), pending: {}, park: new Map(),
    lo: 0, hi: 0, outline: null, outlineLoading: false, outlinePending: null,
    anns: [], links: [], inlines: [],
    panel: null, shadow: null, docEl: null, view: null,
    shadowSeeded: false, progTimer: null, hbTimer: null, session: null, beats: 0,
    restore: -1, restoreT: null, idle: null, raf: 0, bootAt: 0,
    sel: null, tts: null, ttsIdx: 0, ttsOn: false, ttsCh: 0, wakeLock: null,
    toastT: null, lastCh: 0, ready: false, warmF: false, warmB: false,
    page: 0, pages: 1, annTab: 'all', annQ: '', annQT: 0,
    findQ: '', findMark: '', fontFams: null, nav: null, pre: null,
    vols: null, seeking: null, drag: null, hold: null,
    holdTimer: -1, holdAt: null, holdFired: false,
    selRange: null, selMode: '', selFix: null, selText: '', selW: 0, selH: 0, selMore: false,
    manualT: 0, followT: -1, autoT: 0
  };

  var SAFE = { t: 0, b: 0 };
  try {
    var SP = new URLSearchParams(location.search);
    SAFE.t = Math.max(0, Math.round(+SP.get('st') || 0));
    SAFE.b = Math.max(0, Math.round(+SP.get('sb') || 0));
  } catch (e) { }

  function rt() { return window.LantaiRuntime; }
  function req(p, o) {
    var opt = o || {};
    if (PRE.imm) opt = Object.assign({}, opt, { headers: Object.assign({ 'X-Lantai-Incognito': '1' }, opt.headers || {}) });
    return rt().request(p, opt);
  }
  function $(id) { return document.getElementById(id); }
  function el(tag, cls, html) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (html != null) n.innerHTML = html;
    return n;
  }
  function ico(name, size) {
    return '<svg width="' + (size || 16) + '" height="' + (size || 16) + '"><use href="#i-' + name + '"/></svg>';
  }
  function errText(e) {
    if (!e) return L.t('请求失败');
    if (e.status === 403) return L.t('没有这个书库的阅读权限');
    if (e.status === 404) return L.t('书籍或章节不存在');
    return e.message ? String(e.message).slice(0, 120) : 'HTTP ' + (e.status || 'err');
  }

  function toast(text, kind) {
    var t = $('ebToast'); if (!t) return;
    t.textContent = text;
    t.className = 'eb-toast on' + (kind === 'err' ? ' err' : '');
    clearTimeout(EB.toastT);
    EB.toastT = setTimeout(function () { t.className = 'eb-toast'; }, 2600);
  }
  function tip(title, body) {
    var t = $('ebTip'); if (!t) return;
    if (!title) { t.classList.remove('on'); return; }
    t.innerHTML = '<b>' + esc(title) + '</b>' + (body || '');
    t.classList.add('on');
  }

  function savePrefs() {
    try { localStorage.setItem('lantai-ebook', JSON.stringify(PRE)); } catch (e) { }
  }
  function ttsClamp(v, a, b) {
    return Math.max(a, Math.min(b, v));
  }
  function ttsStyleOf() {
    for (var i = 0; i < TTS_STYLES.length; i++) {
      if (TTS_STYLES[i].id === PRE.ttsStyle) return TTS_STYLES[i];
    }
    return TTS_STYLES[0];
  }
  function ttsPitchOf() {
    var v = +PRE.ttsPitch;
    return isNaN(v) ? 1 : v;
  }
  function ttsGapK() {
    for (var i = 0; i < TTS_GAPS.length; i++) if (TTS_GAPS[i].id === PRE.ttsGap) return TTS_GAPS[i].k;
    return 1;
  }
  function ttsHash(seed) {
    var h = 2166136261;
    for (var i = 0; i < seed.length; i++) {
      h ^= seed.charCodeAt(i);
      h = (h * 16777619) >>> 0;
    }
    return h;
  }
  function ttsPause(base, speed, seed) {
    var v = base / Math.pow(Math.max(0.5, speed), 0.8);
    var r = ((ttsHash(seed) % 2001) / 1000) - 1;
    v = v * (1 + r * 0.15);
    return Math.round(ttsClamp(v, 60, 400) / 10) * 10;
  }
  function ttsClean(text) {
    var t = String(text || '');
    t = t.replace(/[\u200b-\u200f\ufeff\ufe0f]/g, '');
    t = t.replace(/[\u2190-\u21ff\u2300-\u23ff\u2600-\u27bf\u2b00-\u2bff]/g, '');
    t = t.replace(/https?:\/\/[^\s]+/gi, '');
    t = t.replace(/\[\d{1,3}\]/g, '');
    t = t.replace(/(^|\s)[\-—*=_]{3,}(?=\s|$)/g, ' ');
    t = t.replace(/([！!])\1+/g, '$1');
    t = t.replace(/([？?])\1+/g, '$1');
    t = t.replace(/。{3,}/g, '……');
    t = t.replace(/\.{4,}/g, '……');
    t = t.replace(/[\s\u00a0\u3000]+/g, ' ');
    return t.trim();
  }
  function ttsNums(text) {
    if (!PRE.ttsAuto) return text;
    var t = text;
    t = t.replace(/(^|[^\d\[])((?:19|20)\d{2})\s*年/g, '$1[n1]$2年');
    t = t.replace(/(^|[^\d\[])(\d{7,})(?!\d)/g, '$1[n1]$2');
    return t;
  }
  function ttsBreakMs(ch) {
    for (var i = 0; i < TTS_BREAK.length; i++) if (TTS_BREAK[i].ch === ch) return TTS_BREAK[i].ms;
    return 0;
  }
  function ttsBreaks(text, speed, seed) {
    var s = String(text || '');
    var out = '', n = 0, sum = 0;
    for (var i = 0; i < s.length; i++) {
      out += s[i];
      if (n >= 3 || sum >= 500 || i >= s.length - 1) continue;
      var base = ttsBreakMs(s[i]);
      if (!base) continue;
      if ((s[i] === '—' || s[i] === '…') && s[i + 1] === s[i]) continue;
      if ((s[i] === '」' || s[i] === '”') && (/[。！？!?…]/.test(s[i - 1] || '') || /[。！？!?…]/.test(s[i + 1] || ''))) continue;
      var ms = ttsPause(base, speed, seed + ':' + i);
      if (sum + ms > 500) continue;
      out += '[p' + ms + ']';
      n++;
      sum += ms;
    }
    return out;
  }
  function ttsSignals(s) {
    var last = s.slice(-1);
    return {
      ex: last === '！' || last === '!',
      q: last === '？' || last === '?',
      ell: s.indexOf('……') >= 0 || /\.{3,}/.test(s),
      dash: /—{2,}/.test(s),
      quote: /[“”「」『』]/.test(s),
      redupe: /([\u4e00-\u9fa5])\1/.test(s)
    };
  }
  function ttsModOf(text, opt) {
    var o = opt || {};
    var style = ttsStyleOf();
    var s = String(text || '');
    var speed = PRE.ttsRate * style.speed;
    var pitch = ttsPitchOf() * style.pitch;
    var volume = style.volume;
    var gap = style.gap * ttsGapK();
    var len = s.length;
    if (PRE.ttsAuto) {
      if (o.title) {
        speed -= 0.08;
        pitch -= 0.03;
      } else {
        speed += o.dialog ? 0.06 : -0.03;
        if (len >= 45) speed -= 0.04;
        else if (len <= 12) speed += 0.02;
        if (len <= 6) gap += 40;
      }
      var sig = ttsSignals(s);
      if (o.boost >= 2) {
        pitch += 0.04;
        volume += 0.04;
        gap += 40;
      } else if (o.boost === 1) {
        pitch += 0.03;
      }
      if (sig.ell || sig.dash) {
        gap += 140;
        speed -= 0.02;
      }
      if (sig.quote && o.boost >= 1) volume -= 0.02;
      if (PRE.ttsEmph && sig.redupe) volume += 0.02;
    }
    gap += o.gapAdd || 0;
    return {
      speed: Math.round(ttsClamp(speed, 0.5, 2) * 1000) / 1000,
      pitch: Math.round(ttsClamp(pitch, 0.8, 1.25) * 1000) / 1000,
      volume: Math.round(ttsClamp(volume, 0.95, 1.08) * 1000) / 1000,
      gap: Math.round(ttsClamp(gap, 120, 1200))
    };
  }
  function ttsTextOf(item) {
    return typeof item === 'string' ? item : String(item.text || '');
  }
  function ttsGroups(list) {
    var out = [], cur = [], last = null;
    for (var i = 0; i < list.length; i++) {
      var el = list[i].el || null;
      if (i > 0 && (el !== last || el === null)) {
        out.push(cur);
        cur = [];
      }
      cur.push(i);
      last = el;
    }
    if (cur.length) out.push(cur);
    return out;
  }
  function ttsPlan(list) {
    var n = list.length;
    var boost = [], dialog = [], tail = [], title = [];
    var i;
    for (i = 0; i < n; i++) {
      boost.push(0);
      dialog.push(0);
      tail.push(0);
      title.push(0);
    }
    var groups = ttsGroups(list);
    for (var gi = 0; gi < groups.length; gi++) {
      var g = groups[gi], best = -1, bestScore = 0, allLen = 0, quoteLen = 0;
      for (var j = 0; j < g.length; j++) {
        var raw = ttsTextOf(list[g[j]]);
        allLen += raw.length;
        if (/[“”「」『』]/.test(raw)) quoteLen += raw.length;
        var el = list[g[j]].el;
        if (el && /^H[1-6]$/.test(el.tagName || '')) title[g[j]] = 1;
        var sc = 0;
        if (/[！!]$/.test(raw)) sc = 3;
        else if (/[？?]$/.test(raw)) sc = 2;
        if (sc > bestScore) {
          bestScore = sc;
          best = g[j];
        }
      }
      var isDialog = allLen > 0 && quoteLen / allLen > 0.6;
      for (var m = 0; m < g.length; m++) {
        if (g[m] === best && bestScore >= 2) boost[g[m]] = bestScore === 3 ? 2 : 1;
        dialog[g[m]] = isDialog ? 1 : 0;
        tail[g[m]] = m === g.length - 1 ? 1 : 0;
      }
    }
    var items = [], mods = [];
    for (i = 0; i < n; i++) {
      var src = ttsTextOf(list[i]);
      var body = ttsNums(ttsClean(src)) || src;
      var gapAdd = 0;
      if (PRE.ttsAuto) {
        if (title[i]) gapAdd += 500;
        if (tail[i]) gapAdd += 220;
        if (i === n - 1) gapAdd += 400;
      }
      var mod = ttsModOf(body, { boost: boost[i], dialog: dialog[i], title: title[i], gapAdd: gapAdd });
      items.push(PRE.ttsAuto ? ttsBreaks(body, mod.speed, EB.ch + ':' + i) : body);
      mods.push(mod);
    }
    return { items: items, mods: mods };
  }
  function immKey() { return 'lantai.imm.e.' + EB.bookId; }
  function immResume(bookId) {
    try { return JSON.parse(sessionStorage.getItem('lantai.imm.e.' + bookId) || 'null'); } catch (e) { return null; }
  }

  function themeOf(key) {
    for (var i = 0; i < THEMES.length; i++) if (THEMES[i][0] === key) return THEMES[i];
    return THEMES[0];
  }

  function applyTheme() {
    var r = $('eb'); if (!r) return;
    var t = themeOf(PRE.theme);
    r.style.setProperty('--eb-bg', t[2]);
    r.style.setProperty('--eb-tx', t[3]);
    r.style.setProperty('--eb-card', t[4]);
    r.style.setProperty('--eb-sunk', t[5]);
    r.style.setProperty('--eb-acc', t[6]);
    r.style.setProperty('--eb-dim', t[0] === 'ink' || t[0] === 'night' ? '#8b939b' : '#6f6a5e');
    r.style.setProperty('--eb-line', t[0] === 'ink' || t[0] === 'night' ? 'rgba(255,255,255,.12)' : 'rgba(0,0,0,.1)');
    r.style.setProperty('--eb-shadow', t[0] === 'ink' || t[0] === 'night' ? '0 16px 48px rgba(0,0,0,.55)' : '0 16px 48px rgba(48,40,24,.16)');
    r.classList.toggle('night', t[0] === 'ink' || t[0] === 'night');
    if (EB.shadow) applyBase();
  }

  function applyType() {
    var r = $('eb'); if (!r) return;
    r.style.setProperty('--eb-fs', PRE.size + 'px');
    r.style.setProperty('--eb-lh', PRE.lh);
    r.style.setProperty('--eb-para', PRE.para + 'em');
    r.style.setProperty('--eb-ti', PRE.indent ? '2em' : '0');
    r.style.setProperty('--eb-measure', PRE.measure + 'rem');
    r.style.setProperty('--eb-fam', fontFamily());
    if (PRE.font.indexOf('srv:') === 0) fontFaceOf(PRE.font.slice(4));
    if (EB.shadow) applyBase();
  }

  function fontFamily() {
    for (var i = 0; i < FONTS.length; i++) if (FONTS[i][0] === PRE.font) return FONTS[i][2];
    return FONTS[0][2];
  }

  var fontFaceState = { family: '', css: {} };

  function loadFontFamilies() {
    if (EB.fontFams !== null) return;
    EB.fontFams = [];
    req('api/v1/fonts/families').then(function (list) {
      var names = (list || []).filter(function (x) { return typeof x === 'string' && x; });
      EB.fontFams = names;
      names.forEach(function (name) {
        var key = 'srv:' + name;
        if (!FONTS.some(function (f) { return f[0] === key; })) FONTS.push([key, name, "'" + name + "',serif"]);
      });
      if (EB.panel === 'set') paintSet('set');
    }).catch(function () { });
  }

  function fontFaceOf(name) {
    if (!EB.shadow || !name) return;
    var style = EB.shadow.getElementById('ebFont');
    if (!style) {
      style = document.createElement('style');
      style.id = 'ebFont';
      var anchor = EB.shadow.getElementById('ebPub') || EB.shadow.getElementById('ebDoc');
      if (anchor && anchor.parentNode) anchor.parentNode.insertBefore(style, anchor);
      else EB.shadow.appendChild(style);
    }
    if (fontFaceState.family === name) return;
    if (fontFaceState.css[name]) {
      style.textContent = fontFaceState.css[name];
      fontFaceState.family = name;
      return;
    }
    var base = (window.resourceBaseUrl || '/').replace(/\/?$/, '/') + 'api/v1/fonts/resource/' + encodeURIComponent(name) + '/';
    fetch(base + 'css', { credentials: 'same-origin' })
      .then(function (res) { return res.ok ? res.text() : ''; })
      .then(function (css) {
        var fixed = String(css || '').replace(/url\((['"]?)([^'")]+)\1\)/g, function (whole, quote, url) {
          if (/^(data:|https?:|\/\/|\/)/.test(url)) return whole;
          return "url('" + base + url + "')";
        });
        fontFaceState.css[name] = fixed;
        if (PRE.font !== 'srv:' + name) return;
        fontFaceState.family = name;
        style.textContent = fixed;
      })
      .catch(function () { });
  }

  function isPaged() { return PRE.layout !== 'scroll'; }

  function colsOf(w) { return PRE.layout === 'double' && w >= 860 ? 2 : 1; }

  function viewHeight() {
    var v = EB.view;
    var h = (v && (v.clientHeight || v.offsetHeight)) || 0;
    return Math.max(280, Math.round(h || window.innerHeight * 0.8));
  }

  function layoutMetrics() {
    var v = EB.view;
    var cw = (v && (v.clientWidth || v.offsetWidth)) || 600;
    var gut = Math.round(Math.min(72, Math.max(16, cw * 0.045)));
    var cols = colsOf(cw);
    var gap = gut * 2;
    var pw = Math.max(180, Math.floor((cw - gut * 2 - (cols - 1) * gap) / cols));
    return { gut: gut, gap: gap, pw: pw, cols: cols, step: cw };
  }

  function measure() {
    var v = EB.view;
    if (!v || !isPaged()) { EB.pages = 1; EB.page = 0; return; }
    var m = layoutMetrics();
    EB.pages = Math.max(1, Math.ceil((v.scrollWidth - 2) / Math.max(1, m.step)));
    EB.page = clamp(Math.ceil((v.scrollLeft - 1) / Math.max(1, m.step)), 0, EB.pages - 1);
  }

  function goPage(n) {
    var v = EB.view; if (!v || !isPaged()) return;
    measure();
    EB.page = clamp(n, 0, EB.pages - 1);
    var max = Math.max(0, v.scrollWidth - v.clientWidth);
    v.scrollLeft = Math.min(EB.page * layoutMetrics().step, max);
  }

  function turnPage(d) {
    if (!isPaged()) return false;
    measure();
    var next = EB.page + (PRE.dir === 'RTL' ? -d : d);
    if (next < 0) {
      if (EB.ch > 1) { gotoChapter(EB.ch - 1, 1); return true; }
      return false;
    }
    if (next > EB.pages - 1) {
      if (EB.ch < EB.total) { gotoChapter(EB.ch + 1, 0); return true; }
      return false;
    }
    goPage(next);
    queueProgress();
    paintProgressBar();
    return true;
  }

  function applyLayout() {
    var r = $('eb'); if (!r) return;
    var m = layoutMetrics();
    r.style.setProperty('--eb-gut', m.gut + 'px');
    r.style.setProperty('--eb-gap', m.gap + 'px');
    r.style.setProperty('--eb-pagew', m.pw + 'px');
    r.style.setProperty('--eb-vh', viewHeight() + 'px');
    r.classList.toggle('paged', isPaged());
    r.classList.toggle('rtl', PRE.dir === 'RTL');
    if (EB.docEl) EB.docEl.classList.toggle('paged', isPaged());
    if (isPaged()) {
      measure();
      goPage(EB.page);
    } else if (EB.view) {
      EB.view.scrollLeft = 0;
      EB.pages = 1; EB.page = 0;
    }
    paintProgressBar();
  }

  function switchLayout(v) {
    if (PRE.layout === v) return;
    PRE.layout = v;
    savePrefs();
    applyLayout();
    paintBot();
    if (!EB.ready) { paintSet('set'); return; }
    tip(L.t('正在重排'), v === 'scroll' ? L.t('连续滚动') : v === 'double' ? L.t('双栏分页') : L.t('单栏分页'));
    reset(EB.ch, 0).then(function () {
      tip('');
      applyLayout();
      if (isPaged()) requestAnimationFrame(function () { measure(); scrollToSec(EB.secs.get(EB.ch), 0); paintProgressBar(); });
      paintBot();
      paintSet('set');
    }).catch(function () { tip(''); paintSet('set'); });
  }

  var BASE_CSS = [
    ':host{display:block;-webkit-tap-highlight-color:transparent}',
    ':host ::selection{background:rgba(138,109,47,.24)}',
    '::selection{background:rgba(138,109,47,.24)}',
    ':where(.doc){color:var(--eb-tx);-webkit-user-select:none;user-select:none;-webkit-touch-callout:none}',
    '.doc.doc{box-sizing:border-box;max-width:var(--eb-measure);margin:0 auto;padding:0 26px;text-align:justify;' +
    'font-size:var(--eb-fs);line-height:var(--eb-lh);' +
    'word-break:break-word;overflow-wrap:break-word;-webkit-hyphens:auto;hyphens:auto}',
    '.doc .sec{position:relative}',
    '.doc .sec+.sec{margin-top:2.6em}',
    '.doc .sec.artpage{min-height:var(--eb-vh,100vh);background-position:center;background-repeat:no-repeat;' +
    'background-size:contain!important;break-inside:avoid}',
    '.doc.doc.paged .sec.artpage{min-height:100%;break-before:column;break-inside:avoid}',
    '.doc.doc.paged .sec{break-before:column}',
    '.doc.doc.paged .sec:first-child{break-before:auto}',
    '.doc.doc.paged{max-width:none;width:calc(100% - var(--eb-gut,24px) * 2);margin:0 auto;padding:0;height:100%;' +
    'column-width:var(--eb-pagew,600px);column-gap:var(--eb-gap,48px);column-fill:auto}',
    '.doc.doc.paged img,.doc.doc.paged figure,.doc.doc.paged pre,.doc.doc.paged table{break-inside:avoid}',
    '.doc .eb-head{display:flex;align-items:baseline;gap:10px;margin:0 0 1.1em;padding-top:1.1em;' +
    'border-top:1px solid var(--eb-line);color:var(--eb-dim);font-size:.66em;letter-spacing:.05em;user-select:none;text-indent:0}',
    '.doc .sec:first-child .eb-head{border-top:0;padding-top:0}',
    '.doc .eb-head .n{font-family:var(--f-mono);font-size:1.02em;opacity:.75;flex:none}',
    '.doc .eb-head .t{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
    '.doc .eb-head .w{flex:none;opacity:.6;font-family:var(--f-mono);font-size:.94em}',
    '.doc .skel{min-height:320px;border-radius:8px;background:linear-gradient(110deg,var(--eb-sunk) 8%,var(--eb-card) 22%,var(--eb-sunk) 36%);' +
    'background-size:220% 100%;animation:ebshine 1.4s linear infinite}',
    '@keyframes ebshine{0%{background-position:120% 0}100%{background-position:-60% 0}}',
    '.doc.doc p{line-height:var(--eb-lh)}',
    ':where(.doc) p{margin:0 0 var(--eb-para);text-indent:var(--eb-ti)}',
    ':where(.doc) .ct>p:first-child,:where(.doc) h1+p,:where(.doc) h2+p,:where(.doc) h3+p,:where(.doc) .eb-head+p{text-indent:0}',
    '.doc .ct.txt p{line-break:strict;text-justify:inter-ideograph;word-break:normal}',
    '.doc .ct.txt>p:first-child{text-indent:var(--eb-ti)}',
    ':where(.doc) h1,:where(.doc) h2,:where(.doc) h3,:where(.doc) h4,:where(.doc) h5,:where(.doc) h6{' +
    'line-height:1.45;margin:1.2em 0 .7em;text-align:left;text-indent:0;font-weight:600}',
    ':where(.doc) h1{font-size:1.5em}:where(.doc) h2{font-size:1.32em}:where(.doc) h3{font-size:1.16em}',
    '.doc.doc img,.doc.doc svg,.doc.doc video{max-width:100%!important;height:auto!important;display:block;margin:.9em auto}',
    ':where(.doc) figure{margin:1em 0}',
    ':where(.doc) blockquote{margin:.35em 0;padding-left:.9em;border-left:2px solid var(--eb-line)}',
    ':where(.doc) blockquote p{text-indent:0}',
    ':where(.doc) pre,:where(.doc) code{white-space:pre-wrap;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.92em}',
    ':where(.doc) table{max-width:100%;border-collapse:collapse}',
    ':where(.doc) td,:where(.doc) th{padding:2px 6px;border:1px solid currentColor}',
    ':where(.doc) hr{border:0;height:1px;background:currentColor;opacity:.22;margin:1.6em 0}',
    ':where(.doc) a{color:inherit;text-decoration:underline;text-underline-offset:2px;cursor:pointer}',
    ':where(.doc) sup,:where(.doc) sub{font-size:.72em;line-height:0}',
    ':where(.doc) ul,:where(.doc) ol{padding-left:1.4em;margin:0 0 var(--eb-para)}',
    '.doc mark[data-ann]{cursor:pointer;border-radius:2px;color:inherit}',
    '.doc [data-ch]{cursor:pointer}',
    '.doc .eb-ill{cursor:zoom-in}',
    '.doc .eb-ill{background:linear-gradient(110deg,var(--eb-sunk) 8%,var(--eb-card) 22%,var(--eb-sunk) 36%);' +
    'background-size:220% 100%;animation:ebshine 1.4s linear infinite;border-radius:4px;color:var(--eb-dim);' +
    'font-size:.74em;text-align:center;line-height:2.4}',
    '.doc .eb-ill.nosize{aspect-ratio:auto 2/3;min-height:120px;width:100%}',
    '.doc .eb-ill.ok{animation:none;background:none;border-radius:0;min-height:0}',
    '.doc .eb-ill.bad{animation:none;background:var(--eb-sunk);color:var(--eb-dim);font-size:.72em}',
    '::highlight(eb-tts){background-color:rgba(201,162,75,.30);color:inherit}',
    '::highlight(eb-sel){background-color:rgba(138,109,47,.26);color:inherit}',
    '::highlight(eb-find){background-color:rgba(90,150,235,.32);color:inherit}',
    ':where(.doc) .tts-cur{background-color:transparent}',
    '.doc .eb-join{display:flex!important;align-items:center!important;gap:0 14px!important;margin:2.2em 0 0!important;' +
    'padding:0!important;border-top:0!important;font-size:.72em;line-height:1.6;color:var(--eb-dim);' +
    'letter-spacing:.02em;text-indent:0;user-select:none;break-inside:avoid;min-height:0}',
    '.doc .eb-join .j{flex:1 1 0!important;min-width:0;display:block;padding:5px 0;border:0;background:transparent;' +
    'color:inherit;font:inherit;font-size:inherit;letter-spacing:inherit;text-align:left;cursor:pointer;text-indent:0;' +
    'white-space:nowrap;overflow:hidden;text-overflow:ellipsis}',
    '.doc .eb-join .j.r{text-align:right}',
    '.doc .eb-join .j:hover{color:var(--eb-acc)}',
    '.doc .eb-join .j.off{visibility:hidden;cursor:default}',
    '.doc .eb-join .j[disabled]{color:inherit;opacity:.7;cursor:default}',
    '.doc .eb-join .nm{display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}',
    '.doc .eb-join .mid{flex:0 0 auto;display:flex;align-items:center;gap:10px;font-size:.92em;letter-spacing:.22em;' +
    'opacity:.7;white-space:nowrap;text-indent:0}',
    '.doc .eb-join .mid::before,.doc .eb-join .mid::after{content:"";display:block;width:22px;height:1px;' +
    'background:var(--eb-line);flex:0 0 auto}',
    '.doc .eb-join+.sec{margin-top:0}'
  ].join('\n');

  var PUB_LAYOUT_DROP = /^(?:-(?:webkit|moz|ms|o)-)?(position|top|right|bottom|left|inset[\w-]*|margin[\w-]*|padding[\w-]*|width|height|min-[\w-]+|max-[\w-]+|inline-size|block-size|display|float|clear|overflow[\w-]*|column[\w-]*|break-[\w-]+|page-break[\w-]*|z-index|transform[\w-]*|flex[\w-]*|grid[\w-]*|gap|box-sizing|contain|content-visibility|writing-mode|text-orientation|background-attachment)\s*:/i;
  var PUB_ROOT_DROP = /^background[\w-]*\s*:/i;
  var PUB_KEEP_BODY = /^(color|font-style|font-weight)\s*:/i;
  var PUB_CACHE = {};
  var pubSeq = 0;
  var pubKey = '';

  function famCss() {
    return (PRE.font === 'book' ? ':where(.doc)' : '.doc.doc') + '{font-family:var(--eb-fam)}';
  }

  function ensureShadow() {
    var v = $('ebView');
    if (!v) return null;
    if (!v.shadowRoot) {
      EB.shadow = v.attachShadow({ mode: 'open' });
      EB.shadow.innerHTML = '<style id="ebBase"></style><style id="ebPub"></style><article class="doc" id="ebDoc"></article>';
    }
    EB.shadow = v.shadowRoot;
    EB.view = v;
    EB.docEl = EB.shadow.getElementById('ebDoc');
    applyBase();
    applyLayout();
    return EB.shadow;
  }

  function applyBase() {
    if (!EB.shadow) return;
    var st = EB.shadow.getElementById('ebBase');
    if (st) st.textContent = famCss() + '\n' + BASE_CSS;
  }

  function dropDecls(body, root) {
    var safe = body.replace(/(data:[^"')]+)/gi, function (m) { return m.replace(/;/g, '\u0002'); });
    var kept = safe.split(';').filter(function (d) {
      var t = d.trim();
      if (!t || PUB_LAYOUT_DROP.test(t)) return false;
      if (root && PUB_ROOT_DROP.test(t)) return false;
      return true;
    }).map(function (d) {
      return /background/i.test(d) ? d.replace(/\bfixed\b/gi, 'scroll') : d;
    });
    return kept.join(';').replace(/\u0002/g, ';');
  }

  function pubRewrite(css) {
    return String(css || '').replace(/([^{}]+)\{([^{}]*)\}/g, function (m, sel, body) {
      if (sel.indexOf('@') >= 0) return m;
      var root = /(^|[\s,>+~()])html(?=$|[\s,>+~{.#:\[])/i.test(sel);
      var s = sel
        .replace(/(^|[\s,>+~()])html(?=$|[\s,>+~{.#:\[])/gi, '$1:host')
        .replace(/(^|[\s,>+~()])body(?=$|[\s,>+~{.#:\[])/gi, '$1:where(.doc .sec)');
      return s + '{' + dropDecls(body, root) + '}';
    });
  }

  function pubUrls(css, base) {
    return String(css || '').replace(/url\(\s*(['"]?)([^'")]+)\1\s*\)/gi, function (m, q, u) {
      if (/^(data:|https?:|\/\/|#)/i.test(u)) return m;
      try { return 'url("' + new URL(u, base).href + '")'; } catch (e) { return m; }
    });
  }

  var PUB_IMPORT = /@import\s+(?:url\(\s*(['"]?)([^'")]+)\1\s*\)|(['"])([^'"]+)\3)\s*[^;]*;/gi;

  function fetchPub(href, depth) {
    var abs;
    try { abs = new URL(href, location.href).href; } catch (e) { abs = href; }
    if (PUB_CACHE[abs]) return PUB_CACHE[abs];
    PUB_CACHE[abs] = fetch(abs, { credentials: 'same-origin' })
      .then(function (r) { return r.ok ? r.text() : ''; })
      .then(function (text) {
        if (!text) return '';
        var jobs = [];
        var body = text.replace(PUB_IMPORT, function (m, q1, u1, q2, u2) {
          var raw = u1 || u2 || '';
          if (!raw || /^(data:|https?:|\/\/)/i.test(raw) || (depth || 0) >= 3) return '';
          var next;
          try { next = new URL(raw, abs).href; } catch (e) { return ''; }
          jobs.push(fetchPub(next, (depth || 0) + 1));
          return '\u0001' + (jobs.length - 1) + '\u0001';
        });
        return Promise.all(jobs).then(function (list) {
          var merged = body.replace(/\u0001(\d+)\u0001/g, function (m, i) { return list[+i] || ''; });
          return pubRewrite(pubUrls(merged, abs));
        });
      })
      .catch(function () { return ''; });
    return PUB_CACHE[abs];
  }

  function clearPub(sh) {
    [].slice.call(sh.querySelectorAll('style[data-eb],link[data-eb]')).forEach(function (n) { n.remove(); });
  }

  function syncPub() {
    if (!EB.shadow) return;
    var sh = EB.shadow;
    var seq = ++pubSeq;
    if (!PRE.pubcss) { pubKey = ''; clearPub(sh); return; }
    var inl = EB.inlines.map(pubRewrite);
    var links = EB.links.slice();
    Promise.all(links.map(function (h) { return fetchPub(h, 0); })).then(function (list) {
      if (seq !== pubSeq || !EB.shadow || !PRE.pubcss) return;
      var css = list.filter(Boolean).concat(inl).filter(Boolean);
      var key = css.join('\u0000');
      if (key === pubKey) return;
      pubKey = key;
      clearPub(sh);
      var anchor = sh.getElementById('ebPub') || sh.getElementById('ebDoc');
      if (!anchor || !anchor.parentNode) return;
      css.forEach(function (t) {
        var s = document.createElement('style');
        s.textContent = t;
        s.setAttribute('data-eb', '1');
        anchor.parentNode.insertBefore(s, anchor);
      });
    });
  }

  function applySafe() {
    var r = $('eb');
    if (!r) return;
    r.style.setProperty('--eb-safe-t', SAFE.t + 'px');
    r.style.setProperty('--eb-safe-b', SAFE.b + 'px');
    measureChrome();
  }

  function measureChrome() {
    var r = $('eb'), t = $('ebTop'), b = $('ebBot');
    if (!r) return;
    if (t && t.offsetHeight) r.style.setProperty('--eb-top-h', t.offsetHeight + 'px');
    if (b && b.offsetHeight) r.style.setProperty('--eb-bot-h', b.offsetHeight + 'px');
  }

  function mount() {
    var r = $('eb');
    if (r) return r;
    r = el('div', 'eb');
    r.id = 'eb';
    r.innerHTML =
      '<div class="eb-bg"></div>' +
      '<div class="eb-edge l" id="ebEdgeL"></div>' +
      '<div class="eb-edge r" id="ebEdgeR"></div>' +
      '<div class="eb-view" id="ebView"></div>' +
      '<div class="eb-top" id="ebTop"></div>' +
      '<div class="eb-bot" id="ebBot"></div>' +
      '<div class="eb-panel" id="ebToc"></div>' +
      '<div class="eb-panel" id="ebSet"></div>' +
      '<div class="eb-sel" id="ebSel"></div>' +
      '<div class="eb-hands" id="ebHands"><i class="hs"></i><i class="he"></i></div>' +
      '<div class="eb-lb" id="ebLb"><img id="ebLbImg" alt=""></div>' +
      '<div class="eb-ask" id="ebAsk"></div>' +
      '<div class="eb-toast" id="ebToast"></div>' +
      '<div class="eb-tip" id="ebTip"></div>' +
      '<div class="eb-cap" id="ebCap"></div>';
    document.body.appendChild(r);
    applySafe();
    r.addEventListener('mousemove', touchIdle);
    r.addEventListener('pointerdown', touchIdle, { passive: true });
    $('ebLb').addEventListener('click', function () { $('ebLb').classList.remove('on'); });
    $('ebView').addEventListener('scroll', onScroll, { passive: true });
    var hb = $('ebHands');
    if (hb) {
      hb.addEventListener('pointerdown', function (ev) {
        var t = ev.target;
        var cls = t && t.classList ? t.classList : null;
        if (!cls) return;
        if (cls.contains('hs')) handDown('start', ev);
        else if (cls.contains('he')) handDown('end', ev);
      }, { passive: false });
    }
    document.addEventListener('pointermove', function (ev) {
      if (EB.selMode !== 'start' && EB.selMode !== 'end') return;
      if (ev.cancelable) ev.preventDefault();
      dragHand(ev.clientX, ev.clientY);
    }, { passive: false });
    document.addEventListener('pointerup', function () {
      if (EB.selMode === 'start' || EB.selMode === 'end') ttsHoldEnd();
    }, { passive: true });
    document.addEventListener('pointercancel', function () {
      if (EB.selMode === 'start' || EB.selMode === 'end') ttsHoldEnd();
    }, { passive: true });
    bindTapZones();
    document.addEventListener('keydown', onKey);
    var rz = null;
    window.addEventListener('resize', function () {
      if (!EB.open) return;
      clearTimeout(rz);
      rz = setTimeout(function () {
        applySafe();
        applyLayout();
        if (GD.open) guideGo(GD.step);
      }, 160);
    });
    if (window.speechSynthesis) {
      window.speechSynthesis.onvoiceschanged = function () {
        if (EB.panel === 'set') fillVoices();
      };
    }
    watchUi();
    return r;
  }

  var lastUi = '';

  function uiSnapshot() {
    var r = $('eb'), lb = $('ebLb'), ask = $('ebAsk'), sel = $('ebSel'), gd = $('ebGuide');
    return {
      open: !!EB.open,
      panel: EB.panel || '',
      sel: !!(sel && sel.classList.contains('on')),
      lb: !!(lb && lb.classList.contains('on')),
      ask: !!(ask && ask.classList.contains('on')),
      guide: !!(gd && gd.classList.contains('on')),
      idle: !r || r.classList.contains('idle')
    };
  }

  function postUi() {
    syncCap();
    if (!window.lantaiBridge || !window.lantaiBridge.report) return;
    var ui = uiSnapshot();
    var key = (ui.open ? '1' : '0') + ui.panel + (ui.sel ? '1' : '0') + (ui.lb ? '1' : '0') +
      (ui.ask ? '1' : '0') + (ui.guide ? '1' : '0') + (ui.idle ? '1' : '0');
    if (key === lastUi) return;
    lastUi = key;
    try { window.lantaiBridge.report(JSON.stringify({ ui: ui })); } catch (e) { }
  }

  function watchUi() {
    if (!window.MutationObserver) return;
    var mo = new MutationObserver(function () { postUi(); });
    ['eb', 'ebLb', 'ebAsk', 'ebSel', 'ebToc', 'ebSet', 'ebGuide'].forEach(function (id) {
      var n = $(id);
      if (n) mo.observe(n, { attributes: true, attributeFilter: ['class'] });
    });
    postUi();
  }

  function armIdle() {
    var r = $('eb'); if (!r) return;
    clearTimeout(EB.idle);
    EB.idle = setTimeout(function () {
      if (!EB.open) return;
      if (EB.panel || EB.selRange || EB.seeking != null || GD.open) return;
      r.classList.add('idle');
    }, 3200);
  }

  function bumpIdle() {
    var r = $('eb'); if (!r) return;
    r.classList.remove('idle');
    armIdle();
  }

  function touchIdle() {
    var r = $('eb'); if (!r) return;
    if (r.classList.contains('idle')) return;
    armIdle();
  }

  function toggleChrome() {
    var r = $('eb'); if (!r) return;
    clearSel();
    if (r.classList.contains('idle')) { bumpIdle(); return; }
    clearTimeout(EB.idle);
    r.classList.add('idle');
  }

  function capText() {
    var v = volInfo(EB.ch);
    var s = '';
    if (v) s += L.t('卷 ') + v.i + '/' + v.total + ' · ';
    s += L.t('章 ') + EB.ch + '/' + num(EB.total);
    if (v) s += ' · ' + L.t('节 ') + v.j + '/' + v.count;
    return s + ' · ' + (totalProgress() * 100).toFixed(2) + '%';
  }

  function syncCap() {
    var c = $('ebCap'), r = $('eb');
    if (!c || !r) return;
    var lb = $('ebLb'), ask = $('ebAsk');
    var show = r.classList.contains('idle') && (!GD.open || GD.cap) && !EB.panel && !EB.selRange &&
      !EB.ttsOn && !(lb && lb.classList.contains('on')) &&
      !(ask && ask.classList.contains('on'));
    if (show) {
      var txt = capText();
      if (c.dataset.txt !== txt) { c.dataset.txt = txt; c.textContent = txt; }
    }
    c.classList.toggle('on', show);
  }

  function sideTurn(d) {
    if (isPaged()) { turnPage(d); return; }
    var v = $('ebView');
    if (!v) return;
    v.scrollBy({ top: d * v.clientHeight * 0.88, behavior: 'smooth' });
    queueProgress();
  }

  var tapAt = null;

  function pathHas(ev, cls) {
    var p = ev.composedPath ? ev.composedPath() : [];
    for (var i = 0; i < p.length; i++) {
      if (p[i] && p[i].classList && p[i].classList.contains(cls)) return true;
    }
    return false;
  }

  function bindTapZones() {
    var view = $('ebView');
    if (!view || view.dataset.tapbound) return;
    view.dataset.tapbound = '1';
    view.addEventListener('pointerdown', function (ev) {
      if (!EB.open || (ev.button != null && ev.button > 0)) { tapAt = null; return; }
      tapAt = { x: ev.clientX, y: ev.clientY };
      ttsHoldStart(ev.clientX, ev.clientY);
    }, { passive: true });
    view.addEventListener('pointermove', function (ev) {
      ttsHoldMove(ev.clientX, ev.clientY);
    }, { passive: true });
    view.addEventListener('touchmove', function (ev) {
      if (EB.selMode && ev.cancelable) ev.preventDefault();
    }, { passive: false });
    view.addEventListener('pointerup', function () {
      ttsHoldEnd();
      setTimeout(function () { EB.holdFired = false; }, 400);
    }, { passive: true });
    view.addEventListener('pointercancel', function () {
      ttsHoldEnd();
    }, { passive: true });
    view.addEventListener('click', function (ev) {
      if (!EB.open) return;
      if (EB.holdFired) { EB.holdFired = false; tapAt = null; return; }
      if (GD.open) { tapAt = null; return; }
      if (pathHas(ev, 'eb-join')) { tapAt = null; return; }
      var d = tapAt;
      tapAt = null;
      if (!d) return;
      if (Math.abs(ev.clientX - d.x) > 8 || Math.abs(ev.clientY - d.y) > 8) return;
      if (ev.target.closest && ev.target.closest('.eb-top,.eb-bot,.eb-panel,.eb-sel,.eb-ask,.eb-lb,.eb-toast,.eb-tip,.eb-edge,.eb-join')) return;
      if (EB.panel) { closePanels(); bumpIdle(); return; }
      if (EB.selRange) { clearSel(); bumpIdle(); return; }
      var a = ev.target.closest ? ev.target.closest('a[href]') : null;
      if (a) {
        if (ev.ctrlKey || ev.metaKey) return;
        if (!PRE.tapAny) return;
      }
      var w = window.innerWidth, x = ev.clientX;
      ev.preventDefault();
      ev.stopPropagation();
      if (x > w * 0.72) return sideTurn(1);
      if (x < w * 0.28) return sideTurn(-1);
      toggleChrome();
    }, true);
    var l = $('ebEdgeL'), r = $('ebEdgeR');
    if (l) l.onclick = function (ev) { ev.preventDefault(); ev.stopPropagation(); edgeTap(-1); };
    if (r) r.onclick = function (ev) { ev.preventDefault(); ev.stopPropagation(); edgeTap(1); };
  }

  function nodeIndexOf(nodes, node, off) {
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i].node === node) return nodes[i].start + (off || 0);
    }
    return -1;
  }

  function flatOf(block) {
    var nodes = nodePoints(block);
    var flat = '';
    for (var i = 0; i < nodes.length; i++) flat += (nodes[i].node.nodeValue || '');
    return { nodes: nodes, flat: flat };
  }

  function caretInElement(el, x, y) {
    var nodes = nodePoints(el);
    if (!nodes.length) return null;
    var total = 0;
    for (var i = 0; i < nodes.length; i++) total += (nodes[i].node.nodeValue || '').length;
    if (!total) return null;
    var lo = 0, hi = total;
    while (lo < hi) {
      var mid = (lo + hi) >> 1;
      var pt0 = pointAt(nodes, mid);
      var r = document.createRange();
      try {
        r.setStart(pt0.node, pt0.offset);
        r.collapse(true);
      } catch (e) { return null; }
      var rect = r.getBoundingClientRect();
      if (!rect || (!rect.width && !rect.height)) { lo = mid + 1; continue; }
      var above = rect.bottom < y;
      var sameLine = !above && rect.top <= y;
      var leftHalf = sameLine && rect.left + rect.width * 0.5 < x;
      if (above || leftHalf) lo = mid + 1;
      else hi = mid;
    }
    return pointAt(nodes, Math.min(lo, total));
  }

  function lineHits(block, x, y) {
    var r = document.createRange();
    try { r.selectNodeContents(block); } catch (e) { return false; }
    var rects = r.getClientRects();
    var hit = false;
    for (var i = 0; i < rects.length; i++) {
      var b = rects[i];
      if (!b || !b.width || !b.height) continue;
      if (y >= b.top - 3 && y <= b.bottom + 3 && x >= b.left - 4 && x <= b.right + 8) { hit = true; break; }
    }
    return hit;
  }

  function textPointAt(x, y) {
    var el = null;
    try {
      if (EB.shadow && typeof EB.shadow.elementFromPoint === 'function') el = EB.shadow.elementFromPoint(x, y);
    } catch (e) { el = null; }
    if (!el) return null;
    var block = el.closest ? el.closest(BLOCK_SEL) : null;
    if (!block) return null;
    if (!lineHits(block, x, y)) return null;
    var p = caretInElement(block, x, y);
    if (!p || !p.node || p.node.nodeType !== 3) return null;
    return p;
  }

  var WORD_BRK = /[\s\u00a0，。！？；：、,.!?;:…—·（）()《》〈〉「」『』【】“”‘’"']/;
  var segMaker = null;
  var segDead = false;

  function segmenterOf() {
    if (segMaker !== null || segDead) return segMaker;
    try {
      if (window.Intl && typeof Intl.Segmenter === 'function') segMaker = new Intl.Segmenter('zh', { granularity: 'word' });
      else segDead = true;
    } catch (e) {
      segDead = true;
      segMaker = null;
    }
    return segMaker;
  }

  function wordSpan(flat, at) {
    var s = at, e = at + 1;
    var sg = segmenterOf();
    var hit = null;
    if (sg) {
      try {
        var it = sg.segment(flat);
        if (typeof it.containing === 'function') {
          hit = it.containing(at);
        } else {
          var list = [];
          it.forEach(function (x) { list.push(x); });
          for (var i = 0; i < list.length; i++) {
            if (at >= list[i].index && at < list[i].index + list[i].segment.length) { hit = list[i]; break; }
          }
        }
      } catch (err) { hit = null; }
    }
    if (hit && hit.segment) {
      s = hit.index;
      e = hit.index + hit.segment.length;
    } else {
      while (s > 0 && !WORD_BRK.test(flat.charAt(s - 1))) s--;
      while (e < flat.length && !WORD_BRK.test(flat.charAt(e))) e++;
      if (e - s > 4) { s = at; e = at + 1; }
    }
    return { s: s, e: e };
  }

  function wordRangeAt(p) {
    if (!p || !p.node) return null;
    var el = p.node.nodeType === 3 ? p.node.parentNode : p.node;
    var block = el && el.closest ? el.closest(BLOCK_SEL) : null;
    if (!block) return null;
    var fp = flatOf(block);
    if (!fp.flat.length) return null;
    var at = nodeIndexOf(fp.nodes, p.node, p.offset);
    if (at < 0) return null;
    if (at >= fp.flat.length) at = fp.flat.length - 1;
    if (/[\s\u00a0]/.test(fp.flat.charAt(at))) return null;
    var sp = wordSpan(fp.flat, at);
    var a = pointAt(fp.nodes, sp.s), b = pointAt(fp.nodes, sp.e);
    if (!a || !b) return null;
    var r = document.createRange();
    try {
      r.setStart(a.node, a.offset);
      r.setEnd(b.node, b.offset);
    } catch (e) { return null; }
    return r.collapsed ? null : r;
  }

  var selHL = null;

  function paintSelRange(range) {
    if (!range) return;
    EB.selRange = range;
    if (window.CSS && CSS.highlights && typeof window.Highlight === 'function') {
      if (!selHL) selHL = new window.Highlight();
      selHL.clear();
      selHL.add(range);
      CSS.highlights.set('eb-sel', selHL);
    }
  }

  function clearSelPaint() {
    try {
      if (window.CSS && CSS.highlights && CSS.highlights.has('eb-sel')) CSS.highlights.delete('eb-sel');
    } catch (e) { }
    selHL = null;
    EB.selRange = null;
  }

  function pt(node, off) {
    return { node: node, offset: off || 0 };
  }

  function cmpPt(a, b) {
    if (!a || !b) return 0;
    if (a.node === b.node) return a.offset === b.offset ? 0 : (a.offset < b.offset ? -1 : 1);
    var pos = a.node.compareDocumentPosition(b.node);
    if (pos & 4) return -1;
    if (pos & 2) return 1;
    return 0;
  }

  function buildRange(a, b) {
    if (!a || !b || !a.node || !b.node) return null;
    var r = document.createRange();
    try {
      if (cmpPt(a, b) <= 0) {
        r.setStart(a.node, a.offset);
        r.setEnd(b.node, b.offset);
      } else {
        r.setStart(b.node, b.offset);
        r.setEnd(a.node, a.offset);
      }
    } catch (e) { return null; }
    return r.collapsed ? null : r;
  }

  function setSel(a, b) {
    var r = buildRange(a, b);
    if (!r) return false;
    paintSelRange(r);
    placeHands(r);
    showSelBox(r);
    return true;
  }

  function ttsHoldStart(x, y) {
    ttsHoldEnd();
    if (EB.panel || !EB.open) return;
    EB.holdAt = { x: x, y: y };
    EB.holdTimer = setTimeout(function () {
      EB.holdTimer = -1;
      var p = EB.holdAt;
      EB.holdAt = null;
      if (!p || !EB.open) return;
      var at = textPointAt(p.x, p.y);
      if (!at) return;
      var r = wordRangeAt(at);
      if (!r) return;
      EB.selMore = false;
      EB.holdFired = true;
      EB.selMode = 'word';
      EB.selFix = pt(r.startContainer, r.startOffset);
      setSel(EB.selFix, pt(r.endContainer, r.endOffset));
    }, 260);
  }

  function ttsHoldMove(x, y) {
    if (EB.selMode === 'word') {
      if (!EB.selFix) return;
      var p = textPointAt(x, y);
      if (p) setSel(EB.selFix, p);
      return;
    }
    var a = EB.holdAt;
    if (!a) return;
    if (Math.abs(x - a.x) > 10 || Math.abs(y - a.y) > 10) ttsHoldEnd();
  }

  function dragHand(x, y) {
    if (!EB.selFix) return;
    var p = textPointAt(x, y);
    if (!p) return;
    setSel(p, EB.selFix);
  }

  function handDown(which, ev) {
    if (!EB.selRange) return;
    ev.preventDefault();
    ev.stopPropagation();
    EB.selMode = which;
    EB.holdFired = true;
    EB.selFix = which === 'start'
      ? pt(EB.selRange.endContainer, EB.selRange.endOffset)
      : pt(EB.selRange.startContainer, EB.selRange.startOffset);
  }

  function ttsHoldEnd() {
    if (EB.holdTimer >= 0) {
      clearTimeout(EB.holdTimer);
      EB.holdTimer = -1;
    }
    EB.holdAt = null;
    EB.selMode = '';
    EB.selFix = null;
  }

  function ttsAnchorOf(node, off) {
    if (!node) return null;
    var el = node.nodeType === 3 ? node.parentNode : node;
    if (!el || !el.closest) return null;
    var sec = el.closest('.sec');
    if (!sec) return null;
    var ch = +sec.dataset.ch || EB.ch;
    var block = el.closest(BLOCK_SEL) || el;
    var list = null;
    if (ch === EB.ch && EB.tts && EB.ttsOn && EB.tts.list && EB.tts.list.length) {
      var f = EB.tts.list[0].el;
      if (f && sec.contains(f)) list = EB.tts.list;
    }
    if (!list) list = ttsSegments(sec);
    if (!list || !list.length) return null;
    var i, best = -1;
    for (i = 0; i < list.length; i++) {
      if (!list[i] || list[i].el !== block) continue;
      var inner = nodeIndexOf(list[i].nodes, node, off || 0);
      if (inner < 0) continue;
      best = i;
      if (list[i].e >= inner) return { ch: ch, idx: i };
    }
    if (best >= 0) return { ch: ch, idx: best };
    for (i = 0; i < list.length; i++) {
      var lb = list[i].el;
      if (!lb) continue;
      if (lb.contains(block)) return { ch: ch, idx: i };
      if (block.compareDocumentPosition(lb) & 4) return { ch: ch, idx: i };
    }
    return { ch: ch, idx: list.length - 1 };
  }

  function edgeTap(d) {
    if (EB.panel) { closePanels(); bumpIdle(); return; }
    if (EB.selRange) { clearSel(); bumpIdle(); return; }
    sideTurn(d);
  }

  var GUIDE_KEY = 'lantai-ebook-guide';
  var guideBooted = false;

  var GSTEPS = [
    {
      sel: '[data-a="exit"]', g: '顶栏', t: '返回', pos: 'bottom',
      d: '左上角退出阅读器，回到书架或详情页。进度已经存下来了，下次打开直接续上。操作栏自动收起时，先点屏幕中间把它叫出来。'
    },
    {
      sel: '.eb-title', g: '顶栏', t: '书名与章节', pos: 'bottom',
      d: '上面一行是书名，下面一行是当前章名与「第 n / N 章」，翻页时跟着变。开启隐身阅读时书名后会多一个「隐身」标记。'
    },
    {
      sel: '#ebTop [data-a="guide"]', g: '顶栏', t: '操作指引', pos: 'bottom',
      d: '右上角这个键随时重看这套引导。第一次打开一本书会自动演示一遍，之后不再自动弹出；顶栏收起时先点屏幕中间把它叫出来。'
    },
    {
      sel: '#ebBot .eb-acts', g: '底栏', t: '功能栏', pos: 'top',
      d: '五个入口并排在底栏最下一排：目录、全书搜索、标注与笔记、朗读、阅读设置，点一下直接展开对应面板，不再经一层转发。当前面板对应的键位变金色。'
    },
    {
      sel: '#ebBot [data-a="toc"]', g: '底栏', t: '目录', pos: 'top',
      d: '底栏最左侧第一个键打开目录面板。全书按卷 / 节两级列出，当前章高亮，点任意一行立刻跳过去。再点一次这个键收起。'
    },
    {
      sel: '#ebTocQ', g: '目录', t: '目录 · 搜索框', pos: 'bottom', panel: 'toc',
      d: '按章节名筛选，边输边过滤，只匹配标题、不搜正文。清空输入框恢复完整目录。'
    },
    {
      sel: '#ebTocList .eb-toc-i.on', g: '目录', t: '目录 · 章节列表', pos: 'top', panel: 'toc',
      d: '卷标题用「卷」标注，节显示章号；右侧数字是本章字数，一万以上按「万」显示。当前章高亮并自动滚到屏幕中间。'
    },
    {
      sel: '#ebToc .eb-panel-h', g: '目录', t: '目录 · 关闭', pos: 'bottom', panel: 'toc',
      d: '右上角叉号关闭目录。也可以点面板外的空白处，或按系统返回键 —— 返回键会先关面板，不会直接退出阅读器。'
    },
    {
      sel: '#ebBot [data-a="find"]', g: '底栏', t: '全书搜索', pos: 'top',
      d: '第二个键打开全书搜索，跨全书所有章节搜正文关键词。首次搜索要现建索引，可能慢几秒，之后会快很多。'
    },
    {
      sel: '#ebSet .eb-search', g: '底栏', t: '搜索 · 展开态', pos: 'bottom', panel: 'find',
      d: '输入关键词后回车开始搜。结果按章节列出、命中词高亮，顶部显示命中总处数与涉及章数；点一条直接跳到那一段。'
    },
    {
      sel: '#ebBot [data-a="ann"]', g: '底栏', t: '标注与笔记', pos: 'top',
      d: '第三个键列出全书所有书签、高亮与笔记，按章节顺序排，点一条跳回原文位置。'
    },
    {
      sel: '#ebSet .eb-seg', g: '底栏', t: '标注 · 展开态', pos: 'bottom', panel: 'ann',
      d: '三档筛选：全部 / 书签 / 标注，标题栏右侧显示书签与标注各多少条。'
    },
    {
      sel: '#ebSet [data-bmadd]', g: '底栏', t: '加书签', pos: 'bottom', panel: 'ann',
      d: '这一行是「给第 N 章加书签」，点一下把当前章节位置记下来。同一章只会有一个书签，重复加会提示已存在。'
    },
    {
      sel: '#ebBot [data-a="tts"]', g: '底栏', t: '朗读', pos: 'top',
      d: '第四个键开始朗读本章，从上次听到的那一句接着读，不是从头。长按这一键＝从当前屏幕第一句开始；长按正文任意位置＝从那条金色虚线处开始，只剩几句没听完时用这两个最快。屏幕浮出朗读球，球面是封面中央，金环是本章进度，播放中球外有一圈微光。点球展开控制条：左端封面圆点收回，中间是上一句、播放 / 暂停、下一句与页码，「音色」切音色，末尾 × 关闭。整条可拖动，松手吸附到最近的边，展开 2 秒无操作会自动收回并贴边。当前句金色高亮并自动滚动，读完本章自动接下章，退出阅读器回到书架也继续播，只有点 × 才彻底结束。语速、语气、语调、间隙与音色在阅读设置里。'
    },
    {
      sel: '#ebBot [data-a="set"]', g: '底栏', t: '阅读设置', pos: 'top',
      d: '第五个键展开设置面板，分五组：底色、排版、翻页、朗读、阅读。改动即时生效并记住，下面逐个说。'
    },
    {
      sel: '#ebSet .eb-swatches', g: '设置', t: '底色', pos: 'bottom', panel: 'set',
      d: '五档：纸白、牛皮纸、护眼、墨黑、夜间。点圆点直接换，正文与工具栏配色会一起变。'
    },
    {
      sel: '#ebSet [data-sz="-1"]', also: ['#ebSet [data-sz="1"]'], g: '设置', t: '排版', pos: 'bottom', panel: 'set',
      d: '字号 A- / A+ 逐级调（13~32）；下面依次是行距紧中松、段距窄中宽、字体、首行缩进开关、版心（每行字数，26~64）、原书样式。'
    },
    {
      sel: '#ebSet [data-lt="scroll"]', also: ['#ebSet [data-lt="double"]'], g: '设置', t: '翻页', pos: 'bottom', panel: 'set',
      d: '连续滚动上下滑；单栏分页一屏一页；双栏分页一屏两栏。方向（从左往右 / 从右往左）只在分页模式生效；点按翻页打开后，左右区域点一下即翻页。'
    },
    {
      sel: '#ebSet [data-tr]', also: ['#ebSet [data-ts]', '#ebSet [data-tp]', '#ebSet [data-tg]'],
      g: '设置', t: '朗读', pos: 'bottom', panel: 'set',
      d: '语气四档是整段听感的主开关：平实不加修饰；沉稳放慢压低；轻快稍快提亮；讲述最慢、音高与音量略抬，适合小说。语调在语气之上再压一档高低，间隙把全篇停顿一起收紧或放宽。这三项随时可改，正在读的会从当前这句按新参数重来，不跳句也不停。自动语气打开后按标点、句长与段落安排停顿与轻重，不识别语义，偏保守但对话多的段落明显自然；关掉就是一律平的旧读法。强调让叠词与拟声词轻微加重，依赖自动语气。音色只列系统里已安装的发音人，切换时同样从当前句续上。'
    },
    {
      sel: '#ebSet [data-sw="wake"]', g: '设置', t: '阅读', pos: 'bottom', panel: 'set',
      d: '屏幕常亮：阅读时不熄屏。隐身阅读：本次不写进度、不上报时长，也不会出现在统计里。'
    },
    {
      sel: '#ebSet [data-guide="1"]', g: '设置', t: '重看指引', pos: 'bottom', panel: 'set',
      d: '设置面板最底部的「重新观看」，点一下回到当前这个引导。'
    },
    {
      sel: '#ebBot .eb-bot-r', g: '底栏', t: '读数', pos: 'top',
      d: '三组读数：卷 / 节位置、本章进度、全书百分比。手机宽度下上一章 / 下一章按钮会隐藏，翻页请用左右轻点或进度条。'
    },
    {
      sel: '#ebTrack', g: '底栏', t: '进度条', pos: 'top',
      d: '拖动时三组读数实时预览目标位置，松手才跳；点轨道任意位置也直接跳。拖到别的章时，本章进度会显示为「—」。'
    },
    {
      sel: '#ebCap', g: '底栏', t: '收起态胶囊', pos: 'top', cap: true,
      d: '操作栏收起后，屏幕底部留一枚半透明胶囊，按卷 / 章 / 节与全书百分比显示进度。它不挡正文，也不拦点击 —— 点它等于点正文。'
    },
    {
      zones: [
        { z: 'l', t: '左侧 28%', n: '往回一屏', r: '0 – 28%' },
        { z: 'c', t: '中间 44%', n: '唤出 / 收起', r: '28% – 72%' },
        { z: 'r', t: '右侧 28%', n: '往前一屏', r: '72% – 100%' }
      ],
      g: '交互', t: '三区轻点', pos: 'topbar',
      d: '左 28% 往回、右 28% 往前、只有中间 44% 能唤出或收起操作栏。连续滚动时左右各滚近一屏；切到单栏 / 双栏翻页后，左右各翻一页。翻页与上下滚动都不会把操作栏叫出来。'
    },
    {
      g: '交互', t: '选中与标注', pos: 'topbar',
      d: '长按正文选中文字，浮出四色高亮、下划线、写笔记、复制、朗读这段。选中期间点左右两侧不会误翻页，轻点空白处先取消选中。'
    },
    {
      g: '交互', t: '章末续读', pos: 'topbar',
      d: '每章末尾有「上一章 · 本章完 · 下一章」接续条；在线书读到最后还能直接续到下一本。随时可在顶栏右上角的「指引」重看本引导。'
    }
  ];

  var GD = { open: false, step: 0, settle: null, settle2: null, panel: null, cap: false };

  function guideEl() {
    var host = $('eb');
    if (!host) return null;
    var g = $('ebGuide');
    if (g) return g;
    g = el('div', 'eb-guide');
    g.id = 'ebGuide';
    g.innerHTML =
      '<div class="eb-g-mask" data-gmask></div>' +
      '<div class="eb-g-hole" data-ghole></div>' +
      '<div class="eb-g-zone" data-gzone></div>' +
      '<div class="eb-g-bub" data-gbub data-dir="bottom">' +
      '<div class="eb-g-step" data-gstep></div>' +
      '<b class="eb-g-t" data-gt></b>' +
      '<p class="eb-g-d" data-gd></p>' +
      '<div class="eb-g-f"><button class="eb-g-skip" data-gskip type="button"></button>' +
      '<div class="eb-g-nav"><button data-gprev type="button"></button>' +
      '<button class="primary" data-gnext type="button"></button></div></div></div>';
    host.appendChild(g);
    var block = function (ev) { ev.stopPropagation(); ev.preventDefault(); };
    ['pointerdown', 'pointerup', 'click', 'dblclick', 'contextmenu', 'touchstart', 'touchmove', 'touchend'].forEach(function (t) {
      g.querySelector('[data-gmask]').addEventListener(t, block, { passive: false });
      g.querySelector('[data-gzone]').addEventListener(t, block, { passive: false });
      g.querySelector('[data-ghole]').addEventListener(t, block, { passive: false });
    });
    ['pointerdown', 'pointerup', 'click', 'dblclick'].forEach(function (t) {
      g.querySelector('[data-gbub]').addEventListener(t, block);
    });
    g.querySelector('[data-gzone]').addEventListener('click', guideZone);
    g.querySelector('[data-gskip]').onclick = function (ev) { ev.stopPropagation(); closeGuide(true); };
    g.querySelector('[data-gprev]').onclick = function (ev) { ev.stopPropagation(); guideGo(GD.step - 1); };
    g.querySelector('[data-gnext]').onclick = function (ev) { ev.stopPropagation(); guideNext(); };
    return g;
  }

  function guideFill(g) {
    var hole = g.querySelector('[data-ghole]');
    if (!hole) return;
    hole.classList.add('nofx', 'flat', 'on');
    hole.style.left = '0px';
    hole.style.top = '0px';
    hole.style.width = '100%';
    hole.style.height = '100%';
    void hole.offsetWidth;
    hole.classList.remove('nofx');
  }

  function guideBands() {
    var t = $('ebTop'), b = $('ebBot');
    return '<div class="eb-g-band top"><span class="eb-g-chip"><b>' + L.t('顶栏 · 按钮区') + ' · ' +
      (t ? t.offsetHeight : 0) + 'px</b><small>' + L.t('自动隐藏，点按钮不翻页') + '</small></span></div>' +
      '<div class="eb-g-band bot"><span class="eb-g-chip"><b>' + L.t('底栏 · 进度与功能') + ' · ' +
      (b ? b.offsetHeight : 0) + 'px</b><small>' + L.t('拖动定位，点键开面板') + '</small></span></div>';
  }

  function guideZones(list) {
    return list.map(function (z) {
      return '<i class="' + z.z + '" data-z="' + z.z + '">' + (z.r ? '<em>' + z.r + '</em>' : '') +
        '<b>' + esc(z.t) + '</b><span>' + esc(z.n) + '</span></i>';
    }).join('');
  }

  function guideHostRect(host, sels) {
    var hr = host.getBoundingClientRect();
    var out = null;
    for (var i = 0; i < sels.length; i++) {
      var nodes = host.querySelectorAll(sels[i]);
      for (var j = 0; j < nodes.length; j++) {
        var b = nodes[j].getBoundingClientRect();
        if (!b.width && !b.height) continue;
        var r = { left: b.left - hr.left, top: b.top - hr.top, right: b.right - hr.left, bottom: b.bottom - hr.top };
        out = out ? {
          left: Math.min(out.left, r.left), top: Math.min(out.top, r.top),
          right: Math.max(out.right, r.right), bottom: Math.max(out.bottom, r.bottom)
        } : r;
      }
    }
    if (!out) return null;
    out.width = out.right - out.left;
    out.height = out.bottom - out.top;
    return out;
  }

  function guidePlace(g, host, s) {
    var bub = g.querySelector('[data-gbub]');
    var hole = g.querySelector('[data-ghole]');
    if (!bub || !hole) return;
    var hr = host.getBoundingClientRect();
    var r = s.sel ? guideHostRect(host, [s.sel].concat(s.also || [])) : null;
    var W = hr.width, H = hr.height, pad = 7, gap = 22, edge = 12;
    bub.classList.add('nofx');
    hole.classList.add('nofx');
    if (r) {
      hole.classList.remove('flat');
      hole.style.left = (r.left - pad) + 'px';
      hole.style.top = (r.top - pad) + 'px';
      hole.style.width = (r.width + pad * 2) + 'px';
      hole.style.height = (r.height + pad * 2) + 'px';
      hole.classList.add('on');
    } else {
      hole.classList.add('flat', 'on');
      hole.style.left = '0px';
      hole.style.top = '0px';
      hole.style.width = '100%';
      hole.style.height = '100%';
    }
    var bw = bub.offsetWidth, bh = bub.offsetHeight;
    var pos = s.pos || 'auto', top, left, ax, dir = pos;
    if (pos === 'topbar') {
      top = Math.max(edge, SAFE.t + 62);
      left = clamp(W / 2 - bw / 2, edge, W - bw - edge);
      dir = 'none'; ax = '50%';
    } else if (!r) {
      top = H - bh - 120;
      left = clamp(W / 2 - bw / 2, edge, W - bw - edge);
      dir = 'none'; ax = '50%';
    } else {
      var below = H - r.bottom - SAFE.b - edge, above = r.top - SAFE.t - edge;
      if (dir === 'auto') dir = (below >= bh + gap || below >= above) ? 'bottom' : 'top';
      if (dir === 'bottom' && below < bh + gap && above > bh + gap) dir = 'top';
      if (dir === 'top' && above < bh + gap && below > bh + gap) dir = 'bottom';
      top = dir === 'bottom' ? r.bottom + gap : r.top - bh - gap;
      left = clamp(r.left + r.width / 2 - bw / 2, edge, W - bw - edge);
      ax = clamp(r.left + r.width / 2 - left, 22, bw - 22) + 'px';
    }
    top = clamp(top, SAFE.t + edge, H - bh - SAFE.b - edge);
    bub.dataset.dir = dir;
    bub.style.setProperty('--ax', ax);
    bub.style.left = left + 'px';
    bub.style.top = top + 'px';
    void bub.offsetWidth;
    bub.classList.remove('nofx');
    hole.classList.remove('nofx');
    bub.classList.add('on');
  }

  function guidePanel(p) {
    var want = p || null;
    if (GD.panel === want) return;
    if (GD.panel) closePanels();
    GD.panel = want;
    if (!want) return;
    openPanel(want);
  }

  function guideGo(i) {
    var g = guideEl(), host = $('eb');
    if (!g || !host) return;
    GD.step = clamp(i, 0, GSTEPS.length - 1);
    var s = GSTEPS[GD.step];
    clearTimeout(GD.settle);
    clearTimeout(GD.settle2);
    GD.cap = !!s.cap;
    host.classList.remove('idle');
    if (GD.cap) host.classList.add('idle');
    syncCap();
    if (GD.cap) guideFill(g);
    var gsnap = GD.step;
    guidePanel(s.panel);
    try {
      var af = document.activeElement;
      if (af && af.blur && af !== document.body) af.blur();
    } catch (e) { }
    if (s.panel && s.sel) {
      var gsel = s.sel;
      setTimeout(function () {
        if (!GD.open || GD.step !== gsnap) return;
        var tg = host.querySelector(gsel);
        if (!tg) return;
        var tr = tg.getBoundingClientRect();
        if (tr.top < SAFE.t + 70 || tr.bottom > window.innerHeight - 150) {
          try { tg.scrollIntoView({ block: 'center' }); } catch (e) { }
        }
      }, 90);
    }
    var bub = g.querySelector('[data-gbub]');
    var zone = g.querySelector('[data-gzone]');
    bub.classList.remove('on');
    zone.classList.remove('on');
    if (s.zones) {
      var tb = $('ebTop'), bb = $('ebBot');
      zone.style.setProperty('--zt', ((tb ? tb.offsetHeight : 60)) + 'px');
      zone.style.setProperty('--zb', ((bb ? bb.offsetHeight : 56)) + 'px');
      zone.innerHTML = guideBands() + guideZones(s.zones);
      zone.classList.add('on');
      guideFill(g);
    }
    g.querySelector('[data-gstep]').textContent = L.t(s.g) + ' · ' + (GD.step + 1) + ' / ' + GSTEPS.length;
    g.querySelector('[data-gt]').textContent = L.t(s.t);
    g.querySelector('[data-gd]').innerHTML = L.t(s.d);
    g.querySelector('[data-gskip]').textContent = L.t('跳过');
    g.querySelector('[data-gprev]').textContent = L.t('上一步');
    g.querySelector('[data-gprev]').disabled = GD.step === 0;
    g.querySelector('[data-gnext]').textContent = GD.step >= GSTEPS.length - 1 ? L.t('开始阅读') : L.t('下一步');
    var run = function () {
      if (GD.open && GD.step === gsnap) guidePlace(g, host, s);
    };
    if (s.panel) {
      GD.settle = setTimeout(run, 320);
      GD.settle2 = setTimeout(run, 620);
    } else {
      requestAnimationFrame(function () { requestAnimationFrame(run); });
      GD.settle2 = setTimeout(run, 320);
    }
  }

  function guideNext() {
    if (GD.step >= GSTEPS.length - 1) return closeGuide(true);
    guideGo(GD.step + 1);
  }

  function guideZone(ev) {
    var z = ev.target.closest ? ev.target.closest('i') : null;
    if (!z) return;
    ev.stopPropagation();
    z.classList.remove('hit');
    void z.offsetWidth;
    z.classList.add('hit');
    var k = z.dataset.z;
    if (k === 'l') return sideTurn(-1);
    if (k === 'r') return sideTurn(1);
    bumpIdle();
  }

  function openGuide() {
    var g = guideEl(), host = $('eb');
    if (!g || !host) return;
    if (EB.panel) closePanels();
    if (EB.selRange) clearSel();
    GD.open = true;
    GD.step = 0;
    GD.panel = null;
    GD.cap = false;
    host.classList.remove('idle');
    g.classList.add('on');
    guideFill(g);
    guideGo(0);
    postUi();
  }

  function closeGuide(mark) {
    var g = $('ebGuide');
    if (!g) return;
    GD.open = false;
    GD.cap = false;
    var host = $('eb');
    if (host) host.classList.remove('idle');
    clearTimeout(GD.settle);
    clearTimeout(GD.settle2);
    GD.settle = null;
    GD.settle2 = null;
    if (GD.panel) closePanels();
    GD.panel = null;
    g.classList.remove('on');
    ['[data-ghole]', '[data-gbub]', '[data-gzone]'].forEach(function (sel) {
      var n = g.querySelector(sel);
      if (n) n.classList.remove('on', 'flat');
    });
    if (mark) { try { localStorage.setItem(GUIDE_KEY, '1'); } catch (e) { } }
    syncCap();
    postUi();
  }

  function maybeAutoGuide() {
    if (guideBooted) return;
    guideBooted = true;
    var seen = false;
    try { seen = localStorage.getItem(GUIDE_KEY) === '1'; } catch (e) { }
    if (seen) return;
    setTimeout(function () { if (EB.open && !GD.open) openGuide(); }, 900);
  }

  function paintTop() {
    var t = $('ebTop'); if (!t) return;
    var b = EB.book || {};
    var cur = EB.chs.get(EB.ch) || {};
    t.innerHTML =
      '<button class="eb-btn" data-a="exit" title="' + L.t('返回') + '">' + ico('left') + '</button>' +
      '<div class="eb-title"><b>' + esc(b.title || '') + (PRE.imm ? '<i class="eb-imm">' + L.t('隐身') + '</i>' : '') + '</b><small id="ebCrumb">' +
      esc(cur.title || L.t('第 ') + EB.ch + L.t(' 章')) + ' · ' + EB.ch + ' / ' + num(EB.total) + '</small></div>' +
      '<button class="eb-btn" data-a="guide" title="' + L.t('操作指引') + '">' + ico('info') + '</button>';
    [].slice.call(t.querySelectorAll('[data-a]')).forEach(function (btn) {
      btn.onclick = function () {
        var a = btn.dataset.a;
        if (a === 'exit') { close(); leaveApp(); }
        else if (a === 'guide') openGuide();
      };
    });
    markTop();
    measureChrome();
  }

  function markTop() {
    var t = $('ebTop');
    if (t) {
      [].slice.call(t.querySelectorAll('[data-a]')).forEach(function (b) {
        b.classList.toggle('on', false);
      });
    }
    var b = $('ebBot'); if (!b) return;
    [].slice.call(b.querySelectorAll('.eb-acts [data-a]')).forEach(function (n) {
      var a = n.dataset.a;
      n.classList.toggle('on', (a === 'toc' && EB.panel === 'toc') ||
        (a === 'find' && EB.panel === 'find') ||
        (a === 'ann' && EB.panel === 'ann') || (a === 'set' && EB.panel === 'set') ||
        (a === 'tts' && EB.ttsOn));
    });
  }

  var BOT_ACTS = [
    ['toc', 'toc', '目录'],
    ['find', 'search', '搜索'],
    ['ann', 'marker', '标注'],
    ['tts', 'volume', '朗读'],
    ['set', 'settings', '设置']
  ];

  function paintBot() {
    var b = $('ebBot'); if (!b) return;
    b.innerHTML =
      '<div class="eb-bot-r">' +
      '<span class="mono eb-pos" id="ebPos">' + posText(EB.ch) + '</span>' +
      '<span class="mono" id="ebChap">' + chapText() + '</span>' +
      '<span class="mono" id="ebPct">' + L.t('全书 ') + '0.00%</span>' +
      '<button class="eb-btn hide-s" data-a="prev" title="' + L.t('上一章') + '">' + ico('left') + '</button>' +
      '<button class="eb-btn hide-s" data-a="next" title="' + L.t('下一章') + '">' + ico('right') + '</button>' +
      '</div>' +
      '<div class="eb-track" id="ebTrack"><div class="rail"></div><div class="fill" id="ebFill"></div><div class="knob" id="ebKnob"></div></div>' +
      '<div class="eb-acts">' + BOT_ACTS.map(function (m) {
        return '<button data-a="' + m[0] + '" title="' + L.t(m[2]) + '">' + ico(m[1], 18) + '<span>' + L.t(m[2]) + '</span></button>';
      }).join('') + '</div>';
    wireTrack($('ebTrack'));
    [].slice.call(b.querySelectorAll('[data-a="prev"],[data-a="next"]')).forEach(function (btn) {
      btn.onclick = function () {
        var d = btn.dataset.a === 'prev' ? -1 : 1;
        if (isPaged()) { turnPage(d); return; }
        d < 0 ? prevChapter() : nextChapter();
      };
    });
    [].slice.call(b.querySelectorAll('.eb-acts [data-a]')).forEach(function (n) {
      n.onclick = function () {
        var a = n.dataset.a;
        if (a === 'tts') {
          if (ttsHeld) { ttsHeld = false; return; }
          ttsToggle();
          return;
        }
        if (a === 'toc') openPanel('toc');
        else if (a === 'find') openPanel('find');
        else if (a === 'ann') { EB.annTab = 'mark'; openPanel('ann'); }
        else if (a === 'set') openPanel('set');
      };
      if (n.dataset.a === 'tts') {
        n.addEventListener('pointerdown', function () {
          ttsHoldBtn();
        });
        n.addEventListener('pointerup', function () {
          ttsHoldBtnEnd();
        });
        n.addEventListener('pointerleave', function () {
          ttsHoldBtnEnd();
        });
        n.addEventListener('pointercancel', function () {
          ttsHoldBtnEnd();
        });
      }
    });
    paintProgressBar(true);
    markTop();
    measureChrome();
  }

  function wireTrack(track) {
    if (!track) return;
    var frac = function (ev) {
      var r = track.getBoundingClientRect();
      return clamp((ev.clientX - r.left) / Math.max(1, r.width), 0, 1);
    };
    var stop = function (id) {
      EB.drag = null;
      EB.seeking = null;
      track.classList.remove('drag');
      try { track.releasePointerCapture(id); } catch (e) { }
    };
    track.addEventListener('pointerdown', function (ev) {
      if (ev.button != null && ev.button > 0) return;
      ev.preventDefault();
      clearTimeout(EB.idle);
      var r = $('eb'); if (r) r.classList.remove('idle');
      EB.drag = { f: frac(ev), x: ev.clientX, moved: false };
      EB.seeking = EB.drag.f;
      track.classList.add('drag');
      try { track.setPointerCapture(ev.pointerId); } catch (e) { }
      paintBar(EB.drag.f, true);
    });
    track.addEventListener('pointermove', function (ev) {
      var d = EB.drag; if (!d) return;
      if (!d.moved && Math.abs(ev.clientX - d.x) < 3) return;
      d.moved = true;
      d.f = frac(ev);
      EB.seeking = d.f;
      paintBar(d.f, true);
    });
    track.addEventListener('pointerup', function (ev) {
      var d = EB.drag; if (!d) return;
      stop(ev.pointerId);
      seek(d.f);
    });
    track.addEventListener('pointercancel', function (ev) {
      if (!EB.drag) return;
      stop(ev.pointerId);
      paintProgressBar(true);
    });
  }

  function paintBar(f, preview) {
    var fill = $('ebFill'), knob = $('ebKnob'), pct = $('ebPct'), pos = $('ebPos'), chap = $('ebChap');
    if (!fill) return;
    var w = (clamp(f, 0, 1) * 100).toFixed(2) + '%';
    fill.style.width = w;
    if (knob) knob.style.left = w;
    if (pct) pct.textContent = L.t('全书 ') + w;
    if (pos) pos.textContent = preview ? posText(previewChapter(f)) : posText(EB.ch) + pageSuffix();
    if (chap) chap.textContent = preview ? L.t('本章 ') + '—' : chapText();
  }

  function paintProgressBar(force) {
    if (EB.seeking != null && !force) return;
    paintBar(totalProgress(), false);
    syncCap();
  }

  function totalProgress() {
    if (!EB.total) return 0;
    return clamp((EB.ch - 1 + chapterProgress()) / EB.total, 0, 1);
  }

  function previewChapter(f) {
    if (!EB.total) return 1;
    return clamp(Math.ceil(clamp(f, 0, 1) * EB.total), 1, EB.total);
  }

  function posText(n) {
    var v = volInfo(n);
    if (v) return L.t('第 ') + v.i + ' / ' + v.total + L.t(' 卷 · 第 ') + v.j + ' / ' + v.count + L.t(' 节');
    return L.t('第 ') + n + ' / ' + num(EB.total) + L.t(' 章');
  }

  function chapText() {
    return L.t('本章 ') + (clamp(chapterProgress(), 0, 1) * 100).toFixed(2) + '%';
  }

  function pageSuffix() {
    if (!isPaged() || !EB.view || !EB.pages || EB.pages < 2) return '';
    var sec = EB.secs.get(EB.ch); if (!sec) return '';
    var vr = EB.view.getBoundingClientRect();
    var sr = sec.getBoundingClientRect();
    var st = Math.max(1, layoutMetrics().step);
    var cols = Math.max(1, Math.ceil((sr.width - 2) / st));
    if (cols < 2) return '';
    var start = Math.round((EB.view.scrollLeft + sr.left - vr.left) / st);
    return ' · ' + clamp(EB.page - start + 1, 1, cols) + ' / ' + cols + L.t(' 页');
  }

  function volInfo(n) {
    var vs = EB.vols; if (!vs) return null;
    var k = 0;
    for (var i = 0; i < vs.length; i++) { if (vs[i].n <= n) k = i; else break; }
    var start = vs[k].n;
    var end = vs[k + 1] ? vs[k + 1].n : EB.total + 1;
    return { i: k + 1, total: vs.length, j: n - start + 1, count: Math.max(1, end - start) };
  }

  function chapterProgress() {
    var sec = EB.secs.get(EB.ch);
    if (!sec || !EB.view) return (EB.hold && EB.hold.n === EB.ch) ? EB.hold.p : 0;
    if (isPaged()) {
      var pv = EB.view.getBoundingClientRect();
      var ps = sec.getBoundingClientRect();
      var span2 = ps.width - EB.view.clientWidth;
      if (span2 <= 8) return 0;
      return clamp((pv.left - ps.left) / span2, 0, 1);
    }
    var vr = EB.view.getBoundingClientRect();
    var sr = sec.getBoundingClientRect();
    var top = EB.view.scrollTop + (sr.top - vr.top);
    var span = sr.height - EB.view.clientHeight;
    if (span <= 8) return 0;
    return clamp((EB.view.scrollTop - top) / span, 0, 1);
  }

  function parseHtml(html) {
    var doc = new DOMParser().parseFromString(html || '', 'text/html');
    var b = doc.body;
    var body = b ? b.innerHTML : '';
    var links = [].slice.call(doc.querySelectorAll('link[rel~="stylesheet"]')).map(function (l) { return l.getAttribute('href'); }).filter(Boolean);
    var styles = [].slice.call(doc.querySelectorAll('style')).map(function (s) { return s.textContent || ''; }).filter(Boolean);
    return {
      body: body, links: links, styles: styles,
      cls: b ? (b.getAttribute('class') || '') : '',
      sty: b ? (b.getAttribute('style') || '') : ''
    };
  }

  function applyBody(sec, parsed) {
    if (!sec || !parsed) return;
    (parsed.cls || '').split(/\s+/).forEach(function (c) {
      if (c && c !== 'sec' && c !== 'doc') sec.classList.add(c);
    });
    (parsed.sty || '').split(';').forEach(function (decl) {
      var i = decl.indexOf(':');
      if (i < 1) return;
      var k = decl.slice(0, i).trim();
      var v = decl.slice(i + 1).trim();
      if (!k || !v || !PUB_KEEP_BODY.test(k + ':')) return;
      sec.style.setProperty(k, v);
    });
  }

  function pushUniq(list, items) {
    items.forEach(function (x) { if (x && list.indexOf(x) < 0) list.push(x); });
  }

  function artPage(sec, ct) {
    if (!ct) return false;
    if (ct.querySelector('img,video,audio,canvas,iframe,object,embed')) return false;
    if (!sec || sec.classList.length < 2) return false;
    return (ct.textContent || '').replace(/[\s\u00a0\u3000]+/g, '').length < 24;
  }

  function chTitle(n) {
    var c = EB.chs.get(n);
    if (c && c.title) return c.title;
    var o = EB.outline || [];
    for (var i = 0; i < o.length; i++) if (o[i].n === n) return o[i].title || '';
    return '';
  }

  function fillJoin(box, n) {
    var nav = EB.nav || {};
    var last = n >= EB.total;
    var pl = box.querySelector('.j.l .nm');
    var pr = box.querySelector('.j.r .nm');
    if (pl) {
      pl.textContent = n > 1 ? ('← ' + (chTitle(n - 1) || L.t('上一章')))
        : (nav.prevBookId ? ('← ' + (nav.prevTitle || L.t('上一本'))) : '');
    }
    if (pr) {
      pr.textContent = last
        ? (nav.nextBookId ? ((nav.nextTitle || L.t('下一本')) + ' →') : L.t('全书完'))
        : ((chTitle(n + 1) || L.t('下一章')) + ' →');
    }
  }

  function joinBar(n) {
    var nav = EB.nav || {};
    var last = n >= EB.total;
    var prevOn = n > 1 || !!nav.prevBookId;
    var nextOn = !last || !!nav.nextBookId;
    var box = el('div', 'eb-join');
    box.dataset.j = String(n);
    box.innerHTML =
      '<button class="j l" type="button" data-d="-1"><span class="nm"></span></button>' +
      '<span class="mid">' + L.t('本章完') + '</span>' +
      '<button class="j r" type="button" data-d="1"><span class="nm"></span></button>';
    box.querySelector('.j.l').classList.toggle('off', !prevOn);
    if (!nextOn) box.querySelector('.j.r').disabled = true;
    box.addEventListener('click', function (ev) {
      var t = ev.target.closest ? ev.target.closest('[data-d]') : null;
      if (!t || t.disabled) return;
      ev.preventDefault();
      ev.stopPropagation();
      if (+t.dataset.d > 0) nextChapter(); else prevChapter();
    });
    fillJoin(box, n);
    return box;
  }

  function placeJoin(sec, n) {
    if (!EB.docEl || !(EB.total > 1 || EB.nav)) return;
    var old = EB.docEl.querySelector('.eb-join[data-j="' + n + '"]');
    var box = old || joinBar(n);
    if (old && old.parentNode) old.parentNode.removeChild(old);
    sec.parentNode.insertBefore(box, sec.nextSibling);
  }

  function refreshJoins() {
    if (!EB.docEl) return;
    [].slice.call(EB.docEl.querySelectorAll('.eb-join')).forEach(function (b) {
      var n = +b.dataset.j || 0;
      if (n) fillJoin(b, n);
    });
  }

  function crossTo(d) {
    if (!EB.open) return false;
    var nav = EB.nav || {};
    var id = d > 0 ? nav.nextBookId : nav.prevBookId;
    if (!id) return false;
    clearTimeout(EB.progTimer);
    sendProgress();
    var pre = (EB.pre && EB.pre.id === id && EB.pre.dto) ? EB.pre.dto : null;
    var meta = { title: d > 0 ? (nav.nextTitle || '') : (nav.prevTitle || '') };
    EB.pre = null;
    if (d > 0) open(id, { boot: pre, meta: meta });
    else open(id, { boot: pre, meta: meta, chapter: 1e9, progress: 0 });
    return true;
  }

  function maybePreload() {
    var nav = EB.nav || {};
    if (!nav.nextBookId || EB.ch < EB.total) return;
    var id = nav.nextBookId;
    if (EB.pre && EB.pre.id === id) return;
    EB.pre = { id: id, dto: null, at: 0 };
    req('api/lantai/v1/read/' + id + '/bootstrap?images=url&w=0&window=3')
      .then(function (dto) {
        if (!EB.pre || EB.pre.id !== id) return;
        if (!dto || !dto.book || dto.book.id !== id) { EB.pre = null; return; }
        EB.pre.dto = dto;
        EB.pre.at = Date.now();
      })
      .catch(function () {
        if (EB.pre && EB.pre.id === id) EB.pre = null;
      });
  }

  function buildSec(dto, inline) {
    var n = dto.chapter;
    EB.chs.set(n, { n: n, title: dto.title || '', chars: dto.chars || 0, href: dto.href || '' });
    var sec = el('section', 'sec');
    sec.dataset.ch = String(n);
    var head = el('div', 'eb-head');
    head.innerHTML = '<span class="n">' + n + '</span><span class="t">' + esc(dto.title || '') + '</span>' +
      '<span class="w">' + (dto.chars ? num(dto.chars) + L.t(' 字') : '') + '</span>';
    var ct = el('div', EB.book && EB.book.profile === 'TXT' ? 'ct txt' : 'ct');
    var parsed = parseHtml(dto.html);
    ct.innerHTML = parsed.body || '';
    applyBody(sec, parsed);
    pushUniq(EB.links, parsed.links);
    pushUniq(EB.inlines, parsed.styles);
    sec.appendChild(head);
    sec.appendChild(ct);
    tidy(ct, n);
    if (artPage(sec, ct)) sec.classList.add('artpage');
    EB.secs.set(n, sec);
    EB.lo = EB.lo ? Math.min(EB.lo, n) : n;
    EB.hi = Math.max(EB.hi, n);
    return sec;
  }

  function tidy(root, n) {
    [].slice.call(root.querySelectorAll('svg')).forEach(function (svg) {
      var pics = [].slice.call(svg.querySelectorAll('image'));
      if (!pics.length) return;
      var box = el('div', 'eb-svgimg');
      pics.forEach(function (node) {
        var src = node.getAttribute('xlink:href') || node.getAttribute('href') || node.getAttribute('src');
        if (!src) return;
        var img = el('img', 'eb-ill');
        img.src = src;
        img.alt = '';
        var sw = parseInt(node.getAttribute('width'), 10);
        var sh = parseInt(node.getAttribute('height'), 10);
        if (sw > 0 && sh > 0) { img.setAttribute('width', sw); img.setAttribute('height', sh); }
        box.appendChild(img);
      });
      if (box.childNodes.length) svg.parentNode.replaceChild(box, svg);
      else svg.remove();
    });
    [].slice.call(root.querySelectorAll('image')).forEach(function (node) {
      var src = node.getAttribute('xlink:href') || node.getAttribute('href') || node.getAttribute('src');
      if (!src) return node.remove();
      var img = el('img', 'eb-ill');
      img.src = src;
      img.alt = '';
      var iw2 = parseInt(node.getAttribute('width'), 10);
      var ih2 = parseInt(node.getAttribute('height'), 10);
      if (iw2 > 0 && ih2 > 0) { img.setAttribute('width', iw2); img.setAttribute('height', ih2); }
      node.parentNode.replaceChild(img, node);
    });
    [].slice.call(root.querySelectorAll('img')).forEach(function (img) {
      img.classList.add('eb-ill');
      img.loading = 'lazy';
      var iw = parseInt(img.getAttribute('width'), 10);
      var ih = parseInt(img.getAttribute('height'), 10);
      img.style.setProperty('max-width', '100%', 'important');
      img.style.setProperty('height', 'auto', 'important');
      if (iw > 0 && ih > 0) img.style.setProperty('aspect-ratio', 'auto ' + iw + ' / ' + ih);
      else img.classList.add('nosize');
      img.removeAttribute('width');
      img.removeAttribute('height');
      img.alt = L.t('加载中');
      img.addEventListener('load', function () { img.classList.add('ok'); img.classList.remove('nosize'); img.alt = ''; });
      img.addEventListener('error', function () { img.classList.add('bad'); img.alt = L.t('图片未能加载'); });
      if (img.complete && img.naturalWidth > 0) { img.classList.add('ok'); img.classList.remove('nosize'); img.alt = ''; }
      img.addEventListener('click', function () { zoomImg(img.src); });
    });
    [].slice.call(root.querySelectorAll('a')).forEach(function (a) {
      var ch = a.getAttribute('data-ch');
      if (ch) {
        a.addEventListener('click', function (ev) {
          ev.preventDefault();
          gotoChapter(+ch, 0);
        });
        return;
      }
      var href = a.getAttribute('href') || '';
      if (href.indexOf('#') === 0 && href.length > 1) {
        a.addEventListener('click', function (ev) {
          ev.preventDefault();
          jumpAnchor(href.slice(1));
        });
      } else if (/^(https?:)?\/\//i.test(href)) {
        a.setAttribute('target', '_blank');
        a.setAttribute('rel', 'noopener noreferrer');
      } else {
        a.addEventListener('click', function (ev) { ev.preventDefault(); });
      }
    });
    paintMarks(root, n);
  }

  function jumpAnchor(id) {
    if (!EB.shadow) return;
    var target = EB.shadow.getElementById(id);
    if (!target) return;
    var vr = EB.view.getBoundingClientRect();
    var tr = target.getBoundingClientRect();
    EB.view.scrollTop += tr.top - vr.top - EB.view.clientHeight * 0.3;
    target.style.transition = 'background .4s';
    target.style.background = 'rgba(201,162,75,.3)';
    setTimeout(function () { target.style.background = ''; }, 900);
  }

  function zoomImg(src) {
    if (!src) return;
    $('ebLbImg').src = src;
    $('ebLb').classList.add('on');
  }

  function load(n, where) {
    if (n < 1 || n > EB.total) return Promise.resolve(null);
    if (EB.secs.has(n)) return Promise.resolve(EB.secs.get(n));
    if (EB.park.has(n)) {
      var parked = EB.park.get(n);
      EB.park.delete(n);
      EB.secs.set(n, parked);
      EB.lo = EB.lo ? Math.min(EB.lo, n) : n;
      EB.hi = Math.max(EB.hi, n);
      insertSec(parked);
      return Promise.resolve(parked);
    }
    var key = 'k' + n;
    if (EB.pending[key]) return EB.pending[key];
    var p = req('api/lantai/v1/read/' + EB.bookId + '/chapter/' + n + '?images=url&w=0&fmt=orig')
      .then(function (dto) {
        delete EB.pending[key];
        if (!EB.open) return null;
        var sec = buildSec(dto, false);
        insertSec(sec);
        return sec;
      })
      .catch(function (e) {
        delete EB.pending[key];
        throw e;
      });
    EB.pending[key] = p;
    return p;
  }

  function insertSec(sec) {
    if (!EB.docEl) return;
    var n = +sec.dataset.ch;
    var kids = [].slice.call(EB.docEl.children);
    var anchor = null;
    for (var i = 0; i < kids.length; i++) {
      if ((+kids[i].dataset.ch || 0) > n) { anchor = kids[i]; break; }
    }
    if (!anchor) {
      EB.docEl.appendChild(sec);
      placeJoin(sec, n);
      syncPub();
      return;
    }
    var vr = EB.view.getBoundingClientRect();
    var visible = anchor.getBoundingClientRect().top < vr.bottom;
    var beforeH = EB.view.scrollHeight;
    var beforeW = EB.view.scrollWidth;
    EB.docEl.insertBefore(sec, anchor);
    placeJoin(sec, n);
    if (isPaged()) EB.view.scrollLeft += EB.view.scrollWidth - beforeW;
    else if (visible) EB.view.scrollTop += EB.view.scrollHeight - beforeH;
    syncPub();
  }

  var KEEP_BEHIND = 6, KEEP_AHEAD = 6, PARK_MAX = 48;

  function trimWindow() {
    if (!EB.open || !EB.docEl || !EB.view) return;
    var paged = isPaged();
    var wLo = EB.ch - (paged ? 1 : KEEP_BEHIND);
    var wHi = EB.ch + (paged ? 1 : KEEP_AHEAD);
    var kids = [].slice.call(EB.docEl.children);
    var hasLeft = false, hasRight = false, hit = false;
    for (var i = 0; i < kids.length; i++) {
      var c = +kids[i].dataset.ch || 0;
      if (!c || (c >= wLo && c <= wHi)) continue;
      hit = true;
      if (c < wLo) hasLeft = true; else hasRight = true;
    }
    if (!hit) { trimPark(); return; }
    var span = paged ? EB.view.scrollWidth : EB.view.scrollHeight;
    for (var j = 0; j < kids.length; j++) {
      var sec = kids[j];
      var n = +sec.dataset.ch || 0;
      if (!n || (n >= wLo && n <= wHi)) continue;
      if (EB.ttsOn && n === EB.ttsCh) continue;
      var jb = sec.nextElementSibling;
      if (jb && jb.classList.contains('eb-join') && +jb.dataset.j === n && jb.parentNode) jb.parentNode.removeChild(jb);
      EB.docEl.removeChild(sec);
      EB.secs.delete(n);
      EB.park.set(n, sec);
    }
    var drop = span - (paged ? EB.view.scrollWidth : EB.view.scrollHeight);
    if (drop > 0 && hasLeft && !hasRight) {
      if (paged) EB.view.scrollLeft = Math.max(0, EB.view.scrollLeft - drop);
      else EB.view.scrollTop = Math.max(0, EB.view.scrollTop - drop);
    }
    trimPark();
  }

  function trimPark() {
    if (EB.park.size <= PARK_MAX) return;
    var keys = Array.from(EB.park.keys()).sort(function (a, b) { return Math.abs(b - EB.ch) - Math.abs(a - EB.ch); });
    for (var i = 0; i < keys.length && EB.park.size > PARK_MAX; i++) EB.park.delete(keys[i]);
  }

  function ensureWindow() {
    if (!EB.open || !isPaged()) return;
    load(EB.ch + 1, 'after').catch(function () { });
    load(EB.ch - 1, 'before').catch(function () { });
  }

  function reset(n, prog) {
    if (!EB.docEl) return Promise.resolve();
    EB.secs.clear();
    EB.park.clear();
    EB.docEl.innerHTML = '';
    EB.lo = 0;
    EB.hi = 0;
    EB.links = [];
    EB.inlines = [];
    EB.ch = n;
    return load(n, 'after').then(function () {
      paintTop();
      paintBot();
      return Promise.all([
        load(n - 1, 'before').catch(function () { }),
        load(n + 1, 'after').catch(function () { })
      ]).then(function () {
        if (!EB.open) return null;
        if (isPaged()) {
          requestAnimationFrame(function () {
            measure();
            scrollToSec(EB.secs.get(n), prog || 0);
            paintProgressBar();
          });
        }
        return null;
      });
    });
  }

  function onScroll() {
    if (!EB.open) return;
    if (EB.raf) return;
    EB.raf = requestAnimationFrame(function () {
      EB.raf = 0;
      if (isPaged()) measure();
      var n = chapterAt();
      if (n && n !== EB.ch) {
        EB.ch = n;
        EB.seen = Math.max(EB.seen, n);
        var crumb = $('ebCrumb');
        var cur = EB.chs.get(n) || {};
        if (crumb) crumb.textContent = (cur.title || L.t('第 ') + n + L.t(' 章')) + ' · ' + n + ' / ' + num(EB.total);
        markToc();
        trimWindow();
        ensureWindow();
      }
      queueProgress();
      paintProgressBar();
      extend();
      if (EB.ttsOn && Date.now() - EB.autoT > 150) noteManual();
      if (EB.selRange && !EB.selMode) {
        placeSelBox(EB.selRange);
        placeHands(EB.selRange);
      }
    });
  }

  function chapterAt() {
    if (!EB.docEl || !EB.view) return 0;
    var secs = EB.docEl.children;
    if (!secs.length) return EB.ch;
    var vr = EB.view.getBoundingClientRect();
    if (isPaged()) {
      var x = vr.left + 2;
      for (var i = 0; i < secs.length; i++) {
        var pr = secs[i].getBoundingClientRect();
        if (pr.right > x) return +secs[i].dataset.ch || EB.ch;
      }
      return +secs[secs.length - 1].dataset.ch || EB.ch;
    }
    var line = vr.top + 96;
    var lo = 0, hi = secs.length - 1, res = +secs[secs.length - 1].dataset.ch || EB.ch;
    while (lo <= hi) {
      var mid = (lo + hi) >> 1;
      var r = secs[mid].getBoundingClientRect();
      if (r.bottom > line) { res = +secs[mid].dataset.ch || EB.ch; hi = mid - 1; } else lo = mid + 1;
    }
    return res;
  }

  function extend() {
    if (!EB.view) return;
    if (isPaged()) return;
    var v = EB.view;
    var kids = EB.docEl ? EB.docEl.children : null;
    if (!kids || !kids.length) return;
    var vr = v.getBoundingClientRect();
    var nearTop = kids[0].getBoundingClientRect().top - vr.top > -1600;
    var nearBottom = vr.bottom - kids[kids.length - 1].getBoundingClientRect().bottom > -1600;
    if (!EB.warmF && nearBottom && EB.hi < EB.total) {
      EB.warmF = true;
      load(EB.hi + 1, 'after')
        .then(function () { if (EB.open && EB.hi < EB.total) return load(EB.hi + 1, 'after'); })
        .catch(function () { })
        .then(function () { EB.warmF = false; });
    }
    if (!EB.warmB && nearTop && EB.lo > 1) {
      EB.warmB = true;
      load(EB.lo - 1, 'before')
        .then(function () { if (EB.open && EB.lo > 1) return load(EB.lo - 1, 'before'); })
        .catch(function () { })
        .then(function () { EB.warmB = false; });
    }
  }

  function scrollToSec(sec, prog) {
    if (!sec || !EB.view) return;
    if (isPaged()) {
      measure();
      var bv = EB.view.getBoundingClientRect();
      var bs = sec.getBoundingClientRect();
      var st = Math.max(1, layoutMetrics().step);
      var startPage = Math.max(0, Math.round((EB.view.scrollLeft + bs.left - bv.left) / st));
      var secCols = Math.max(1, Math.ceil((bs.width - 2) / st));
      var rel = clamp(prog || 0, 0, 1);
      goPage(rel >= 0.999 ? startPage + secCols - 1 : startPage + Math.round(rel * (secCols - 1)));
      return;
    }
    var vr = EB.view.getBoundingClientRect();
    var sr = sec.getBoundingClientRect();
    var pad = parseFloat(getComputedStyle(EB.view).paddingTop) || 0;
    var top = EB.view.scrollTop + (sr.top - vr.top) - pad;
    var span = Math.max(0, sr.height - EB.view.clientHeight);
    EB.view.scrollTop = Math.max(0, top + span * clamp(prog || 0, 0, 1));
  }

  function reanchor(n, prog) {
    var ticks = 0;
    var timer = setInterval(function () {
      ticks++;
      if (ticks > 8 || !EB.open || !EB.view) { clearInterval(timer); return; }
      var sec = EB.secs.get(n);
      if (!sec) return;
      var vr = EB.view.getBoundingClientRect();
      var sr = sec.getBoundingClientRect();
      if (sr.top >= vr.top - 8) { clearInterval(timer); return; }
      scrollToSec(sec, prog || 0);
    }, 120);
  }

  function gotoChapter(n, prog) {
    n = Math.round(clamp(n, 1, EB.total));
    ttsClear();
    EB.hold = { n: n, p: clamp(prog || 0, 0, 1) };
    var sec = EB.secs.get(n);
    if (sec) {
      scrollToSec(sec, prog || 0);
      EB.ch = n;
      paintProgressBar();
      queueProgress();
      setTimeout(function () {
        if (!EB.open) return;
        var s = EB.secs.get(n);
        if (s) scrollToSec(s, prog || 0);
      }, 240);
      return;
    }
    tip(L.t('正在载入'), L.t('第 ') + n + L.t(' 章 · 共 ') + num(EB.total) + L.t(' 章'));
    reset(n, prog || 0).then(function () {
      tip('');
      scrollToSec(EB.secs.get(n), prog || 0);
      EB.ch = n;
      paintProgressBar();
      queueProgress();
      setTimeout(function () {
        if (!EB.open) return;
        var s = EB.secs.get(n);
        if (s) scrollToSec(s, prog || 0);
      }, 240);
    }).catch(function (e) {
      tip('');
      toast(L.t('载入失败：') + errText(e), 'err');
    });
  }

  function prevChapter() {
    if (EB.ch > 1) return gotoChapter(EB.ch - 1, 0);
    return crossTo(-1);
  }

  function nextChapter() {
    if (EB.ch < EB.total) return gotoChapter(EB.ch + 1, 0);
    return crossTo(1);
  }

  function seek(f) {
    if (!EB.total) return;
    gotoChapter(previewChapter(f), 0);
  }

  function queueProgress() {
    clearTimeout(EB.progTimer);
    EB.progTimer = setTimeout(sendProgress, 900);
  }

  function sendProgress() {
    if (!EB.open || EB.restoring) return;
    var ref = EB.chs.get(EB.ch) || {};
    var p = chapterProgress();
    var tp = totalProgress();
    if (PRE.imm) {
      try { sessionStorage.setItem(immKey(), JSON.stringify({ ch: EB.ch, p: p })); } catch (e) { }
      return;
    }
    if (typeof PROGRESS !== 'undefined') {
      PROGRESS[EB.bookId] = {
        page: EB.ch, pages: EB.total, completed: tp >= 0.999, device: 'webui', at: Date.now(),
        locator: { href: ref.href || ('#page=' + EB.ch), position: EB.ch, totalProgression: tp }
      };
    }
    req('api/lantai/v1/read-progress?book=' + encodeURIComponent(EB.bookId) +
      '&ch=' + EB.ch + '&p=' + p.toFixed(4) + '&tp=' + tp.toFixed(4) +
      '&href=' + encodeURIComponent(ref.href || ''), {
      method: 'GET'
    }).catch(function () { });
  }

  function startBeat() {
    clearInterval(EB.hbTimer);
    EB.hbTimer = setInterval(function () {
      if (!EB.open || PRE.imm || !EB.session) return;
      EB.beats++;
      EB.session.dur += 30000;
      EB.session.pages = Math.max(EB.session.pages, EB.seen);
      if (typeof pushSession === 'function') pushSession(EB.session);
      req('api/lantai/v1/reading/heartbeat', {
        method: 'POST',
        body: { bookId: EB.bookId, page: EB.ch, deviceId: 'webui', deviceName: '网页端', client: 'lantai-webui' }
      }).catch(function () { });
    }, 30000);
  }

  function loadOutline() {
    if (EB.outline) return Promise.resolve(EB.outline);
    if (EB.outlinePending) return EB.outlinePending;
    var bid = EB.bookId;
    EB.outlineLoading = true;
    EB.outlinePending = req('api/lantai/v1/read/' + bid + '/outline?from=1&window=500')
      .then(function (dto) {
        EB.outlineLoading = false;
        EB.outlinePending = null;
        if (EB.bookId !== bid) return null;
        var list = (dto && dto.entries) || [];
        EB.outline = list.length ? list : null;
        var volumes = (dto && dto.volumes) || [];
        EB.vols = volumes.length ? volumes : null;
        list.forEach(function (c) {
          if (!c || !c.n) return;
          var old = EB.chs.get(c.n);
          EB.chs.set(c.n, {
            n: c.n,
            title: c.title || (old && old.title) || '',
            chars: (old && old.chars) || c.chars || 0,
            href: c.href || (old && old.href) || ''
          });
        });
        return EB.outline;
      })
      .catch(function () { EB.outlineLoading = false; EB.outlinePending = null; return null; });
    return EB.outlinePending;
  }

  function openPanel(which) {
    var r = $('eb');
    if (!r) return;
    if (EB.panel === which) {
      closePanels();
      return;
    }
    EB.panel = which;
    if (which === 'toc') {
      $('ebSet').classList.remove('on');
      paintToc();
      $('ebToc').classList.add('on');
    } else {
      $('ebToc').classList.remove('on');
      if (which === 'find') paintFind(); else paintSet(which);
      $('ebSet').classList.add('on');
    }
    r.classList.add('modal');
    clearSel();
    markTop();
  }

  function closePanels() {
    EB.panel = null;
    $('ebToc').classList.remove('on');
    $('ebSet').classList.remove('on');
    var r = $('eb'); if (r) r.classList.remove('modal');
    markTop();
  }

  function paintFind() {
    var P = $('ebSet');
    P.innerHTML =
      '<div class="eb-panel-h"><b>' + L.t('全书搜索') + '</b><span class="mono" id="ebFindN"></span>' +
      '<button class="eb-btn" data-a="close">' + ico('close') + '</button></div>' +
      '<div class="eb-search">' + ico('search') + '<input id="ebFindQ" placeholder="' + L.t('搜索正文，回车开始') + '" autocomplete="off" value="' + esc(EB.findQ || '') + '"></div>' +
      '<div class="eb-list" id="ebFindList"><div class="eb-empty">' + L.t('输入关键词后回车') + '</div></div>';
    P.querySelector('[data-a=close]').onclick = function () { closePanels(); };
    var input = $('ebFindQ');
    input.addEventListener('keydown', function (e) {
      if (e.key !== 'Enter') return;
      e.preventDefault();
      runFind(this.value.trim());
    });
    if (EB.findQ) runFind(EB.findQ);
    setTimeout(function () { try { input.focus(); } catch (e) { } }, 40);
  }

  function markText(text, q) {
    var s = esc(text);
    var k = esc(q);
    if (!k) return s;
    var i = s.toLowerCase().indexOf(k.toLowerCase());
    if (i < 0) return s;
    return s.slice(0, i) + '<mark>' + s.slice(i, i + k.length) + '</mark>' + s.slice(i + k.length);
  }

  function runFind(q) {
    EB.findQ = q;
    var box = $('ebFindList'), n = $('ebFindN');
    if (!box) return;
    if (!q) {
      box.innerHTML = '<div class="eb-empty">' + L.t('输入关键词后回车') + '</div>';
      if (n) n.textContent = '';
      return;
    }
    box.innerHTML = '<div class="eb-empty">' + L.t('正在搜索…') + '</div>';
    if (n) n.textContent = '';
    var slow = setTimeout(function () {
      if (EB.panel === 'find' && box && !box.querySelector('.eb-find-i')) {
        box.innerHTML = '<div class="eb-empty">' + L.t('首次搜索要建立正文索引，请稍候…') + '</div>';
      }
    }, 1500);
    req('api/lantai/v1/read/' + EB.bookId + '/search?limit=60&q=' + encodeURIComponent(q))
      .then(function (d) {
        clearTimeout(slow);
        if (EB.panel !== 'find') return;
        var hits = (d && d.hits) || [];
        if (n) n.textContent = d && d.total ? num(d.total) + L.t(' 处 · ') + num(d.matchedChapters) + L.t(' 章') : L.t('无结果');
        if (!hits.length) {
          box.innerHTML = '<div class="eb-empty">' + L.t('没有找到「') + esc(q) + L.t('」') + '</div>';
          return;
        }
        box.innerHTML = hits.map(function (h, i) {
          return '<div class="eb-find-i" data-hit="' + i + '">' +
            '<div class="h"><span class="mono">' + h.chapter + '</span>' + esc(h.title) + '</div>' +
            '<div class="s">' + markText(h.snippet, q) + '</div></div>';
        }).join('');
        [].slice.call(box.querySelectorAll('[data-hit]')).forEach(function (el) {
          el.onclick = function () { gotoHit(hits[+el.dataset.hit], q); };
        });
      })
      .catch(function (e) {
        clearTimeout(slow);
        box.innerHTML = '<div class="eb-empty">' + L.t('搜索失败：') + esc(errText(e)) + '</div>';
      });
  }

  function gotoHit(hit, q) {
    closePanels();
    if (hit.chapter === EB.ch) {
      findInView(q);
      return;
    }
    gotoChapter(hit.chapter, 0);
    setTimeout(function () { findInView(q); }, 800);
  }

  function findInView(q) {
    var sec = EB.secs.get(EB.ch);
    if (!sec || !q) return;
    var ct = sec.querySelector('.ct') || sec;
    var low = q.toLowerCase();
    var ranges = [];
    var w = document.createTreeWalker(ct, NodeFilter.SHOW_TEXT, null);
    var node;
    while ((node = w.nextNode())) {
      var value = node.nodeValue || '';
      var vl = value.toLowerCase();
      var at = 0;
      while (at < vl.length) {
        var i = vl.indexOf(low, at);
        if (i < 0) break;
        ranges.push({ node: node, s: i, e: i + q.length });
        at = i + q.length;
      }
    }
    if (!ranges.length) return;
    if (window.CSS && CSS.highlights && typeof window.Highlight === 'function') {
      var hl = new window.Highlight();
      var first = null;
      ranges.forEach(function (r) {
        var rg = document.createRange();
        try {
          rg.setStart(r.node, r.s);
          rg.setEnd(r.node, r.e);
        } catch (e) { return; }
        if (!first) first = rg;
        hl.add(rg);
      });
      CSS.highlights.set('eb-find', hl);
      if (first) {
        var holder = first.startContainer.parentElement || ct;
        ttsReveal(holder);
      }
    }
  }

  function paintToc() {
    var P = $('ebToc');
    P.innerHTML =
      '<div class="eb-panel-h"><b>' + L.t('目录') + '</b><span class="mono" id="ebTocN">' + num(EB.total) + L.t(' 章') + '</span>' +
      '<button class="eb-btn" data-a="close">' + ico('close') + '</button></div>' +
      '<div class="eb-search">' + ico('search') + '<input id="ebTocQ" placeholder="' + L.t('搜索章节') + '" autocomplete="off"></div>' +
      '<div class="eb-list" id="ebTocList"><div class="eb-empty">' + L.t('正在读取目录…') + '</div></div>';
    P.querySelector('[data-a=close]').onclick = function () { closePanels(); };
    $('ebTocQ').addEventListener('input', function () { renderToc(this.value.trim()); });
    loadOutline().then(function () {
      if (EB.panel !== 'toc') return;
      renderToc('');
    });
  }

  function tocItems() {
    var list = EB.outline || [];
    var vols = EB.vols || [];
    var out = [];
    var vi = 0;
    list.forEach(function (e) {
      while (vi < vols.length && vols[vi].n <= e.n) {
        out.push({ n: -vols[vi].n, title: vols[vi].title, depth: 0, chars: 0, vol: true });
        vi++;
      }
      var c = EB.chs.get(e.n) || {};
      out.push({
        n: e.n,
        title: e.title || c.title || (L.t('第 ') + e.n + L.t(' 章')),
        depth: vols.length ? 1 : 0,
        chars: c.chars || e.chars || 0,
        vol: false
      });
    });
    while (vi < vols.length) {
      out.push({ n: -vols[vi].n, title: vols[vi].title, depth: 0, chars: 0, vol: true });
      vi++;
    }
    return out;
  }

  function renderToc(q) {
    var box = $('ebTocList'); if (!box) return;
    var items = tocItems();
    if (!items.length) {
      items = Array.from(EB.chs.keys()).sort(function (a, b) { return a - b; }).map(function (n) {
        var c = EB.chs.get(n) || {};
        return { n: n, title: c.title || (L.t('第 ') + n + L.t(' 章')), depth: 0, chars: c.chars || 0, vol: false };
      });
    }
    if (q) {
      var low = q.toLowerCase();
      items = items.filter(function (x) { return String(x.title || '').toLowerCase().indexOf(low) >= 0; });
    }
    if (!items.length) { box.innerHTML = '<div class="eb-empty">' + L.t('没有匹配的章节') + '</div>'; return; }
    box.innerHTML = items.map(function (x) {
      var vol = x.vol && !q;
      return '<div class="eb-toc-i lv' + Math.min(2, x.depth || 0) + (vol ? ' vol' : '') + (x.n === EB.ch ? ' on' : '') + '" data-n="' + x.n + '">' +
        '<span class="lv">' + (vol ? L.t('卷') : x.n) + '</span><span class="nm">' + esc(x.title) + '</span>' +
        (x.chars ? '<span class="pg">' + (x.chars > 10000 ? (x.chars / 10000).toFixed(1) + L.t('万') : num(x.chars)) + '</span>' : '') +
        '</div>';
    }).join('');
    [].slice.call(box.querySelectorAll('[data-n]')).forEach(function (n) {
      n.onclick = function () {
        var at = +n.dataset.n;
        if (at <= 0) return;
        gotoChapter(at, 0);
        closePanels();
      };
    });
    var cur = box.querySelector('.on');
    if (cur) cur.scrollIntoView({ block: 'center' });
  }

  function markToc() {
    if (EB.panel !== 'toc') return;
    var box = $('ebTocList'); if (!box) return;
    [].slice.call(box.querySelectorAll('[data-n]')).forEach(function (n) {
      n.classList.toggle('on', +n.dataset.n === EB.ch);
    });
  }

  function paintSet(which) {
    var P = $('ebSet');
    if (which === 'ann') { paintAnns(); return; }
    loadFontFamilies();
    P.innerHTML =
      '<div class="eb-panel-h"><b>' + L.t('阅读设置') + '</b><button class="eb-btn" data-a="close">' + ico('close') + '</button></div>' +
      '<div class="eb-list">' +
      '<div class="eb-group">' + L.t('底色') + '</div>' +
      '<div class="eb-row"><label>' + L.t('主题') + '</label><div class="grow"><div class="eb-swatches">' +
      THEMES.map(function (t) {
        return '<div class="eb-sw-dot' + (PRE.theme === t[0] ? ' on' : '') + '" data-th="' + t[0] + '" title="' + t[1] + '">' +
          '<span style="background:' + t[2] + ';border:1px solid ' + t[3] + '22"></span></div>';
      }).join('') + '</div></div></div>' +
      '<div class="eb-group">' + L.t('排版') + '</div>' +
      '<div class="eb-row"><label>' + L.t('字号') + '</label><div class="grow" style="flex-wrap:nowrap">' +
      '<button class="eb-chip sq" data-sz="-1">A-</button>' +
      '<span class="mono" style="flex:1;text-align:center;font-size:12px">' + PRE.size + '</span>' +
      '<button class="eb-chip sq" data-sz="1">A+</button></div></div>' +
      '<div class="eb-row"><label>' + L.t('行距') + '</label><div class="grow">' +
      [[1.55, L.t('紧')], [1.85, L.t('中')], [2.15, L.t('松')]].map(function (x) {
        return '<button class="eb-chip' + (Math.abs(PRE.lh - x[0]) < .01 ? ' on' : '') + '" data-lh="' + x[0] + '">' + x[1] + '</button>';
      }).join('') + '</div></div>' +
      '<div class="eb-row"><label>' + L.t('段距') + '</label><div class="grow">' +
      [[0.4, L.t('窄')], [0.9, L.t('中')], [1.5, L.t('宽')]].map(function (x) {
        return '<button class="eb-chip' + (Math.abs(PRE.para - x[0]) < .01 ? ' on' : '') + '" data-pa="' + x[0] + '">' + x[1] + '</button>';
      }).join('') + '</div></div>' +
      '<div class="eb-row"><label>' + L.t('字体') + '</label><div class="grow">' +
      FONTS.map(function (f) {
        return '<button class="eb-chip' + (PRE.font === f[0] ? ' on' : '') + '" data-ft="' + f[0] + '" style="font-family:' + f[2] + '">' + f[1] + '</button>';
      }).join('') + '</div></div>' +
      '<div class="eb-row"><label>' + L.t('缩进') + '</label><div class="grow"><button class="eb-sw' + (PRE.indent ? ' on' : '') + '" data-sw="indent"></button></div></div>' +
      '<div class="eb-row"><label>' + L.t('版心') + '</label><div class="eb-slider"><input type="range" id="ebMeasure" min="26" max="64" step="2" value="' + PRE.measure + '"><span class="v" id="ebMeasureV">' + PRE.measure + '</span></div></div>' +
      '<div class="eb-row"><label>' + L.t('原书样式') + '</label><div class="grow"><button class="eb-sw' + (PRE.pubcss ? ' on' : '') + '" data-sw="pubcss"></button></div></div>' +
      '<div class="eb-note">' + L.t('关闭原书样式使用兰台排版，字号与行距调整才会生效；打开可还原出版社版式。') + '</div>' +
      '<div class="eb-group">' + L.t('翻页') + '</div>' +
      '<div class="eb-row"><label>' + L.t('方式') + '</label><div class="grow">' +
      [['scroll', L.t('连续滚动')], ['paged', L.t('单栏分页')], ['double', L.t('双栏分页')]].map(function (x) {
        return '<button class="eb-chip' + (PRE.layout === x[0] ? ' on' : '') + '" data-lt="' + x[0] + '">' + x[1] + '</button>';
      }).join('') + '</div></div>' +
      '<div class="eb-row' + (PRE.layout === 'scroll' ? ' dim' : '') + '"><label>' + L.t('方向') + '</label><div class="grow">' +
      [['LTR', L.t('从左往右')], ['RTL', L.t('从右往左')]].map(function (x) {
        return '<button class="eb-chip' + (PRE.dir === x[0] ? ' on' : '') + '" data-dr="' + x[0] + '"' +
          (PRE.layout === 'scroll' ? ' disabled' : '') + '>' + x[1] + '</button>';
      }).join('') + '</div></div>' +
      '<div class="eb-row"><label>' + L.t('点按翻页') + '</label><div class="grow"><button class="eb-sw' + (PRE.tapAny ? ' on' : '') + '" data-sw="tapAny"></button></div></div>' +
      '<div class="eb-note">' + L.t('分页模式下方向决定左右点击区；连续滚动时方向不生效。') + '</div>' +
      '<div class="eb-note">' + L.t('开启点按翻页后，左右区域点一下即翻页，正文链接优先跳转；关闭后只有链接可点。中间区域点一下呼出工具栏。') + '</div>' +
      '<div class="eb-group">' + L.t('朗读') + '</div>' +
      '<div class="eb-row"><label>' + L.t('语速') + '</label><div class="grow">' +
      [[0.8, L.t('慢')], [1, L.t('常')], [1.2, L.t('快')], [1.5, L.t('极快')]].map(function (x) {
        return '<button class="eb-chip' + (Math.abs(PRE.ttsRate - x[0]) < .01 ? ' on' : '') + '" data-tr="' + x[0] + '">' + x[1] + '</button>';
      }).join('') + '</div></div>' +
      '<div class="eb-row"><label>' + L.t('语气') + '</label><div class="grow">' +
      TTS_STYLES.map(function (x) {
        return '<button class="eb-chip' + (PRE.ttsStyle === x.id ? ' on' : '') + '" data-ts="' + x.id + '">' + L.t(x.name) + '</button>';
      }).join('') + '</div></div>' +
      '<div class="eb-row"><label>' + L.t('语调') + '</label><div class="grow">' +
      TTS_PITCHES.map(function (x) {
        return '<button class="eb-chip' + (Math.abs(ttsPitchOf() - x.value) < .01 ? ' on' : '') + '" data-tp="' + x.value + '">' + L.t(x.name) + '</button>';
      }).join('') + '</div></div>' +
      '<div class="eb-row"><label>' + L.t('间隙') + '</label><div class="grow">' +
      TTS_GAPS.map(function (x) {
        return '<button class="eb-chip' + (PRE.ttsGap === x.id ? ' on' : '') + '" data-tg="' + x.id + '">' + L.t(x.name) + '</button>';
      }).join('') + '</div></div>' +
      '<div class="eb-row"><label>' + L.t('自动语气') + '</label><div class="grow"><button class="eb-sw' + (PRE.ttsAuto ? ' on' : '') + '" data-sw="ttsAuto"></button></div></div>' +
      '<div class="eb-note">' + L.t('自动语气按标点、句长与段落安排停顿和轻重，不识别语义；关闭后与旧版听感一致。') + '</div>' +
      '<div class="eb-row' + (PRE.ttsAuto ? '' : ' dim') + '"><label>' + L.t('强调') + '</label><div class="grow"><button class="eb-sw' + (PRE.ttsEmph ? ' on' : '') + '" data-sw="ttsEmph"' + (PRE.ttsAuto ? '' : ' disabled') + '></button></div></div>' +
      '<div class="eb-note">' + L.t('叠词与拟声词轻微加重，需在自动语气开启时生效；误判时关闭即可。') + '</div>' +
      '<div class="eb-row"><label>' + L.t('音色') + '</label><div class="grow"><select id="ebVoice" style="width:100%;height:28px;border-radius:7px;border:1px solid var(--eb-line);background:var(--eb-sunk);color:var(--eb-tx);font-size:11.5px;padding:0 6px"></select></div></div>' +
      '<div class="eb-group">' + L.t('阅读') + '</div>' +
      '<div class="eb-row"><label>' + L.t('屏幕常亮') + '</label><div class="grow"><button class="eb-sw' + (PRE.wake ? ' on' : '') + '" data-sw="wake"></button></div></div>' +
      '<div class="eb-row"><label>' + L.t('隐身阅读') + '</label><div class="grow"><button class="eb-sw' + (PRE.imm ? ' on' : '') + '" data-sw="imm"></button></div></div>' +
      '<div class="eb-note">' + L.t('隐身阅读不写入进度、不上报时长，本次阅读不会出现在统计里。') + '</div>' +
      '<div class="eb-group">' + L.t('帮助') + '</div>' +
      '<div class="eb-row"><label>' + L.t('操作指引') + '</label><div class="grow">' +
      '<button class="eb-chip" data-guide="1">' + L.t('重新观看') + '</button></div></div>' +
      '<div class="eb-note">' + L.t('顶栏、目录、底栏功能栏、进度条、触控分区、选中标注与章末接续，逐步演示一遍。') + '</div>' +
      '</div>';
    P.querySelector('[data-a=close]').onclick = function () { closePanels(); };
    var gbtn = P.querySelector('[data-guide]');
    if (gbtn) gbtn.onclick = function () { closePanels(); openGuide(); };
    [].slice.call(P.querySelectorAll('[data-th]')).forEach(function (d) {
      d.onclick = function () { PRE.theme = d.dataset.th; savePrefs(); applyTheme(); paintSet('set'); };
    });
    [].slice.call(P.querySelectorAll('[data-lt]')).forEach(function (b) {
      b.onclick = function () { switchLayout(b.dataset.lt); };
    });
    [].slice.call(P.querySelectorAll('[data-dr]')).forEach(function (b) {
      b.onclick = function () {
        if (PRE.layout === 'scroll') return toast(L.t('连续滚动下方向不生效，先切到分页'));
        PRE.dir = b.dataset.dr; savePrefs(); applyLayout(); paintSet('set');
      };
    });
    [].slice.call(P.querySelectorAll('[data-sz]')).forEach(function (b) {
      b.onclick = function () {
        PRE.size = clamp(PRE.size + (+b.dataset.sz), 13, 32);
        savePrefs(); applyType(); paintSet('set');
      };
    });
    [].slice.call(P.querySelectorAll('[data-lh]')).forEach(function (b) {
      b.onclick = function () { PRE.lh = +b.dataset.lh; savePrefs(); applyType(); paintSet('set'); };
    });
    [].slice.call(P.querySelectorAll('[data-pa]')).forEach(function (b) {
      b.onclick = function () { PRE.para = +b.dataset.pa; savePrefs(); applyType(); paintSet('set'); };
    });
    [].slice.call(P.querySelectorAll('[data-ft]')).forEach(function (b) {
      b.onclick = function () { PRE.font = b.dataset.ft; savePrefs(); applyType(); paintSet('set'); };
    });
    [].slice.call(P.querySelectorAll('[data-tr]')).forEach(function (b) {
      b.onclick = function () {
        PRE.ttsRate = +b.dataset.tr; savePrefs(); paintSet('set');
        if (EB.ttsOn) ttsRestart();
      };
    });
    [].slice.call(P.querySelectorAll('[data-ts]')).forEach(function (b) {
      b.onclick = function () {
        PRE.ttsStyle = b.dataset.ts; savePrefs(); paintSet('set');
        if (EB.ttsOn) ttsRestart();
      };
    });
    [].slice.call(P.querySelectorAll('[data-tp]')).forEach(function (b) {
      b.onclick = function () {
        PRE.ttsPitch = +b.dataset.tp; savePrefs(); paintSet('set');
        if (EB.ttsOn) ttsRestart();
      };
    });
    [].slice.call(P.querySelectorAll('[data-tg]')).forEach(function (b) {
      b.onclick = function () {
        PRE.ttsGap = b.dataset.tg; savePrefs(); paintSet('set');
        if (EB.ttsOn) ttsRestart();
      };
    });
    [].slice.call(P.querySelectorAll('[data-sw]')).forEach(function (b) {
      b.onclick = function () {
        var k = b.dataset.sw;
        if (k === 'ttsEmph' && !PRE.ttsAuto) return;
        PRE[k] = !PRE[k];
        if (k === 'ttsAuto') PRE.ttsEmph = PRE.ttsAuto && !!PRE.ttsEmph;
        savePrefs();
        b.classList.toggle('on', PRE[k]);
        if (k === 'pubcss') syncPub();
        if (k === 'wake') PRE.wake ? wakeOn() : wakeOff();
        if (k === 'ttsAuto') paintSet('set');
        if ((k === 'ttsAuto' || k === 'ttsEmph') && EB.ttsOn) ttsRestart();
        if (k === 'imm') {
          try {
            if (PRE.imm) sessionStorage.setItem(immKey(), JSON.stringify({ ch: EB.ch, p: chapterProgress() }));
            else sessionStorage.removeItem(immKey());
          } catch (e) { }
          paintTop();
          toast(PRE.imm ? L.t('隐身阅读已开启，本次不记录进度') : L.t('已恢复记录进度'));
        }
      };
    });
    var range = $('ebMeasure');
    range.addEventListener('input', function () {
      PRE.measure = +range.value;
      $('ebMeasureV').textContent = PRE.measure;
      applyType();
    });
    range.addEventListener('change', savePrefs);
    fillVoices();
  }

  function fillVoices() {
    var sel = $('ebVoice'); if (!sel) return;
    var list = ttsVoices();
    if (!list.length) {
      try { if (window.lantaiBridge && window.lantaiBridge.ttsLoadVoices) window.lantaiBridge.ttsLoadVoices(); } catch (e) { }
    }
    var cur = String(PRE.ttsVoice || '');
    if (cur && !/^[0-9]+$/.test(cur)) {
      for (var i = 0; i < list.length; i++) if (list[i].name === cur) { cur = String(list[i].tone); break; }
    }
    if (!cur) {
      try { if (window.lantaiBridge && window.lantaiBridge.ttsToneNow) cur = String(window.lantaiBridge.ttsToneNow()); } catch (e) { cur = ''; }
    }
    var groups = { zh: [], en: [], other: [] };
    list.forEach(function (v) {
      var tag = String(v.lang || '').toLowerCase(), name = String(v.name || '');
      if (/^zh|^cmn/.test(tag) || /Chinese|中文|普通话/i.test(name)) groups.zh.push(v);
      else if (/^en/.test(tag) || /English|英语/i.test(name)) groups.en.push(v);
      else groups.other.push(v);
    });
    var optgroup = function (label, rows) {
      if (!rows.length) return '';
      return '<optgroup label="' + label + '">' + rows.map(function (v) {
        var label2 = v.name + ' · ' + v.lang + (v.localService ? '' : ' · ' + L.t('需下载'));
        return '<option value="' + v.tone + '"' + (cur === String(v.tone) ? ' selected' : '') + '>' +
          esc(label2) + '</option>';
      }).join('') + '</optgroup>';
    };
    var body = optgroup(L.t('中文'), groups.zh) + optgroup(L.t('英语'), groups.en) +
      optgroup(L.t('其他'), groups.other);
    sel.innerHTML = body || ('<option value="">' + L.t('系统默认') + '</option>');
    sel.onchange = function () {
      PRE.ttsVoice = String(sel.value);
      savePrefs();
      try { if (window.lantaiBridge && window.lantaiBridge.ttsTone) window.lantaiBridge.ttsTone(+sel.value); } catch (e) { }
    };
  }

  function ttsVoices() {
    var raw = '';
    try {
      raw = window.lantaiBridge && window.lantaiBridge.ttsVoices ? window.lantaiBridge.ttsVoices() : '';
    } catch (e) { raw = ''; }
    var list = [];
    try { list = JSON.parse(raw || '[]'); } catch (e) { list = []; }
    if ((!list || !list.length) && EB.voices) list = EB.voices;
    return (list || []).map(function (v) {
      return { name: v.name, tone: v.tone, lang: v.lang, localService: !!v.ready, voiceURI: 'lantai:' + v.tone };
    });
  }

  function annFiltered() {
    var tab = EB.annTab || 'all';
    var q = String(EB.annQ || '').trim().toLowerCase();
    return EB.anns.filter(function (a) {
      if (tab === 'bookmark' && a.kind !== 'bookmark') return false;
      if (tab === 'mark' && a.kind === 'bookmark') return false;
      if (!q) return true;
      var title = (EB.chs.get(a.ch) || {}).title || '';
      return (String(a.mark || '') + ' ' + String(a.note || '') + ' ' + title).toLowerCase().indexOf(q) >= 0;
    }).sort(function (a, b) { return a.ch - b.ch || (a.at || 0) - (b.at || 0); });
  }

  function paintAnns() {
    var P = $('ebSet');
    var bm = 0;
    EB.anns.forEach(function (a) { if (a.kind === 'bookmark') bm++; });
    var list = annFiltered();
    var tab = EB.annTab || 'all';
    P.innerHTML =
      '<div class="eb-panel-h"><b>' + L.t('书签与标注') + '</b><span class="mono">' + bm + L.t(' 书签 · ') + (EB.anns.length - bm) + L.t(' 标注') + '</span>' +
      '<button class="eb-btn" data-a="close">' + ico('close') + '</button></div>' +
      '<div class="eb-seg">' +
      [['all', L.t('全部')], ['bookmark', L.t('书签')], ['mark', L.t('标注')]].map(function (x) {
        return '<button class="eb-chip' + (tab === x[0] ? ' on' : '') + '" data-atab="' + x[0] + '">' + x[1] + '</button>';
      }).join('') + '</div>' +
      '<div class="eb-search">' + ico('search') + '<input id="ebAnnQ" placeholder="' + L.t('搜索书签、标注或笔记') + '" autocomplete="off" value="' + esc(EB.annQ || '') + '"></div>' +
      '<div style="padding:0 12px 8px"><button class="eb-chip" data-bmadd="1" style="width:100%">' + ico('bookmark', 13) + L.t(' 给第 ') + EB.ch + L.t(' 章加书签') + '</button></div>' +
      '<div class="eb-list" id="ebAnnList"></div>';
    P.querySelector('[data-a=close]').onclick = function () { closePanels(); };
    [].slice.call(P.querySelectorAll('[data-atab]')).forEach(function (b) {
      b.onclick = function () { EB.annTab = b.dataset.atab; paintAnns(); markTop(); };
    });
    var qi = $('ebAnnQ');
    qi.addEventListener('input', function () {
      EB.annQ = this.value;
      clearTimeout(EB.annQT);
      EB.annQT = setTimeout(paintAnns, 200);
    });
    P.querySelector('[data-bmadd]').onclick = addBookmark;
    var box = $('ebAnnList');
    if (!list.length) {
      box.innerHTML = '<div class="eb-empty">' + (EB.anns.length ? L.t('没有匹配的条目') : L.t('还没有书签和标注') + '<br><span style="font-size:11px">' + L.t('按 B 给当前章加书签；选中文字可高亮、划下划线或写笔记') + '</span>') + '</div>';
      return;
    }
    box.innerHTML = list.map(function (a) {
      var col = a.kind === 'bookmark' ? 'var(--eb-acc)' : a.color;
      return '<div class="eb-ann" data-annjump="' + a.id + '" style="border-left-color:' + col + '">' +
        (a.note ? '<div class="n">' + esc(a.note) + '</div>' : '') +
        (a.mark ? '<div class="q">' + esc(a.mark) + '</div>' : '') +
        '<div class="m"><span>' + (MARK_CN[a.kind] || L.t('标注')) + '</span><span>' + (a.ch || 0) + L.t(' 章') + '</span><span>' + ago(a.at) + '</span>' +
        '<button class="x" data-annedit="' + a.id + L.t('">编辑') + '</button><button class="x" data-anndel="' + a.id + L.t('">删除') + '</button></div></div>';
    }).join('');
    [].slice.call(box.querySelectorAll('[data-annjump]')).forEach(function (n) {
      n.onclick = function (ev) {
        if (ev.target.closest('[data-anndel]') || ev.target.closest('[data-annedit]')) return;
        jumpAnn(n.dataset.annjump);
      };
    });
    [].slice.call(box.querySelectorAll('[data-anndel]')).forEach(function (n) {
      n.onclick = function (ev) { ev.stopPropagation(); delAnn(n.dataset.anndel); };
    });
    [].slice.call(box.querySelectorAll('[data-annedit]')).forEach(function (n) {
      n.onclick = function (ev) { ev.stopPropagation(); editAnn(n.dataset.annedit); };
    });
  }

  function addBookmark() {
    if (!EB.ready) return toast(L.t('章节还在载入'), 'err');
    var ch = EB.ch;
    var ref = EB.chs.get(ch) || {};
    if (!ref.href) return toast(L.t('这一章还没有可锚定的位置'), 'err');
    var dup = null;
    EB.anns.forEach(function (a) { if (a.kind === 'bookmark' && a.ch === ch) dup = a; });
    if (dup) { EB.annTab = 'bookmark'; paintAnns(); return toast(L.t('第 ') + ch + L.t(' 章已有书签')); }
    var p = chapterProgress();
    req('api/lantai/v1/annotations', {
      method: 'POST',
      body: {
        bookId: EB.bookId, href: ref.href, progression: (ch - 1 + p) / Math.max(1, EB.total),
        textBefore: '', textHighlight: '', textAfter: '', color: '#C9A24B', marker: 'BOOKMARK',
        note: isPaged() ? L.t('本章 ') + (p * 100).toFixed(2) + L.t('% 处') : ''
      }
    }).then(function (dto) {
      EB.anns.unshift({
        id: dto.id, href: ref.href, ch: ch, color: '#C9A24B', kind: 'bookmark',
        note: dto.note || '', before: '', mark: '', after: '', progression: 0, at: Date.now()
      });
      toast(L.t('已在第 ') + ch + L.t(' 章加书签'), 'ok');
      if (EB.panel === 'ann') paintAnns();
    }).catch(function (e) { toast(L.t('书签保存失败：') + errText(e), 'err'); });
  }

  function editAnn(id) {
    var a = null;
    EB.anns.forEach(function (x) { if (x.id === id) a = x; });
    if (!a) return;
    var pick = { color: a.color, kind: a.kind };
    var ask = $('ebAsk');
    ask.innerHTML = '<div class="card"><h4>' + L.t('编辑') + (MARK_CN[a.kind] || L.t('标注')) + '</h4>' +
      '<div class="q">' + esc(a.mark || (L.t('第 ') + a.ch + L.t(' 章'))) + '</div>' +
      '<div style="display:flex;gap:8px;margin:10px 0">' +
      COLORS.map(function (c) {
        return '<button data-ec="' + c + '" style="width:26px;height:26px;border-radius:50%;border:2px solid ' +
          (a.color === c ? 'var(--eb-acc)' : 'transparent') + ';background:' + c + ';cursor:pointer"></button>';
      }).join('') + '</div>' +
      '<div class="eb-seg" style="margin-bottom:10px">' +
      [['highlight', L.t('高亮')], ['underline', L.t('下划线')], ['comment', L.t('笔记')], ['bookmark', L.t('书签')]].map(function (x) {
        return '<button class="eb-chip' + (a.kind === x[0] ? ' on' : '') + '" data-ek="' + x[0] + '">' + x[1] + '</button>';
      }).join('') + '</div>' +
      '<textarea id="ebEditNote" placeholder="' + L.t('笔记…') + '">' + esc(a.note || '') + '</textarea>' +
      '<div class="ft"><button data-x>' + L.t('取消') + '</button><button class="pri" data-ok>' + L.t('保存') + '</button></div></div>';
    ask.classList.add('on');
    ask.querySelector('[data-x]').onclick = function () { ask.classList.remove('on'); };
    [].slice.call(ask.querySelectorAll('[data-ec]')).forEach(function (b) {
      b.onclick = function () {
        pick.color = b.dataset.ec;
        [].slice.call(ask.querySelectorAll('[data-ec]')).forEach(function (o) {
          o.style.borderColor = o === b ? 'var(--eb-acc)' : 'transparent';
        });
      };
    });
    [].slice.call(ask.querySelectorAll('[data-ek]')).forEach(function (b) {
      b.onclick = function () {
        pick.kind = b.dataset.ek;
        [].slice.call(ask.querySelectorAll('[data-ek]')).forEach(function (o) { o.classList.toggle('on', o === b); });
      };
    });
    ask.querySelector('[data-ok]').onclick = function () {
      var note = $('ebEditNote').value.trim();
      ask.classList.remove('on');
      req('api/lantai/v1/annotations/' + a.id, {
        method: 'PATCH',
        body: { color: pick.color, marker: String(pick.kind).toUpperCase(), note: note }
      }).then(function () {
        a.color = pick.color; a.kind = pick.kind; a.note = note; a.at = Date.now();
        repaintChapter(a.ch);
        paintAnns();
        toast(L.t('已更新'));
      }).catch(function (e) { toast(L.t('更新失败：') + errText(e), 'err'); });
    };
    setTimeout(function () { var t = $('ebEditNote'); if (t) t.focus(); }, 40);
  }

  function jumpAnn(id) {
    var a = null;
    for (var i = 0; i < EB.anns.length; i++) if (EB.anns[i].id === id) a = EB.anns[i];
    if (!a) return;
    closePanels();
    var go = EB.secs.has(a.ch) ? Promise.resolve() : reset(a.ch).then(function () { scrollToSec(EB.secs.get(a.ch), 0); });
    go.then(function () {
      setTimeout(function () {
        var mk = EB.docEl && EB.docEl.querySelector('mark[data-ann="' + id + '"]');
        if (!mk) return toast(L.t('这一章没有找到标注位置'), 'err');
        var vr = EB.view.getBoundingClientRect();
        var mr = mk.getBoundingClientRect();
        EB.view.scrollTop += mr.top - vr.top - EB.view.clientHeight * 0.36;
        mk.style.boxShadow = '0 0 0 3px ' + hexA(a.color, .5);
        setTimeout(function () { mk.style.boxShadow = ''; }, 1200);
      }, 120);
    });
  }

  function loadAnns() {
    return req('api/lantai/v1/annotations?bookId=' + EB.bookId)
      .then(function (list) {
        EB.anns = (list || []).map(function (a) {
          var n = chOfHref(a.href);
          return {
            id: a.id, href: a.href || '', ch: n, color: a.color || COLORS[0],
            kind: String(a.marker || 'HIGHLIGHT').toLowerCase(), note: a.note || '',
            before: a.textBefore || '', mark: a.textHighlight || '', after: a.textAfter || '',
            progression: typeof a.progression === 'number' ? a.progression : 0,
            at: new Date(a.lastModifiedDate || a.createdDate || Date.now()).getTime()
          };
        });
        EB.anns.forEach(function (a) { if (a.ch) repaintChapter(a.ch); });
        if (EB.panel === 'ann') paintAnns();
      })
      .catch(function () { });
  }

  function remapAnns() {
    var changed = false;
    EB.anns.forEach(function (a) {
      if (!a.ch) {
        var n = chOfHref(a.href);
        if (n) { a.ch = n; changed = true; }
      }
    });
    if (!changed) return;
    EB.anns.forEach(function (a) { if (a.ch === EB.ch) repaintChapter(a.ch); });
    if (EB.panel === 'ann') paintAnns();
  }

  function chOfHref(href) {
    var target = String(href || '').split('#')[0];
    if (!target) return 0;
    var m = target.match(/^#page=(\d+)$/);
    if (m) return +m[1];
    var hit = 0;
    EB.chs.forEach(function (c, n) { if (c.href === target) hit = n; });
    return hit;
  }

  function repaintChapter(n) {
    var sec = EB.secs.get(n);
    if (!sec) return;
    [].slice.call(sec.querySelectorAll('mark[data-ann]')).forEach(function (mk) {
      var txt = document.createTextNode(mk.textContent);
      mk.parentNode.replaceChild(txt, mk);
      txt.parentNode.normalize();
    });
    paintMarks(sec, n);
  }

  function textMap(root) {
    var sec = root.closest ? root.closest('.sec') : null;
    var sig = sec ? (root.childElementCount + ':' + root.getElementsByTagName('*').length + ':' + (root.textContent || '').length) : '';
    if (sec && sec.__map && sec.__sig === sig) return sec.__map;
    var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
      acceptNode: function (n) {
        if (!n.nodeValue || !n.nodeValue.length) return NodeFilter.FILTER_REJECT;
        var p = n.parentNode;
        if (p && /^(SCRIPT|STYLE|TEXTAREA)$/.test(p.nodeName)) return NodeFilter.FILTER_REJECT;
        return NodeFilter.FILTER_ACCEPT;
      }
    });
    var segs = [], total = 0, n;
    while ((n = walker.nextNode())) {
      segs.push({ node: n, start: total, end: total + n.nodeValue.length });
      total += n.nodeValue.length;
    }
    var res = { segs: segs, length: total, text: segs.map(function (s) { return s.node.nodeValue; }).join('') };
    if (sec) { sec.__map = res; sec.__sig = sig; }
    return res;
  }

  function segOffset(map, node, off) {
    if (!map || !node) return -1;
    var list = map.segs;
    for (var i = 0; i < list.length; i++) if (list[i].node === node) return list[i].start + (off || 0);
    return -1;
  }

  function locate(map, before, mark, after) {
    if (!mark) return null;
    var whole = map.text;
    if (before) {
      var tail = before.slice(-26);
      var at = whole.indexOf(tail + mark + (after || '').slice(0, 26));
      if (at >= 0) return { start: at + tail.length, end: at + tail.length + mark.length };
    }
    var idx = whole.indexOf(mark);
    if (idx < 0) return null;
    return { start: idx, end: idx + mark.length };
  }

  function paintMarks(root, n) {
    var list = EB.anns.filter(function (a) { return a.ch === n && a.mark; });
    if (!list.length) return;
    var map = textMap(root);
    list.forEach(function (a) {
      if (root.querySelector('mark[data-ann="' + a.id + '"]')) return;
      var pos = locate(map, a.before, a.mark, a.after);
      if (!pos) return;
      wrapRange(root, map, pos.start, pos.end, a);
    });
  }

  function wrapRange(root, map, start, end, a) {
    var segs = map.segs.filter(function (s) { return s.end > start && s.start < end; });
    for (var i = segs.length - 1; i >= 0; i--) {
      var s = segs[i];
      var from = Math.max(0, start - s.start);
      var to = Math.min(s.node.nodeValue.length, end - s.start);
      if (to <= from) continue;
      var node = s.node;
      if (from > 0) node = node.splitText(from);
      if (to - from < node.nodeValue.length) node.splitText(to - from);
      var mk = document.createElement('mark');
      mk.setAttribute('data-ann', a.id);
      mk.style.background = hexA(a.color, a.kind === 'highlight' ? .34 : .12);
      mk.style.borderBottom = a.kind === 'underline' ? '2px solid ' + a.color : 'none';
      mk.style.padding = '1px 0';
      mk.addEventListener('click', function (ev) {
        ev.stopPropagation();
        jumpAnn(this.getAttribute('data-ann'));
      });
      node.parentNode.insertBefore(mk, node);
      mk.appendChild(node);
    }
  }

  function currentSelection() {
    var sh = EB.shadow;
    if (sh && typeof sh.getSelection === 'function') {
      try {
        var s = sh.getSelection();
        if (s && s.rangeCount) return s;
      } catch (e) { }
    }
    return document.getSelection();
  }

  function hideSelBox() {
    var box = $('ebSel');
    if (box) box.classList.remove('on');
    EB.sel = null;
  }

  function handEls() {
    var h = $('ebHands');
    if (!h) return null;
    return { box: h, s: h.querySelector('.hs'), e: h.querySelector('.he') };
  }

  function placeHands(range) {
    var h = handEls();
    if (!h || !h.s || !h.e || !range) return;
    var rects = range.getClientRects();
    var list = [];
    for (var i = 0; i < rects.length; i++) {
      if (rects[i].width > 0 && rects[i].height > 0) list.push(rects[i]);
    }
    if (!list.length) { h.box.classList.remove('on'); return; }
    var first = list[0], last = list[list.length - 1];
    h.s.style.left = (first.left + 2) + 'px';
    h.s.style.top = first.bottom + 'px';
    h.e.style.left = (last.right - 2) + 'px';
    h.e.style.top = last.bottom + 'px';
    h.box.classList.add('on');
  }

  function hideHands() {
    var h = handEls();
    if (h) h.box.classList.remove('on');
  }

  function placeSelBox(range) {
    var box = $('ebSel');
    if (!box || !range) return;
    box.classList.add('on');
    var ur = range.getBoundingClientRect();
    if (!EB.selW) {
      EB.selW = box.offsetWidth || 236;
      EB.selH = box.offsetHeight || 38;
    }
    var bw = EB.selW;
    var bh = EB.selH;
    var bhid = parseFloat(getComputedStyle($('eb')).getPropertyValue('--eb-bot-h')) || 0;
    var loY = SAFE.t + 8;
    var hiY = innerHeight - SAFE.b - bhid - 8;
    var ax = ur.width ? ur.left + ur.width / 2 : innerWidth / 2;
    var left = clamp(ax - bw / 2, 8, Math.max(8, innerWidth - bw - 8));
    var top = ur.top - bh - 14;
    if (top < loY) top = ur.bottom + 14;
    top = clamp(top, loY, Math.max(loY, hiY - bh));
    box.style.left = left + 'px';
    box.style.top = top + 'px';
  }

  function bindSelBox(box) {
    [].slice.call(box.querySelectorAll('button')).forEach(function (btn) {
      btn.onclick = function (ev) {
        ev.preventDefault();
        ev.stopPropagation();
        if (btn.dataset.more) {
          EB.selMore = !EB.selMore;
          fillSelBox(box, true);
          if (EB.selRange) {
            placeSelBox(EB.selRange);
            placeHands(EB.selRange);
          }
          return;
        }
        if (btn.dataset.copy) {
          var txt = EB.selText || (EB.selRange ? String(EB.selRange.toString() || '').replace(/\s+/g, ' ').trim() : '');
          if (navigator.clipboard && txt) {
            navigator.clipboard.writeText(txt).then(function () { toast(L.t('已复制')); }).catch(function () { toast(L.t('复制失败'), 'err'); });
          } else {
            toast(L.t('没有可复制的内容'), 'err');
          }
          clearSel();
          return;
        }
        if (btn.dataset.tts) {
          var r = EB.selRange;
          var a = r ? ttsAnchorOf(r.startContainer, r.startOffset) : null;
          clearSel();
          if (!a) return toast(L.t('这里没有可朗读的文字'), 'err');
          if (a.ch !== EB.ch) {
            var tsec = EB.secs.get(a.ch);
            if (!tsec) return toast(L.t('这一章没有可朗读的文字'), 'err');
            scrollToSec(tsec, 0);
            ttsStart(null, a.idx, false, a.ch);
            return;
          }
          if (EB.ttsOn) ttsSeek(a.idx); else ttsStart(null, a.idx);
          return;
        }
        if (btn.dataset.note) createAnn('#C9A24B', 'comment', true);
        else createAnn(btn.dataset.c || '#C9A24B', btn.dataset.k || 'highlight', false);
      };
    });
  }

  var SEL_TOP = 3;

  function dotBtn(c) {
    return '<button data-c="' + c + '" data-k="highlight" title="' + L.t('高亮') + '"><span class="dot" style="background:' + c + '"></span></button>';
  }

  function fillSelBox(box, full) {
    box.dataset.tpl = full ? 'full' : 'lite';
    EB.selW = 0;
    EB.selH = 0;
    var copyBtn = '<button data-copy="1" class="cp" title="' + L.t('复制') + '">' + ico('copy', 14) + '<span>' + L.t('复制') + '</span></button>';
    var ttsBtn = '<button data-tts="1" title="' + L.t('从这里朗读') + '">' + ico('volume', 14) + '</button>';
    var head;
    if (full) {
      head = COLORS.slice(0, SEL_TOP).map(dotBtn).join('') +
        '<button data-more="1" class="more' + (EB.selMore ? ' on' : '') + '" title="' + L.t('更多颜色') + '">' + ico('brush', 14) + '</button>' +
        '<div class="sep"></div>' +
        '<button data-k="underline" title="' + L.t('下划线') + '">' + ico('edit', 14) + '</button>' +
        '<button data-note="1" title="' + L.t('写笔记') + '">' + ico('marker', 14) + '</button>' +
        copyBtn + ttsBtn;
    } else {
      head = copyBtn + ttsBtn;
    }
    box.innerHTML = '<div class="row">' + head + '</div>' +
      (full && EB.selMore ? '<div class="row more">' + COLORS.slice(SEL_TOP).map(dotBtn).join('') + '</div>' : '');
    bindSelBox(box);
  }

  function showSelBox(range) {
    if (!range || !EB.open || !EB.shadow) return;
    var box = $('ebSel');
    if (!box) return;
    var text = String(range.toString() || '').replace(/\s+/g, ' ').trim();
    if (!text.length) { hideSelBox(); hideHands(); clearSelPaint(); return; }
    var node = range.commonAncestorContainer;
    if (node.nodeType === 3) node = node.parentNode;
    if (!node || !EB.shadow.contains(node)) { hideSelBox(); hideHands(); clearSelPaint(); return; }
    var sec = node.closest ? node.closest('.sec') : null;
    if (!sec) { hideSelBox(); hideHands(); clearSelPaint(); return; }
    var n = +sec.dataset.ch;
    var ct = sec.querySelector('.ct') || sec;
    var map = textMap(ct);
    var start = segOffset(map, range.startContainer, range.startOffset);
    if (start < 0) {
      try {
        if (ct.contains(range.startContainer)) {
          var probe = document.createRange();
          probe.selectNodeContents(ct);
          probe.setEnd(range.startContainer, range.startOffset);
          start = probe.toString().length;
        }
      } catch (e) {
        start = -1;
      }
    }
    if (start < 0 || start > map.length) start = map.text.indexOf(text);
    var ok = start >= 0 && start + text.length <= map.length;
    EB.selText = text;
    EB.sel = ok ? {
      ch: n, start: start, end: start + text.length, text: text,
      before: map.text.slice(Math.max(0, start - 40), start),
      after: map.text.slice(start + text.length, start + text.length + 40)
    } : null;
    if (box.dataset.tpl !== (ok ? 'full' : 'lite')) fillSelBox(box, ok);
    placeSelBox(range);
    placeHands(range);
  }

  function clearSel() {
    var box = $('ebSel');
    if (box) box.classList.remove('on');
    hideHands();
    EB.sel = null;
    EB.selText = '';
    EB.selMode = '';
    EB.selFix = null;
    clearSelPaint();
    var s = currentSelection();
    if (s) s.removeAllRanges();
  }

  function createAnn(color, kind, withNote) {
    var sel = EB.sel;
    if (!sel) return;
    clearSel();
    var a = {
      id: '', ch: sel.ch, color: color, kind: kind, note: '',
      before: sel.before, mark: sel.text.slice(0, 400), after: sel.after,
      progression: (sel.ch - 1) / Math.max(1, EB.total)
    };
    if (!withNote) return saveAnn(a);
    var ask = $('ebAsk');
    ask.innerHTML = '<div class="card"><h4>' + L.t('写一条笔记') + '</h4><div class="q">' + esc(sel.text) + '</div>' +
      '<textarea id="ebNote" placeholder="' + L.t('想法、出处、待查…') + '"></textarea>' +
      '<div class="ft"><button data-x>' + L.t('取消') + '</button><button class="pri" data-ok>' + L.t('保存') + '</button></div></div>';
    ask.classList.add('on');
    ask.querySelector('[data-x]').onclick = function () { ask.classList.remove('on'); };
    ask.querySelector('[data-ok]').onclick = function () {
      a.note = $('ebNote').value.trim();
      ask.classList.remove('on');
      saveAnn(a);
    };
    setTimeout(function () { var t = $('ebNote'); if (t) t.focus(); }, 40);
  }

  function saveAnn(a) {
    if (!rt()) return toast(L.t('后端不可用'), 'err');
    var ref = EB.chs.get(a.ch) || {};
    if (!ref.href) return toast(L.t('这一章还没有可锚定的位置'), 'err');
    req('api/lantai/v1/annotations', {
      method: 'POST',
      body: {
        bookId: EB.bookId, href: ref.href, progression: a.progression,
        textBefore: a.before, textHighlight: a.mark, textAfter: a.after,
        color: a.color, marker: String(a.kind).toUpperCase(), note: a.note || ''
      }
    }).then(function (dto) {
      var item = {
        id: dto.id, href: ref.href, ch: a.ch, color: a.color, kind: a.kind, note: a.note || '',
        before: a.before, mark: a.mark, after: a.after, progression: a.progression,
        at: Date.now()
      };
      EB.anns.unshift(item);
      var sec = EB.secs.get(a.ch);
      if (sec) paintMarks(sec, a.ch);
      if (EB.panel === 'ann') paintAnns();
      if (typeof renderNav === 'function') renderNav();
      toast(L.t('已保存「') + (MARK_CN[a.kind] || L.t('标注')) + L.t('」'));
    }).catch(function (e) { toast(L.t('保存失败：') + errText(e), 'err'); });
  }

  function delAnn(id) {
    req('api/lantai/v1/annotations/' + id, { method: 'DELETE' })
      .then(function () {
        var ch = 0;
        EB.anns = EB.anns.filter(function (a) { if (a.id === id) { ch = a.ch; return false; } return true; });
        if (ch) repaintChapter(ch);
        paintAnns();
        toast(L.t('标注已删除'));
      })
      .catch(function (e) { toast(L.t('删除失败：') + errText(e), 'err'); });
  }

  function chapterText(n) {
    var sec = EB.secs.get(n);
    if (!sec) return '';
    var ct = sec.querySelector('.ct') || sec;
    return String(ct.textContent || '').replace(/\s+/g, ' ').trim();
  }

  var TTS_SOFT = /[，,、；;：:]/;
  var TTS_END = /[。！？!?…]/;
  function ttsCutAt(text, start, end) {
    var lo = Math.max(start + 60, end - 40);
    for (var i = end - 1; i >= lo; i--) {
      if (TTS_SOFT.test(text[i])) return i + 1;
    }
    return end;
  }
  function splitSentences(text) {
    var out = [];
    var buf = '';
    for (var i = 0; i < text.length; i++) {
      buf += text[i];
      if (TTS_END.test(text[i]) || (text[i] === '.' && i + 1 < text.length && /\s/.test(text[i + 1]))) {
        while (i + 1 < text.length && TTS_END.test(text[i + 1])) {
          buf += text[++i];
        }
        if (buf.trim()) out.push(buf.trim());
        buf = '';
      } else if (buf.length > 220) {
        var cut = -1;
        for (var j = buf.length - 1; j > 60; j--) {
          if (TTS_SOFT.test(buf[j])) {
            cut = j + 1;
            break;
          }
        }
        if (cut > 0) {
          if (buf.slice(0, cut).trim()) out.push(buf.slice(0, cut).trim());
          buf = buf.slice(cut);
        } else {
          if (buf.trim()) out.push(buf.trim());
          buf = '';
        }
      }
    }
    if (buf.trim()) out.push(buf.trim());
    return out.filter(function (s) { return s.length > 0; });
  }

  var BLOCK_SEL = 'p,div,h1,h2,h3,h4,h5,h6,li,td,blockquote,section,article,figcaption,pre';
  var ttsHL = null;

  function nodePoints(el) {
    var nodes = [], off = 0;
    var w = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, null);
    var n;
    while ((n = w.nextNode())) {
      var p = n.parentNode;
      if (p && /^(SCRIPT|STYLE)$/i.test(p.tagName)) continue;
      var v = n.nodeValue || '';
      if (!v) continue;
      nodes.push({ node: n, start: off, end: off + v.length });
      off += v.length;
    }
    return nodes;
  }

  function pointAt(nodes, offset) {
    for (var i = 0; i < nodes.length; i++) {
      if (offset <= nodes[i].end) return { node: nodes[i].node, offset: Math.max(0, Math.min(nodes[i].node.nodeValue.length, offset - nodes[i].start)) };
    }
    var last = nodes[nodes.length - 1];
    return { node: last.node, offset: last.node.nodeValue.length };
  }

  function sentenceRanges(text) {
    var out = [], start = 0, buf = 0;
    for (var i = 0; i < text.length; i++) {
      buf++;
      if (TTS_END.test(text[i]) || (text[i] === '.' && i + 1 < text.length && /\s/.test(text[i + 1]))) {
        while (i + 1 < text.length && TTS_END.test(text[i + 1])) i++;
        if (text.slice(start, i + 1).trim()) out.push([start, i + 1]);
        start = i + 1;
        buf = 0;
      } else if (buf > 220) {
        var cut = ttsCutAt(text, start, i + 1);
        if (text.slice(start, cut).trim()) out.push([start, cut]);
        start = cut;
        buf = 0;
        i = cut - 1;
      }
    }
    if (text.slice(start).trim()) out.push([start, text.length]);
    return out;
  }

  function ttsSegments(sec) {
    var ct = sec.querySelector('.ct') || sec;
    var out = [];
    var blocks = [].slice.call(ct.querySelectorAll(BLOCK_SEL)).filter(function (el) {
      return !el.querySelector(BLOCK_SEL) && !/^(SCRIPT|STYLE|SVG)$/i.test(el.tagName);
    });
    if (!blocks.length) blocks = [ct];
    blocks.forEach(function (el) {
      var nodes = nodePoints(el);
      if (!nodes.length) return;
      var flat = '';
      nodes.forEach(function (x) { flat += x.node.nodeValue; });
      if (!flat.replace(/[\s\u00a0\u3000]+/g, '')) return;
      sentenceRanges(flat).forEach(function (r) {
        var t = flat.slice(r[0], r[1]).replace(/[\s\u00a0\u3000]+/g, ' ').trim();
        if (!t) return;
        out.push({ text: t, el: el, s: r[0], e: r[1], nodes: nodes });
      });
    });
    return out;
  }

  function ttsMark(el) {
    var roots = [document];
    if (EB.shadow) roots.push(EB.shadow);
    roots.forEach(function (root) {
      [].slice.call(root.querySelectorAll('.tts-cur')).forEach(function (n) { n.classList.remove('tts-cur'); });
    });
    if (el) el.classList.add('tts-cur');
  }

  function ttsPaint(seg) {
    if (!seg || !seg.el) return;
    var nodes = seg.nodes || nodePoints(seg.el);
    if (!nodes.length) return;
    var a = pointAt(nodes, seg.s), b = pointAt(nodes, seg.e);
    var r = document.createRange();
    try {
      r.setStart(a.node, a.offset);
      r.setEnd(b.node, b.offset);
    } catch (e) { return; }
    var reg = !!(window.CSS && CSS.highlights && typeof window.Highlight === 'function');
    if (reg) {
      if (!ttsHL) ttsHL = new window.Highlight();
      ttsHL.clear();
      ttsHL.add(r);
      CSS.highlights.set('eb-tts', ttsHL);
      ttsMark(null);
    } else {
      ttsMark(seg.el);
    }
    ttsReveal(seg.el);
  }

  function ttsClear() {
    stopFollow();
    try {
      if (window.CSS && CSS.highlights && CSS.highlights.has('eb-tts')) CSS.highlights.delete('eb-tts');
    } catch (e) { }
    ttsHL = null;
    ttsMark(null);
    clearSel();
  }

  function stopFollow() {
    if (EB.followT >= 0) {
      clearTimeout(EB.followT);
      EB.followT = -1;
    }
    EB.manualT = 0;
  }

  function noteManual() {
    EB.manualT = Date.now();
    if (EB.followT >= 0) clearTimeout(EB.followT);
    EB.followT = setTimeout(function () {
      EB.followT = -1;
      if (!EB.ttsOn || !EB.tts || !EB.tts.list) return;
      var seg = EB.tts.list[EB.tts.idx];
      if (!seg || !seg.el) return;
      EB.manualT = 0;
      ttsReveal(seg.el);
    }, 2000);
  }

  function ttsReveal(el) {
    var v = EB.view;
    if (!v || !el) return;
    if (EB.manualT && Date.now() - EB.manualT < 2000) return;
    var er = el.getBoundingClientRect(), vr = v.getBoundingClientRect();
    if (!er.height) return;
    EB.autoT = Date.now();
    if (PRE.layout === 'paged') {
      if (er.left < vr.left - 1 || er.right > vr.right + 1) {
        v.scrollLeft += er.left - vr.left - 24;
        EB.page = Math.max(0, Math.round(v.scrollLeft / (v.clientWidth || 1)));
      }
    } else if (er.top < vr.top || er.bottom > vr.bottom) {
      v.scrollTop += er.top - vr.top - vr.height * 0.34;
    }
  }

  function pickVoice() {
    var list = ttsVoices();
    for (var i = 0; i < list.length; i++) if (list[i].name === PRE.ttsVoice) return list[i];
    return null;
  }

  var ttsHoldT = -1;
  var ttsHeld = false;

  function ttsHoldBtn() {
    ttsHoldBtnEnd();
    ttsHeld = false;
    ttsHoldT = setTimeout(function () {
      ttsHoldT = -1;
      ttsHeld = true;
      ttsFromViewport();
    }, 600);
  }

  function ttsHoldBtnEnd() {
    if (ttsHoldT >= 0) {
      clearTimeout(ttsHoldT);
      ttsHoldT = -1;
    }
  }

  function ttsFromViewport() {
    var v = EB.view;
    if (!v) return;
    var vr = v.getBoundingClientRect();
    var chs = Array.from(EB.secs.keys()).sort(function (a, b) { return a - b; });
    var hit = null, hitIdx = 0;
    for (var k = 0; k < chs.length; k++) {
      var sec = EB.secs.get(chs[k]);
      if (!sec) continue;
      var sr = sec.getBoundingClientRect();
      if (sr.bottom <= vr.top + 20 || sr.top >= vr.bottom) continue;
      var list = ttsSegments(sec);
      for (var i = 0; i < list.length; i++) {
        var node = list[i].el;
        if (!node) continue;
        if (node.getBoundingClientRect().bottom > vr.top + 20) { hit = chs[k]; hitIdx = i; break; }
      }
      if (hit != null) break;
    }
    if (hit == null) {
      var c = chapterAt() || EB.ch;
      var s0 = EB.secs.get(c);
      if (!s0 || !ttsSegments(s0).length) return toast(L.t('这一章没有可朗读的文字'), 'err');
      hit = c;
      hitIdx = 0;
    }
    if (EB.ttsOn && hit === EB.ttsCh) ttsSeek(hitIdx);
    else ttsStart(null, hitIdx, false, hit);
    toast(L.t('从第 ') + (hitIdx + 1) + L.t(' 句开始'));
  }

  function ttsBookKey() {
    return 'lantai.tts.' + EB.bookId;
  }

  function ttsSavePos() {
    if (!EB.tts) return;
    try {
      localStorage.setItem(ttsBookKey(), JSON.stringify({
        ch: EB.ttsCh || EB.ch, idx: EB.tts.idx, total: EB.tts.total, at: Date.now()
      }));
    } catch (e) { }
  }

  function ttsResumeAt(list) {
    var raw = null;
    try { raw = JSON.parse(localStorage.getItem(ttsBookKey()) || 'null'); } catch (e) { return 0; }
    if (!raw || raw.ch !== EB.ch || !(raw.idx > 0)) return 0;
    if (list && raw.idx >= list.length) return 0;
    return raw.idx;
  }

  function ttsToggle() {
    if (EB.ttsOn) return ttsStop();
    ttsStart(null, -1);
  }

  function ttsStart(text, from, retune, ch) {
    if (!window.lantaiBridge || !window.lantaiBridge.ttsStart) return toast(L.t('朗读不可用'), 'err');
    var want0 = ch ? Math.round(clamp(ch, 1, EB.total)) : EB.ch;
    EB.ttsCh = want0;
    var sec = text ? null : EB.secs.get(want0);
    var list = retune && EB.tts ? EB.tts.list : (sec ? ttsSegments(sec) : null);
    if (!list || !list.length) {
      var body = text || chapterText(want0);
      if (!body) return toast(L.t('这一章没有可朗读的文字'), 'err');
      list = splitSentences(body).map(function (t) { return { text: t }; });
    }
    if (!list.length) return toast(L.t('这一章没有可朗读的文字'), 'err');
    var want = from == null ? -1 : from;
    if (want < 0) want = ttsResumeAt(list);
    var start = Math.max(0, Math.min(want, list.length - 1));
    EB.tts = { list: list, idx: start, total: list.length };
    EB.ttsOn = true;
    if (!retune) EB.paused = false;
    var plan = ttsPlan(list);
    window.lantaiBridge.ttsStart(JSON.stringify({
      title: (EB.book && EB.book.title) || '',
      sub: chTitle(EB.ch) || '',
      items: plan.items,
      mods: plan.mods,
      speed: PRE.ttsRate,
      from: start,
      retune: !!retune
    }));
    if (list[start] && list[start].el) ttsPaint(list[start]);
    markTop();
  }

  function ttsPauseToggle() {
    if (!EB.ttsOn) return;
    if (EB.paused) {
      EB.paused = false;
      if (window.lantaiBridge) window.lantaiBridge.ttsResume();
    } else {
      EB.paused = true;
      if (window.lantaiBridge) window.lantaiBridge.ttsPause();
    }
  }

  function ttsSeek(i) {
    if (!EB.tts) return;
    EB.tts.idx = Math.max(0, Math.min(i, EB.tts.list.length - 1));
    if (window.lantaiBridge) window.lantaiBridge.ttsSeek(EB.tts.idx);
  }

  function ttsSync(json) {
    var m = null;
    try { m = typeof json === 'string' ? JSON.parse(json) : json; } catch (e) { return; }
    if (!m || !m.type) return;
    if (m.type === 'voices') { EB.voices = m.list || []; if (EB.panel === 'set') fillVoices(); return; }
    if (m.type === 'tone') { PRE.ttsVoice = String(m.tone); savePrefs(); if (EB.panel === 'set') fillVoices(); return; }
    if (m.type === 'stop') {
      EB.ttsOn = false;
      EB.tts = null;
      EB.paused = false;
      ttsClear();
      markTop();
      return;
    }
    if (!EB.ttsOn) return;
    if (m.type === 'start') {
      if (!EB.tts) return;
      EB.tts.idx = m.idx;
      if (typeof m.total === 'number' && m.total > 0) EB.tts.total = m.total;
      var s = EB.tts.list[m.idx];
      if (s && s.el) ttsPaint(s);
      ttsSavePos();
      queueProgress();
      return;
    }
    if (m.type === 'end') {
      if ((EB.ttsCh || EB.ch) < EB.total) return ttsNextChapter();
      return ttsStop();
    }
    if (m.type === 'err') {
      ttsStop();
      return toast(L.t('朗读不可用'), 'err');
    }
  }

  function ttsNextChapter() {
    if (!EB.ttsOn) return;
    var cur = EB.ttsCh || EB.ch;
    if (cur >= EB.total) return ttsStop();
    var n = cur + 1;
    ttsClear();
    tip(L.t('正在载入'), L.t('第 ') + n + L.t(' 章 · 共 ') + num(EB.total) + L.t(' 章'));
    var ready = EB.secs.get(n) ? Promise.resolve(EB.secs.get(n)) : reset(n, 0).then(function () {
      return EB.secs.get(n);
    });
    ready.then(function (sec) {
      tip('');
      if (!EB.ttsOn || !sec) return ttsStop();
      EB.ttsCh = n;
      scrollToSec(sec, 0);
      queueProgress();
      ttsStart(null, 0, false, n);
    }).catch(function () {
      tip('');
      ttsStop();
    });
  }

  function ttsRestart() {
    if (!EB.ttsOn || !EB.tts) return;
    ttsStart(null, EB.tts.idx, true);
  }

  function ttsStop() {
    EB.ttsOn = false;
    EB.tts = null;
    EB.paused = false;
    if (window.lantaiBridge && window.lantaiBridge.ttsStop) window.lantaiBridge.ttsStop();
    ttsClear();
    markTop();
  }

  function wakeOn() {
    if (!navigator.wakeLock || !navigator.wakeLock.request) {
      toast(L.t('屏幕常亮需要 HTTPS 或 localhost'));
      PRE.wake = false;
      savePrefs();
      if (EB.panel === 'set') paintSet('set');
      return;
    }
    navigator.wakeLock.request('screen').then(function (s) {
      EB.wakeLock = s;
      s.addEventListener('release', function () { EB.wakeLock = null; });
    }).catch(function () { toast(L.t('屏幕常亮申请被拒绝'), 'err'); });
  }

  function wakeOff() {
    if (!EB.wakeLock) return;
    try { EB.wakeLock.release(); } catch (e) { }
    EB.wakeLock = null;
  }

  function fullscreen() {
    if (document.fullscreenElement) { document.exitFullscreen().catch(function () { }); return; }
    var r = $('eb');
    (r || document.documentElement).requestFullscreen().catch(function () { toast(L.t('浏览器拒绝了全屏请求'), 'err'); });
  }

  function onKey(ev) {
    if (!EB.open) return;
    if (ev.target && /INPUT|TEXTAREA|SELECT/.test(ev.target.tagName)) return;
    var k = ev.key;
    if (k === 'Escape') {
      if ($('ebLb').classList.contains('on')) { $('ebLb').classList.remove('on'); return; }
      if ($('ebAsk').classList.contains('on')) { $('ebAsk').classList.remove('on'); return; }
      if (EB.panel) { closePanels(); return; }
      if (EB.selRange) { clearSel(); return; }
      return close();
    }
    if ((ev.ctrlKey || ev.metaKey) && (k === 'f' || k === 'F')) { ev.preventDefault(); openPanel('find'); return; }
    if (ev.ctrlKey || ev.metaKey || ev.altKey) return;
    if (k === 'ArrowLeft') { ev.preventDefault(); if (isPaged()) turnPage(-1); else prevChapter(); }
    else if (k === 'ArrowRight') { ev.preventDefault(); if (isPaged()) turnPage(1); else nextChapter(); }
    else if (k === 'PageDown' || (k === ' ' && isPaged())) { ev.preventDefault(); turnPage(1); }
    else if (k === 'PageUp' && isPaged()) { ev.preventDefault(); turnPage(-1); }
    else if (k === 't' || k === 'T') { ev.preventDefault(); openPanel('toc'); }
    else if (k === 's' || k === 'S') { ev.preventDefault(); openPanel('set'); }
    else if (k === 'a' || k === 'A') { ev.preventDefault(); EB.annTab = 'all'; openPanel('ann'); }
    else if (k === 'b' || k === 'B') { ev.preventDefault(); addBookmark(); }
    else if (k === 'd' || k === 'D') { ev.preventDefault(); ttsToggle(); }
    else if (k === 'f' || k === 'F') { ev.preventDefault(); fullscreen(); }
  }

  function open(bookId, opts) {
    opts = opts || {};
    if (!rt()) return toast(L.t('后端不可用'), 'err');
    if (EB.open && EB.bookId === bookId) {
      if (opts.chapter) gotoChapter(opts.chapter, opts.progress || 0);
      return;
    }
    if (EB.open) close(false);
    var boot = (opts.boot && opts.boot.book && opts.boot.book.id === bookId) ? opts.boot : null;
    var b = book(bookId);
    if (!b && boot) {
      b = {
        id: bookId, name: boot.book.title || (opts.meta && opts.meta.title) || '',
        seriesTitle: boot.book.seriesTitle || '', chs: boot.total || 0, pages: 0,
        profile: boot.book.profile || 'EPUB', s: boot.book.seriesTitle || '', status: 'READY'
      };
    }
    if (!b) return toast(L.t('这本书不在书库里'), 'err');
    if (b.status === 'UNSUPPORTED') return toast(L.t('这本书需要先安装转换器'), 'err');

    mount();
    EB.open = true;
    if (opts.imm) { EB.immOnce = !PRE.imm; PRE.imm = true; }
    var sm = null;
    try { sm = series(b.s); } catch (e) { }
    EB.book = { title: (sm && sm.t) || b.name || '', profile: b.profile };
    EB.bookId = bookId;
    EB.total = b.chs > 0 ? b.chs : (b.pages > 0 ? b.pages : 1);
    EB.chs.clear();
    EB.secs.clear();
    EB.park.clear();
    EB.pending = {};
    EB.restoring = false;
    EB.warmF = false; EB.warmB = false;
    EB.anns = [];
    EB.outline = null;
    EB.outlinePending = null;
    EB.vols = null;
    EB.seeking = null;
    EB.drag = null;
    EB.hold = null;
    EB.nav = null;
    EB.pre = null;
    EB.links = [];
    EB.inlines = [];
    pubKey = '';
    var resume = PRE.imm ? immResume(bookId) : null;
    var startOpt = opts.chapter || (resume && resume.ch) || 0;
    EB.ch = startOpt || 1;
    EB.seen = EB.ch;
    EB.ready = false;
    EB.bootDone = false;
    EB.bootAt = Date.now();
    EB.lo = 0;
    EB.hi = 0;
    EB.panel = null;
    $('ebToc').classList.remove('on');
    $('ebSet').classList.remove('on');
    $('eb').classList.add('on');
    $('eb').classList.remove('idle', 'modal');
    applyTheme();
    applyType();
    ensureShadow();
    if (EB.docEl) {
      EB.docEl.className = 'doc' + (isPaged() ? ' paged' : '');
      EB.docEl.removeAttribute('style');
    }
    if (EB.shadow) clearPub(EB.shadow);
    EB.docEl.innerHTML = '';
    paintTop();
    paintBot();
    $('ebView').scrollTop = 0;
    $('ebView').scrollLeft = 0;
    EB.page = 0;
    EB.pages = 1;

    EB.session = {
      id: (window.crypto && crypto.randomUUID) ? crypto.randomUUID() : 'eb_' + bookId + '_' + Date.now(),
      book: bookId, dur: 0, pages: EB.ch, dev: 'webui', devName: L.t('网页端'), start: Date.now(), end: Date.now(), offline: false
    };
    if (typeof pushSession === 'function' && !PRE.imm) pushSession(EB.session);
    startBeat();
    if (PRE.wake) wakeOn();
    if (location.hash.indexOf('#/read/') !== 0) {
      history.replaceState(null, '', '#/read/' + bookId);
      document.title = L.t('兰台 · ') + (EB.book.title || '') + L.t(' · 阅读');
    }
    loadAnns();
    var q = 'api/lantai/v1/read/' + bookId + '/bootstrap?images=inline&w=0&window=3' +
      (startOpt ? '&chapter=' + startOpt : '');
    var onBoot = function (dto) {
      if (!EB.open || EB.bookId !== bookId) return;
      EB.total = dto.total || EB.total;
      (dto.chapters || []).forEach(function (c) { EB.chs.set(c.n, c); });
      EB.nav = dto.nav || null;
      EB.book = Object.assign({}, dto.book || {}, { profile: (dto.book && dto.book.profile) || b.profile });
      EB.docEl.innerHTML = '';
      EB.lo = 0; EB.hi = 0;
      var first = buildSec(dto.first, true);
      EB.docEl.appendChild(first);
      placeJoin(first, +first.dataset.ch);
      syncPub();
      EB.ready = true;
      var startCh = dto.first.chapter;
      EB.ch = startCh;
      EB.seen = startCh;
      paintTop();
      paintBot();
      var restore = 0;
      if (opts.chapter) restore = opts.progress || 0;
      else if (PRE.imm && resume && resume.ch === startCh) restore = resume.p || 0;
      else if (dto.progress && dto.progress.chapter === startCh) restore = dto.progress.progression || 0;
      else restore = opts.progress || 0;
      if (restore > 0.005) restoreTo(restore);
      else scrollToSec(first, 0);
      EB.restoring = true;
      clearTimeout(EB.restoreT);
      EB.restoreT = setTimeout(function () { EB.restoring = false; }, 2800);
      load(startCh + 1, 'after')
        .then(function () { return load(startCh + 2, 'after'); })
        .catch(function () { });
      load(startCh - 1, 'before').catch(function () { });
      if (startCh > 1) load(startCh - 2, 'before').catch(function () { });
      reanchor(startCh, restore);
      if (dto.annotations && dto.annotations.length && !EB.anns.length) loadAnns();
      loadOutline().then(function () {
        if (!EB.open || EB.bookId !== bookId) return;
        refreshJoins();
        paintProgressBar();
      });
      EB.bootDone = true;
      remapAnns();
      bumpIdle();
      maybePreload();
      maybeAutoGuide();
    };
    if (boot) {
      onBoot(boot);
    } else {
      EB.docEl.innerHTML = '<div class="sec skel" style="min-height:340px"></div>';
      req(q).then(onBoot).catch(function (e) {
        if (!EB.open) return;
        EB.docEl.innerHTML = '';
        tip(L.t('打不开这本书'), errText(e) + '<br><span style="font-size:11px;opacity:.7">' + esc(EB.bookId) + '</span>');
      });
    }
  }

  function restoreTo(prog) {
    EB.restore = prog;
    var tries = 0;
    var run = function () {
      if (!EB.open || EB.restore < 0) return;
      var sec = EB.secs.get(EB.ch);
      if (!sec) return;
      scrollToSec(sec, EB.restore);
      tries++;
      if (tries < 4) setTimeout(run, 260 + tries * 200);
      else EB.restore = -1;
    };
    setTimeout(run, 60);
  }

  function close(settle) {
    if (!EB.open) return;
    var id = EB.bookId;
    clearTimeout(EB.progTimer);
    clearTimeout(EB.restoreT);
    EB.restoring = false;
    if (settle !== false) {
      if (PRE.imm) {
        try { sessionStorage.setItem(immKey(), JSON.stringify({ ch: EB.ch, p: chapterProgress() })); } catch (e) { }
        if (EB.session) toast(L.t('隐身阅读 · 本次不留记录'));
      } else if (EB.session) {
        EB.session.end = Date.now();
        if (typeof pushSession === 'function') pushSession(EB.session);
        sendProgress();
        req('api/lantai/v1/reading/stop', { method: 'POST', body: { bookId: id, deviceId: 'webui' } }).catch(function () { });
        toast(L.t('已读 ') + dur(EB.session.dur) + L.t(' · 停在第 ') + EB.ch + L.t(' 章'));
      }
    }
    EB.session = null;
    if (EB.immOnce) { PRE.imm = false; EB.immOnce = false; }
    EB.open = false;
    EB.nav = null;
    EB.pre = null;
    clearInterval(EB.hbTimer);
    ttsStop();
    wakeOff();
    closeGuide(false);
    var r = $('eb');
    if (r) r.classList.remove('on', 'idle');
    $('ebLb').classList.remove('on');
    $('ebAsk').classList.remove('on');
    $('ebSel').classList.remove('on');
    $('ebTip').classList.remove('on');
    closePanels();
    if (EB.shadow && EB.docEl) EB.docEl.innerHTML = '';
    EB.secs.clear();
    EB.park.clear();
    EB.pending = {};
    EB.warmF = false; EB.warmB = false;
    if (location.hash.indexOf('#/read/') === 0) {
      history.replaceState(null, '', '#/book/' + id);
      if (typeof render === 'function') render();
    }
  }

  function leaveApp() {
    if (!window.lantaiBridge || !window.lantaiBridge.exit) return;
    try { window.lantaiBridge.exit(); } catch (e) { }
  }

  function back() {
    if (!EB.open) return false;
    if (GD.open) { closeGuide(true); return true; }
    var lb = $('ebLb');
    if (lb && lb.classList.contains('on')) { lb.classList.remove('on'); return true; }
    var ask = $('ebAsk');
    if (ask && ask.classList.contains('on')) { ask.classList.remove('on'); return true; }
    if (EB.panel) { closePanels(); return true; }
    var cs = currentSelection();
    if (EB.selRange || (cs && cs.rangeCount && !cs.isCollapsed)) { clearSel(); return true; }
    var r = $('eb');
    if (r && !r.classList.contains('idle')) {
      clearTimeout(EB.idle);
      r.classList.add('idle');
      return true;
    }
    return false;
  }

  window.EbookReader = {
    open: open,
    close: close,
    back: back,
    goto: gotoChapter,
    ttsSync: ttsSync,
    ttsStop: ttsStop,
    ttsStart: function (from) { return ttsStart(null, from || 0); },
    ttsUi: function () {
      return { on: EB.ttsOn, idx: EB.tts ? EB.tts.idx : -1, total: EB.tts ? EB.tts.total : 0, paused: !!EB.paused };
    },
    isOpen: function () { return EB.open; },
    flush: function () {
      clearTimeout(EB.progTimer);
      if (!EB.open || EB.restoring) return;
      sendProgress();
    },
    current: function () { return { open: EB.open, chapter: EB.ch, total: EB.total, panel: EB.panel, theme: PRE.theme, bootDone: !!EB.bootDone }; },
    prefs: PRE
  };
})();
