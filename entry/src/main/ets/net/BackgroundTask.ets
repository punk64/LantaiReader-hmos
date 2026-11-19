import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { common, wantAgent } from '@kit.AbilityKit';

export class BackgroundTask {
  private dataHolds: number = 0;
  private audioHolds: number = 0;
  private cur: number = 0;
  private busy: boolean = false;
  private dirty: boolean = false;

  private wanted(): number {
    if (this.audioHolds > 0) {
      return 2;
    }
    if (this.dataHolds > 0) {
      return 1;
    }
    return 0;
  }

  private async agent(ctx: common.UIAbilityContext): Promise<object> {
    const info: wantAgent.WantAgentInfo = {
      wants: [{
        bundleName: ctx.abilityInfo.bundleName,
        abilityName: ctx.abilityInfo.name
      }],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    return await wantAgent.getWantAgent(info);
  }

  private async apply(ctx: common.UIAbilityContext): Promise<void> {
    if (this.busy) {
      this.dirty = true;
      return;
    }
    this.busy = true;
    do {
      this.dirty = false;
      const next: number = this.wanted();
      if (next !== this.cur) {
        try {
          if (this.cur !== 0) {
            await backgroundTaskManager.stopBackgroundRunning(ctx);
            this.cur = 0;
          }
          if (next !== 0) {
            const mode: backgroundTaskManager.BackgroundMode = next === 2 ?
              backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK :
              backgroundTaskManager.BackgroundMode.DATA_TRANSFER;
            await backgroundTaskManager.startBackgroundRunning(ctx, mode, await this.agent(ctx));
            this.cur = next;
          }
        } catch (error) {
          this.cur = 0;
        }
      }
    } while (this.dirty);
    this.busy = false;
  }

  async acquire(ctx: common.UIAbilityContext): Promise<void> {
    this.dataHolds += 1;
    await this.apply(ctx);
  }

  async release(ctx: common.UIAbilityContext): Promise<void> {
    this.dataHolds = Math.max(0, this.dataHolds - 1);
    await this.apply(ctx);
  }

  async acquireAudio(ctx: common.UIAbilityContext): Promise<void> {
    this.audioHolds += 1;
    await this.apply(ctx);
  }

  async releaseAudio(ctx: common.UIAbilityContext): Promise<void> {
    this.audioHolds = Math.max(0, this.audioHolds - 1);
    await this.apply(ctx);
  }

  active(): boolean {
    return this.cur !== 0;
  }
}

export const backgroundTask: BackgroundTask = new BackgroundTask();
