import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { readingTracker } from '../net/ReadingSession';
import { WindowFx } from '../common/WindowFx';
import { AppCtx } from '../common/AppCtx';

const TAG: string = 'LantaiReader';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppCtx.set(this.context);
    hilog.info(0x0000, TAG, 'onCreate');
  }

  onForeground(): void {
    readingTracker.setForeground(true);
  }

  onBackground(): void {
    readingTracker.setForeground(false);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, TAG, 'loadContent failed %{public}s', JSON.stringify(err));
        return;
      }
      try {
        WindowFx.applyBars(windowStage.getMainWindowSync());
      } catch (error) {
        hilog.warn(0x0000, TAG, 'apply bars failed');
      }
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, TAG, 'onWindowStageDestroy');
  }
}
