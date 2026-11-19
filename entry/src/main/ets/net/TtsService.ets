import { textToSpeech } from '@kit.CoreSpeechKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { AppCtx } from '../common/AppCtx';
import { PrefKeys, Prefs } from '../model/Prefs';
import { ttsSession } from './TtsSession';

const TAG: string = 'LantaiTts';

export type TtsNotify = (json: string) => void;

interface TtsMod {
  speed: number;
  pitch: number;
  volume: number;
  gap: number;
}

export class TtsService {
  private eng: textToSpeech.TextToSpeechEngine | null = null;
  private notify: TtsNotify | null = null;
  private items: string[] = [];
  private mods: TtsMod[] = [];
  private cur: number = -1;
  private seq: number = 0;
  private tone: number = 13;
  private speed: number = 1;
  private pitch: number = 1;
  private volume: number = 1;
  private gap: number = 200;
  private speakTs: number = 0;
  private speakChars: number = 0;
  private timer: number = -1;
  private quiet: number = -1;
  private paused: boolean = false;
  private stopping: boolean = false;
  private running: boolean = false;
  private voicesCache: string = '[]';
  private voiceInfos: textToSpeech.VoiceInfo[] = [];
  private voiceSeq: number = 0;
  private toneLoaded: boolean = false;
  private title: string = '';
  private sub: string = '';

  constructor() {
    ttsSession.setHooks({
      play: () => {
        this.resume();
      },
      pause: () => {
        this.pause();
      },
      stop: () => {
        setTimeout(() => {
          this.stop();
        }, 0);
      },
      next: () => {
        this.seek(this.cur + 1);
      },
      prev: () => {
        this.seek(this.cur - 1);
      }
    });
  }

  setNotify(fn: TtsNotify): void {
    this.notify = fn;
  }

  isPlaying(): boolean {
    return this.items.length > 0 && (this.running || this.paused);
  }

  pos(): number {
    return this.cur;
  }

  private send(payload: string): void {
    if (this.notify !== null) {
      this.notify(payload);
    }
  }

  private publish(): void {
    AppStorage.setOrCreate('ttsBarIdx', this.cur < 0 ? 0 : this.cur);
    AppStorage.setOrCreate('ttsBarTotal', this.items.length);
    AppStorage.setOrCreate('ttsBarPlay', this.running && !this.paused);
    AppStorage.setOrCreate('ttsBarOn', this.items.length > 0);
    AppStorage.setOrCreate('ttsBarKey', Date.now());
  }

  private clearTimer(): void {
    if (this.timer >= 0) {
      clearTimeout(this.timer);
      this.timer = -1;
    }
  }

  private muteFor(ms: number): void {
    if (this.quiet >= 0) {
      clearTimeout(this.quiet);
    }
    this.stopping = true;
    this.quiet = setTimeout(() => {
      this.stopping = false;
      this.quiet = -1;
    }, ms);
  }

  private clampNum(v: number, lo: number, hi: number): number {
    return v < lo ? lo : (v > hi ? hi : v);
  }

  private numOf(obj: Record<string, Object>, key: string, fallback: number): number {
    const raw: Object = obj[key];
    if (raw === undefined || raw === null) {
      return fallback;
    }
    const n: number = Number(raw);
    return isNaN(n) ? fallback : n;
  }

  private defaultMod(): TtsMod {
    return {
      speed: this.speed,
      pitch: this.pitch,
      volume: this.volume,
      gap: this.gap
    };
  }

  private modAt(i: number): TtsMod {
    if (i >= 0 && i < this.mods.length) {
      return this.mods[i];
    }
    return this.defaultMod();
  }

  private parseMods(raw: Object, count: number): TtsMod[] {
    const out: TtsMod[] = [];
    if (!Array.isArray(raw)) {
      return out;
    }
    const list: Object[] = raw as Object[];
    const n: number = Math.min(count, list.length);
    for (let i = 0; i < n; i++) {
      const item: Object = list[i];
      if (item === null || item === undefined) {
        out.push(this.defaultMod());
        continue;
      }
      const rec: Record<string, Object> = item as Record<string, Object>;
      out.push({
        speed: this.clampNum(this.numOf(rec, 'speed', this.speed), 0.5, 2),
        pitch: this.clampNum(this.numOf(rec, 'pitch', this.pitch), 0.5, 2),
        volume: this.clampNum(this.numOf(rec, 'volume', this.volume), 0, 2),
        gap: this.clampNum(this.numOf(rec, 'gap', this.gap), 0, 1200)
      });
    }
    return out;
  }

