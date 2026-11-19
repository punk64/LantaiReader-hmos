(function () {
  'use strict';

  var DICT = {
    '纸白': '纸白', '牛皮纸': '牛皮纸', '护眼': '护眼', '墨黑': '墨黑', '夜间': '夜间',
    '宋体': '宋体', '黑体': '黑体', '楷体': '楷体', '原书': '原书',
    '高亮': '高亮', '下划线': '下划线', '书签': '书签', '笔记': '笔记'
  };

  window.LantaiI18n = {
    t: function (key) { return DICT[key] || key; },
    lang: function () { return 'zh-Hans'; },
    langs: function () { return [{ code: 'zh-Hans', name: '简体中文' }]; },
    name: function (code) { return code; },
    set: function () { }
  };

  var L = window.LantaiI18n;
  var stats = { get: 0, post: 0, fail: 0 };
  var timings = {};

  function httpGet(path, opts) {
    var init = { credentials: 'same-origin', headers: Object.assign({}, (opts && opts.headers) || {}) };
    if (opts && opts.signal) {
      init.signal = opts.signal;
    }
    return fetch(path, init).then(function (res) {
      if (!res.ok) {
        return res.text().catch(function () { return ''; }).then(function (text) {
          var err = new Error(text || ('HTTP ' + res.status));
          err.status = res.status;
          throw err;
        });
      }
      var type = res.headers.get('content-type') || '';
      if (type.indexOf('application/json') >= 0) {
        return res.json();
      }
      return res.text();
    });
  }

  window.LantaiRuntime = {
    request: function (path, opts) {
      var method = String((opts && opts.method) || 'GET').toUpperCase();
      if (method === 'GET') {
        stats.get += 1;
        return httpGet(path, opts).catch(function (err) {
          stats.fail += 1;
          throw err;
        });
      }
      stats.post += 1;
      try {
        if (window.lantaiBridge && window.lantaiBridge.post) {
          window.lantaiBridge.post(method, path, JSON.stringify((opts && opts.body) || null));
        }
      } catch (bridgeError) {
      }
      return Promise.resolve({ ok: true });
    }
  };

  var BOOK = null;

  window.book = function (id) {
    return BOOK && BOOK.id === id ? BOOK : null;
  };
  window.series = function () {
    return { t: (BOOK && BOOK.seriesTitle) || '' };
  };
  window.clamp = function (v, a, b) {
    return Math.max(a, Math.min(b, v));
  };
  window.esc = function (s) {
    return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c];
    });
  };
  window.num = function (n) {
    return Number(n || 0).toLocaleString('zh-CN');
  };
  window.ago = function (t) {
    var d = Date.now() - t;
    if (d < 0) return window.LantaiI18n.t('刚刚');
    if (d < 36e5) return Math.max(1, Math.round(d / 6e4)) + window.LantaiI18n.t(' 分钟前');
    if (d < 864e5) return Math.round(d / 36e5) + window.LantaiI18n.t(' 小时前');
    return Math.round(d / 864e5) + window.LantaiI18n.t(' 天前');
  };
  window.dur = function (ms) {
    var s = Math.floor(ms / 1000), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60);
    if (h) return h + window.LantaiI18n.t(' 时 ') + m + window.LantaiI18n.t(' 分');
    if (m) return m + window.LantaiI18n.t(' 分 ') + (s % 60) + window.LantaiI18n.t(' 秒');
    return s + window.LantaiI18n.t(' 秒');
  };
  window.hexA = function (hex, alpha) {
    var h = String(hex || '').replace('#', '');
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    var n = parseInt(h, 16);
    if (isNaN(n)) return 'rgba(201,162,75,' + alpha + ')';
    return 'rgba(' + ((n >> 16) & 255) + ',' + ((n >> 8) & 255) + ',' + (n & 255) + ',' + alpha + ')';
  };

  function secRoot() {
    var view = document.getElementById('ebView');
    return view && view.shadowRoot ? view.shadowRoot.getElementById('ebDoc') : null;
  }

  function hasChapter(n) {
    var root = secRoot();
    if (!root) {
      return false;
    }
    var node = root.querySelector('[data-ch="' + n + '"]');
    return !!node && node.childElementCount > 0;
  }

  function probeLocalStorage() {
    try {
      localStorage.setItem('lantai.probe', '1');
      var value = localStorage.getItem('lantai.probe');
      localStorage.removeItem('lantai.probe');
      return value === '1';
    } catch (error) {
      return false;
    }
  }

  function report(extra) {
    var payload = {
      href: location.href,
      origin: location.origin,
      storage: probeLocalStorage(),
      wakeLock: !!(navigator.wakeLock && navigator.wakeLock.request),
      cssHighlights: !!(window.CSS && CSS.highlights),
      shadow: !!(window.ShadowRoot),
      stats: stats,
      at: Date.now()
    };
    Object.assign(payload, extra || {});
    var text = JSON.stringify(payload);
    try {
      if (window.lantaiBridge && window.lantaiBridge.report) {
        window.lantaiBridge.report(text);
      }
    } catch (bridgeError) {
    }
  }

  function fail(title, detail) {
    var host = document.getElementById('lantaiFail');
    if (!host) {
      host = document.createElement('div');
      host.id = 'lantaiFail';
      document.body.appendChild(host);
    }
    var dark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
    host.setAttribute('style', 'position:fixed;inset:0;z-index:99;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;padding:36px;box-sizing:border-box;text-align:center;font-family:-apple-system,"HarmonyOS Sans SC",sans-serif;background:' + (dark ? '#141414' : '#fbf9f3') + ';color:' + (dark ? '#e8e6e1' : '#1f1e1a') + ';');
    host.innerHTML =
      '<div style="font-size:15px;font-weight:600">' + esc(title) + '</div>' +
      '<div style="font-size:12px;line-height:1.7;opacity:.62;max-width:340px;word-break:break-all">' + esc(detail || '') + '</div>' +
      '<button type="button" id="lantaiFailRetry" style="margin-top:10px;padding:9px 26px;border-radius:99px;border:1px solid rgba(128,128,128,.4);background:transparent;color:inherit;font-size:13px">' + esc(L.t('重试')) + '</button>';
    var retry = document.getElementById('lantaiFailRetry');
    if (retry) {
      retry.addEventListener('click', function () { location.reload(); });
    }
  }

  function boot() {
    var params = new URLSearchParams(location.search);
    var bookId = params.get('book');
    if (!bookId) {
      report({ fatal: 'no-book-param' });
      fail(L.t('没有可打开的书'), '');
      return;
    }
    var chapter = params.get('chapter') ? parseInt(params.get('chapter'), 10) : 0;
    if (!(chapter > 0)) chapter = 0;
    var began = performance.now();
    httpGet('api/lantai/v1/read/' + bookId + '/bootstrap?images=inline&w=0&window=3')
      .then(function (dto) {
        timings.bootstrapMs = Math.round(performance.now() - began);
        BOOK = {
          id: bookId,
          name: (dto.book && dto.book.title) || '',
          seriesTitle: (dto.book && dto.book.seriesTitle) || '',
          chs: dto.total || 0,
          pages: 0,
          profile: (dto.book && dto.book.profile) || 'EPUB',
          s: (dto.book && dto.book.seriesTitle) || '',
          status: 'READY'
        };
        var opened = performance.now();
        if (!window.EbookReader) {
          report({ fatal: 'reader-missing' });
          fail(L.t('打不开这本书'), 'reader-missing');
          return;
        }
        window.EbookReader.open(bookId, { boot: dto, chapter: chapter });
        var deadline = performance.now() + 10000;
        var tick = function () {
          var current = window.EbookReader.current();
          if (current.bootDone) {
            report({
              openMs: Math.round(performance.now() - opened),
              chapter: current.chapter,
              total: current.total,
              rendered: (function () {
                var root = secRoot();
                return root ? root.childElementCount : 0;
              })()
            });
            return;
          }
          if (performance.now() > deadline) {
            report({ fatal: 'open-timeout', on: true, bootstrapMs: timings.bootstrapMs });
            fail(L.t('打不开这本书'), L.t('内容渲染超时'));
            return;
          }
          requestAnimationFrame(tick);
        };
        requestAnimationFrame(tick);
      })
      .catch(function (error) {
        report({ fatal: 'bootstrap-failed', message: String((error && error.message) || error) });
        fail(L.t('连不上兰台'), String((error && error.message) || error || ''));
      });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
