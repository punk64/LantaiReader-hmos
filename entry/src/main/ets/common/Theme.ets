export class C {
  static mode: string = 'dark';
  static bg: string = '#121313';
  static bg1: string = '#161818';
  static bg2: string = '#1b1e1e';
  static bg3: string = '#222727';
  static bg4: string = '#2b3130';
  static line: string = '#2a2f2e';
  static line2: string = '#39403e';
  static line3: string = '#4a5350';
  static tx: string = '#e9e5db';
  static tx2: string = '#b3b6ae';
  static tx3: string = '#7f857e';
  static tx4: string = '#5a615a';
  static acc: string = '#C9A24B';
  static acc2: string = '#E3C377';
  static accBg: string = '#2a2517';
  static accLine: string = '#5c4d29';
  static bad: string = '#c8563c';
  static ok: string = '#79a06a';
  static warn: string = '#c99a3f';
  static info: string = '#6d92a8';
  static paper: string = '#f3efe4';
  static paperTx: string = '#2b2923';
  static glass: string = '#d1161818';
  static glassDeep: string = '#ed0e100f';
  static navSolid: string = '#ff1a1c1c';
  static navGlass: string = '#801C201F';
  static navEdge: string = '#3D4543';
  static hair: string = '#26ffffff';
  static shadow: string = '#000000';
  static onAcc: string = '#17140c';

  static apply(mode: string): void {
    if (mode === 'light') {
      C.mode = 'light';
      C.bg = '#f2eee3';
      C.bg1 = '#f7f4ec';
      C.bg2 = '#fffdf6';
      C.bg3 = '#efe9da';
      C.bg4 = '#e5ddc9';
      C.line = '#dbd3be';
      C.line2 = '#c9c0a6';
      C.line3 = '#b4ab90';
      C.tx = '#20201c';
      C.tx2 = '#545348';
      C.tx3 = '#87857a';
      C.tx4 = '#a8a494';
      C.acc = '#8a651f';
      C.acc2 = '#a87f2c';
      C.accBg = '#e9e0c9';
      C.accLine = '#c6b48a';
      C.bad = '#a63a24';
      C.ok = '#4d7a3f';
      C.warn = '#94701c';
      C.info = '#3f6a80';
      C.paper = '#fffdf6';
      C.paperTx = '#2b2923';
      C.glass = '#dbfffdf6';
      C.glassDeep = '#f2fffdf6';
      C.navSolid = '#fff7f4ec';
      C.navGlass = '#80FCFAF3';
      C.navEdge = '#C9C0A6';
      C.hair = '#1f000000';
      C.shadow = '#2a2420';
      C.onAcc = '#fffdf6';
    } else {
      C.mode = 'dark';
      C.bg = '#121313';
      C.bg1 = '#161818';
      C.bg2 = '#1b1e1e';
      C.bg3 = '#222727';
      C.bg4 = '#2b3130';
      C.line = '#2a2f2e';
      C.line2 = '#39403e';
      C.line3 = '#4a5350';
      C.tx = '#e9e5db';
      C.tx2 = '#b3b6ae';
      C.tx3 = '#7f857e';
      C.tx4 = '#5a615a';
      C.acc = '#C9A24B';
      C.acc2 = '#E3C377';
      C.accBg = '#2a2517';
      C.accLine = '#5c4d29';
      C.bad = '#c8563c';
      C.ok = '#79a06a';
      C.warn = '#c99a3f';
      C.info = '#6d92a8';
      C.paper = '#f3efe4';
      C.paperTx = '#2b2923';
      C.glass = '#d1161818';
      C.glassDeep = '#ed0e100f';
      C.navSolid = '#ff1a1c1c';
      C.navGlass = '#801C201F';
      C.navEdge = '#3D4543';
      C.hair = '#26ffffff';
      C.shadow = '#000000';
      C.onAcc = '#17140c';
    }
    AppStorage.setOrCreate('uiTick', Date.now());
  }
}

export class FT {
  static readonly disp: string = 'serif';
  static readonly ui: string = 'HarmonyOS Sans';
  static readonly mono: string = 'monospace';
}

export class R {
  static readonly s: number = 8;
  static readonly m: number = 12;
  static readonly l: number = 16;
  static readonly xl: number = 22;
}

export class S {
  static readonly page: number = 16;
  static readonly gap: number = 12;
}