  private idxOf(requestId: string): number {
    const at: number = requestId.lastIndexOf('-');
    if (at < 0) {
      return -1;
    }
    const n: number = parseInt(requestId.substring(at + 1), 10);
    return isNaN(n) ? -1 : n;
  }

  private async ensure(): Promise<boolean> {
    if (this.eng !== null) {
      return true;
    }
    this.restoreTone();
    try {
      const extra: Record<string, Object> = {
        'style': 'interaction-broadcast',
        'locate': 'CN',
        'name': 'LantaiTts',
        'isBackStage': true
      };
      const params: textToSpeech.CreateEngineParams = {
        language: 'zh-CN',
        person: this.tone,
        online: 1,
        extraParams: extra
      };
      const eng: textToSpeech.TextToSpeechEngine = await textToSpeech.createEngine(params);
      const self: TtsService = this;
      eng.setListener({
        onStart: (requestId: string): void => {
          self.handleStart(requestId);
        },
        onComplete: (requestId: string, response: textToSpeech.CompleteResponse): void => {
          self.handleComplete(requestId, response);
        },
        onStop: (requestId: string): void => {
        },
        onError: (requestId: string, code: number, message: string): void => {
          self.handleError(requestId, code, message);
        },
        onData: (requestId: string, audio: ArrayBuffer, response: textToSpeech.SynthesisResponse): void => {
        }
      });
      this.eng = eng;
      setTimeout(() => {
        this.pullVoices();
      }, 1500);
      return true;
    } catch (error) {
      hilog.error(0x0000, TAG, 'create engine failed %{public}s', (error as Error).message);
      this.send('{"type":"err","msg":"引擎创建失败"}');
      return false;
    }
  }

  private handleStart(requestId: string): void {
    if (this.stopping) {
      return;
    }
    const idx: number = this.idxOf(requestId);
    if (idx < 0 || idx !== this.cur) {
      return;
    }
    this.send(`{"type":"start","idx":${idx},"total":${this.items.length}}`);
    ttsSession.mark(true, idx, this.items.length);
    this.publish();
  }

  private handleComplete(requestId: string, response: textToSpeech.CompleteResponse): void {
    if (response.type !== 1 || this.stopping || this.paused) {
      return;
    }
    const idx: number = this.idxOf(requestId);
    if (idx !== this.cur) {
      return;
    }
    this.clearTimer();
    if (this.speakTs > 0) {
      const spent: number = Date.now() - this.speakTs;
      hilog.info(0x0000, TAG, 'seg %{public}d %{public}d字 %{public}dms %{public}dms/字',
        idx, this.speakChars, spent, Math.round(spent / Math.max(1, this.speakChars)));
    }
    const next: number = idx + 1;
    this.timer = setTimeout(() => {
      this.timer = -1;
      if (this.stopping || this.paused) {
        return;
      }
      this.speakAt(next);
    }, this.modAt(idx).gap);
  }

  private handleError(requestId: string, code: number, message: string): void {
    hilog.error(0x0000, TAG, 'speak error %{public}d %{public}s', code, message);
    this.clearTimer();
    this.running = false;
    this.send(`{"type":"err","msg":"${code}"}`);
    this.publish();
  }

