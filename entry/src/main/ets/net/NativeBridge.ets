import { LantaiSession } from './LantaiSession';
import { progressOutbox } from './ProgressOutbox';
import { LocalStore } from './LocalStore';
import { ttsService } from './TtsService';

export type ReportSink = (json: string) => void;
export type PostSink = (method: string, path: string, ok: boolean, status: number) => void;
export type ExitSink = () => void;

export class NativeBridge {
  private session: LantaiSession;
  private reportSink: ReportSink;
  private postSink: PostSink;
  private exitSink: ExitSink;
  private hidden: boolean;

  constructor(session: LantaiSession, reportSink: ReportSink, postSink: PostSink, exitSink: ExitSink,
    hidden: boolean) {
    this.session = session;
    this.reportSink = reportSink;
    this.postSink = postSink;
    this.exitSink = exitSink;
    this.hidden = hidden;
  }

  report(json: string): void {
    this.reportSink(json);
  }

  exit(): void {
    this.exitSink();
  }

  ttsStart(json: string): void {
    ttsService.start(json);
  }

  ttsSeek(idx: number): void {
    ttsService.seek(idx);
  }

  ttsPause(): void {
    ttsService.pause();
  }

  ttsResume(): void {
    ttsService.resume();
  }

  ttsStop(): void {
    ttsService.stop();
  }

  ttsOnce(text: string, params: string): void {
    ttsService.speakOnce(text, params);
  }

  ttsVoices(): string {
    return ttsService.voices();
  }

  ttsLoadVoices(): void {
    ttsService.refreshVoices();
  }

  ttsToneNow(): number {
    return ttsService.toneNow();
  }

  ttsTone(tone: number): void {
    ttsService.setTone(tone);
  }

  post(method: string, path: string, body: string): void {
    if (this.hidden) {
      this.postSink(method, path, true, 204);
      return;
    }
    if (NativeBridge.isLocal(path, body)) {
      NativeBridge.keepLocal(path, body);
      this.postSink(method, path, true, 204);
      return;
    }
    this.session.sendJson(method, path, body)
      .then((status: number) => {
        if (status >= 500) {
          progressOutbox.enqueue(method, path, body);
        }
        this.postSink(method, path, status >= 200 && status < 300, status);
      })
      .catch((error: Error) => {
        progressOutbox.enqueue(method, path, body);
        this.postSink(method, path, false, 0);
      });
  }

  private static isLocal(path: string, body: string): boolean {
    if (path.indexOf('local:') >= 0) {
      return true;
    }
    return body.indexOf('"local:') >= 0;
  }

  private static keepLocal(path: string, body: string): void {
    if (path.indexOf('/progression') < 0) {
      return;
    }
    const id: string = NativeBridge.bookIdOf(path, body);
    if (id.length === 0) {
      return;
    }
    const chapterMatch: RegExpExecArray | null = /"position"\s*:\s*([0-9]+)/.exec(body);
    const progressMatch: RegExpExecArray | null = /"progression"\s*:\s*([0-9.]+)/.exec(body);
    const chapter: number = chapterMatch !== null ? parseInt(chapterMatch[1], 10) : 0;
    const progress: number = progressMatch !== null ? parseFloat(progressMatch[1]) : 0;
    LocalStore.saveProgress(id, chapter, progress).catch(() => {
    });
  }

  private static bookIdOf(path: string, body: string): string {
    const marker: string = '/books/';
    const at: number = path.indexOf(marker);
    if (at >= 0) {
      const rest: string = path.substring(at + marker.length);
      const slash: number = rest.indexOf('/');
      const id: string = slash > 0 ? rest.substring(0, slash) : rest;
      if (id.startsWith('local:')) {
        return decodeURIComponent(id);
      }
    }
    const match: RegExpExecArray | null = /"bookId"\s*:\s*"(local:[^"]+)"/.exec(body);
    return match !== null ? match[1] : '';
  }
}
