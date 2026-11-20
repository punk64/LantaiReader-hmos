import { avSession } from '@kit.AVSessionKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { backgroundTask } from './BackgroundTask';
import { t } from '../common/I18n';

const TAG: string = 'LantaiTts';

export interface TtsHooks {
  play: () => void;
  pause: () => void;
  stop: () => void;
  next: () => void;
  prev: () => void;
}

export class TtsSession {
  private ses: avSession.AVSession | null = null;
  private hooks: TtsHooks | null = null;
  private title: string = '';
  private held: boolean = false;

  setHooks(hooks: TtsHooks): void {
    this.hooks = hooks;
  }

  private bind(s: avSession.AVSession): void {
    s.on('play', () => {
      const h: TtsHooks | null = this.hooks;
      if (h !== null) {
        h.play();
      }
    });
    s.on('pause', () => {
      const h: TtsHooks | null = this.hooks;
      if (h !== null) {
        h.pause();
      }
    });
    s.on('stop', () => {
      const h: TtsHooks | null = this.hooks;
      if (h !== null) {
        h.stop();
      }
    });
    s.on('playNext', () => {
      const h: TtsHooks | null = this.hooks;
      if (h !== null) {
        h.next();
      }
    });
    s.on('playPrevious', () => {
      const h: TtsHooks | null = this.hooks;
      if (h !== null) {
        h.prev();
      }
    });
  }

  async begin(ctx: common.UIAbilityContext, title: string, sub: string): Promise<void> {
    if (title.length > 0) {
      this.title = title;
    }
    try {
      if (this.ses === null) {
        const s: avSession.AVSession = await avSession.createAVSession(ctx, 'LantaiTts', 'audio');
        this.bind(s);
        this.ses = s;
      }
      const meta: avSession.AVMetadata = {
        assetId: 'lantai-tts',
        title: this.title.length > 0 ? this.title : t('兰台阅读'),
        artist: sub
      };
      await this.ses.setAVMetadata(meta);
      await this.ses.activate();
    } catch (error) {
      hilog.warn(0x0000, TAG, 'av session failed %{public}s', (error as Error).message);
    }
    if (!this.held) {
      this.held = true;
      await backgroundTask.acquireAudio(ctx);
    }
  }

  async mark(playing: boolean, idx: number, total: number): Promise<void> {
    if (this.ses === null) {
      return;
    }
    try {
      const pos: avSession.PlaybackPosition = {
        elapsedTime: Math.max(0, idx) * 1000,
        updateTime: Date.now()
      };
      await this.ses.setAVPlaybackState({
        state: playing ? avSession.PlaybackState.PLAYBACK_STATE_PLAY :
          avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
        speed: 1,
        position: pos
      });
    } catch (error) {
    }
  }

  async end(ctx: common.UIAbilityContext): Promise<void> {
    if (this.held) {
      this.held = false;
      await backgroundTask.releaseAudio(ctx);
    }
    if (this.ses === null) {
      return;
    }
    const s: avSession.AVSession = this.ses;
    this.ses = null;
    try {
      await s.setAVPlaybackState({ state: avSession.PlaybackState.PLAYBACK_STATE_STOP });
      await s.deactivate();
      await s.destroy();
    } catch (error) {
    }
  }
}

export const ttsSession: TtsSession = new TtsSession();