  private speakAt(i: number): void {
    if (this.eng === null) {
      return;
    }
    if (i >= this.items.length) {
      this.running = false;
      ttsSession.mark(false, this.cur, this.items.length);
      this.send(`{"type":"end","idx":${this.items.length - 1}}`);
      return;
    }
    this.cur = i;
    this.speakTs = Date.now();
    this.speakChars = this.items[i].replace(/\[[^\]]*\]/g, '').length;
    this.publish();
    const mod: TtsMod = this.modAt(i);
    const params: textToSpeech.SpeakParams = {
      requestId: `${this.seq}-${i}`,
      extraParams: {
        'queueMode': 0,
        'speed': mod.speed,
        'volume': mod.volume,
        'pitch': mod.pitch,
        'playType': 1,
        'soundChannel': 3
      }
    };
    try {
      this.eng.speak(this.items[i], params);
    } catch (error) {
      this.running = false;
      this.send('{"type":"err","msg":"播报失败"}');
    }
  }

  async start(json: string): Promise<void> {
    let obj: Record<string, Object>;
    let list: string[];
    try {
      obj = JSON.parse(json) as Record<string, Object>;
      const raw: Object = obj['items'];
      list = raw as string[];
      if (list === null || list === undefined || list.length === 0) {
        this.send('{"type":"err","msg":"没有可朗读的文字"}');
        return;
      }
    } catch (error) {
      this.send('{"type":"err","msg":"朗读参数无效"}');
      return;
    }
    const speed: number = this.clampNum(this.numOf(obj, 'speed', this.speed), 0.5, 2);
    const pitch: number = this.clampNum(this.numOf(obj, 'pitch', this.pitch), 0.5, 2);
    const volume: number = this.clampNum(this.numOf(obj, 'volume', this.volume), 0, 2);
    const gap: number = this.clampNum(this.numOf(obj, 'gap', this.gap), 0, 1200);
    const rawMods: Object = obj['mods'];
    const mods: TtsMod[] = this.parseMods(rawMods, list.length);
    const rawRetune: Object = obj['retune'];
    const retune: boolean = rawRetune !== undefined && rawRetune !== null && String(rawRetune) === 'true';
    if (retune && this.running && this.items.length === list.length) {
      this.speed = speed;
      this.pitch = pitch;
      this.volume = volume;
      this.gap = gap;
      this.items = list;
      this.mods = mods;
      if (!this.paused) {
        this.seek(this.cur);
      }
      return;
    }
    this.halt();
    const ok: boolean = await this.ensure();
    if (!ok) {
      return;
    }
    try {
      const rawFrom: Object = obj['from'];
      const from: number = rawFrom === undefined || rawFrom === null ? 0 : rawFrom as number;
      const rawTitle: Object = obj['title'];
      if (rawTitle !== undefined && rawTitle !== null) {
        this.title = rawTitle as string;
      }
      const rawSub: Object = obj['sub'];
      if (rawSub !== undefined && rawSub !== null) {
        this.sub = rawSub as string;
      }
      const ctx: common.UIAbilityContext | null = AppCtx.get();
      if (ctx !== null) {
        await ttsSession.begin(ctx, this.title, this.sub);
      }
      this.items = list;
      this.mods = mods;
      this.speed = speed;
      this.pitch = pitch;
      this.volume = volume;
      this.gap = gap;
      this.paused = false;
      this.running = true;
      this.seq += 1;
      const startAt: number = Math.max(0, Math.min(from, list.length - 1));
      this.cur = startAt;
      this.speakAt(startAt);
      this.publish();
    } catch (error) {
      this.send('{"type":"err","msg":"朗读参数无效"}');
    }
  }

  seek(i: number): void {
    if (this.items.length === 0) {
      return;
    }
    this.clearTimer();
    this.muteFor(220);
    if (this.eng !== null) {
      this.eng.stop();
    }
    this.paused = false;
    this.running = true;
    this.seq += 1;
    const target: number = Math.max(0, Math.min(i, this.items.length - 1));
    this.cur = target;
    setTimeout(() => {
      if (this.stopping) {
        this.speakAt(target);
      }
    }, 140);
  }

  pause(): void {
    if (!this.running || this.paused) {
      return;
    }
    this.clearTimer();
    this.paused = true;
    this.muteFor(260);
    if (this.eng !== null) {
      this.eng.stop();
    }
    this.send(`{"type":"pause","idx":${this.cur}}`);
    ttsSession.mark(false, this.cur, this.items.length);
    this.publish();
  }

  resume(): void {
    if (!this.paused || this.items.length === 0) {
      return;
    }
    this.clearTimer();
    this.paused = false;
    this.running = true;
    this.stopping = false;
    this.seq += 1;
    this.speakAt(Math.max(0, this.cur));
    ttsSession.mark(true, this.cur, this.items.length);
    this.publish();
  }

  private halt(): void {
    this.clearTimer();
    this.running = false;
    this.paused = false;
    this.items = [];
    this.mods = [];
    this.cur = -1;
  }

  stop(): void {
    this.halt();
    this.muteFor(260);
    if (this.eng !== null) {
      this.eng.stop();
    }
    this.send('{"type":"stop"}');
    this.publish();
    const ctx: common.UIAbilityContext | null = AppCtx.get();
    if (ctx !== null) {
      ttsSession.end(ctx);
    }
  }

  async speakOnce(text: string, json: string): Promise<void> {
    const ok: boolean = await this.ensure();
    if (!ok || this.eng === null) {
      return;
    }
    let speed: number = this.speed;
    let pitch: number = this.pitch;
    let volume: number = this.volume;
    try {
      const obj: Record<string, Object> = JSON.parse(json) as Record<string, Object>;
      speed = this.clampNum(this.numOf(obj, 'speed', speed), 0.5, 2);
      pitch = this.clampNum(this.numOf(obj, 'pitch', pitch), 0.5, 2);
      volume = this.clampNum(this.numOf(obj, 'volume', volume), 0, 2);
    } catch (error) {
    }
    const params: textToSpeech.SpeakParams = {
      requestId: `once-${Date.now()}`,
      extraParams: {
        'queueMode': 1,
        'speed': speed,
        'volume': volume,
        'pitch': pitch,
        'playType': 1,
        'soundChannel': 3
      }
    };
    try {
      this.eng.speak(text, params);
    } catch (error) {
      this.send('{"type":"err","msg":"播报失败"}');
    }
  }

  private restoreTone(): void {
    if (this.toneLoaded) {
      return;
    }
    this.toneLoaded = true;
    const raw: string = Prefs.read(PrefKeys.ttsTone);
    const value: number = parseInt(raw, 10);
    if (!isNaN(value) && value > 0) {
      this.tone = value;
    }
  }

  private static isZh(v: textToSpeech.VoiceInfo): boolean {
    try {
      const lang: string = v.language === undefined ? '' : v.language.toLowerCase();
      if (lang.indexOf('zh') === 0 || lang.indexOf('cmn') === 0) {
        return true;
      }
      const name: string = v.description === undefined ? '' : v.description;
      return name.indexOf('中文') >= 0 || name.indexOf('Chinese') >= 0 || name.indexOf('普通话') >= 0;
    } catch (error) {
      return false;
    }
  }

  voiceList(): textToSpeech.VoiceInfo[] {
    return this.voiceInfos;
  }

  toneNow(): number {
    return this.tone;
  }

  refreshVoices(): Promise<void> {
    return this.pullVoices();
  }

  private async pullVoices(): Promise<void> {
    for (let attempt: number = 0; attempt < 3; attempt++) {
      const list: textToSpeech.VoiceInfo[] | null = await this.tryList();
      if (list !== null) {
        this.applyVoices(list);
        return;
      }
      if (attempt < 2) {
        await new Promise<void>((resolve: () => void) => {
          setTimeout(resolve, 600);
        });
      }
    }
    this.send('{"type":"voices","list":[]}');
  }

  private async tryList(): Promise<textToSpeech.VoiceInfo[] | null> {
    this.voiceSeq += 1;
    const tag: string = `voices-${this.voiceSeq}-${Date.now()}`;
    try {
      const query: textToSpeech.VoiceQuery = { requestId: tag, online: 1 };
      return await textToSpeech.listVoices(query);
    } catch (error) {
      hilog.warn(0x0000, TAG, 'list voices online failed %{public}s', (error as Error).message);
    }
    try {
      const local: textToSpeech.VoiceQuery = { requestId: `${tag}l`, online: 0 };
      return await textToSpeech.listVoices(local);
    } catch (localError) {
      hilog.warn(0x0000, TAG, 'list voices local failed %{public}s', (localError as Error).message);
    }
    return null;
  }

  private applyVoices(list: textToSpeech.VoiceInfo[]): void {
    const zh: textToSpeech.VoiceInfo[] = [];
    const rest: textToSpeech.VoiceInfo[] = [];
    list.forEach((v: textToSpeech.VoiceInfo) => {
      if (TtsService.isZh(v)) {
        zh.push(v);
      } else {
        rest.push(v);
      }
    });
    this.voiceInfos = zh.concat(rest);
    const parts: string[] = [];
    this.voiceInfos.forEach((v: textToSpeech.VoiceInfo) => {
      const ready: boolean = v.status === 'INSTALLED';
      parts.push(`{"tone":${v.person},"name":${JSON.stringify(v.description)},` +
        `"lang":${JSON.stringify(v.language)},"ready":${ready}}`);
    });
    this.voicesCache = `[${parts.join(',')}]`;
    hilog.info(0x0000, TAG, 'voices %{public}d', this.voiceInfos.length);
    this.send(`{"type":"voices","list":${this.voicesCache}}`);
  }

  voices(): string {
    return this.voicesCache;
  }

  async setTone(tone: number): Promise<void> {
    if (tone === this.tone) {
      return;
    }
    const at: number = this.cur;
    const resumeAt: boolean = this.running && !this.paused && this.items.length > 0;
    this.clearTimer();
    this.muteFor(400);
    this.dropEngine();
    this.tone = tone;
    this.toneLoaded = true;
    Prefs.write(PrefKeys.ttsTone, `${tone}`);
    this.send(`{"type":"tone","tone":${tone}}`);
    if (!resumeAt) {
      return;
    }
    const ok: boolean = await this.ensure();
    if (!ok || !this.running) {
      return;
    }
    this.stopping = false;
    this.seq += 1;
    this.cur = Math.max(0, Math.min(at, this.items.length - 1));
    this.speakAt(this.cur);
  }

  private dropEngine(): void {
    if (this.eng === null) {
      return;
    }
    try {
      this.eng.stop();
    } catch (error) {
    }
    try {
      this.eng.shutdown();
    } catch (error) {
    }
    this.eng = null;
  }
}

export const ttsService: TtsService = new TtsService();
