import { window } from '@kit.ArkUI';

import { C } from './Theme';

export class WindowFx {
  static applyBars(win: window.Window): void {
    const content: string = C.mode === 'light' ? '#20201c' : '#e9e5db';
    try {
      win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: content,
        navigationBarColor: '#00000000',
        navigationBarContentColor: content
      }).catch(() => {
      });
    } catch (error) {
    }
  }

  static async enterImmersive(win: window.Window): Promise<void> {
    try {
      await win.setWindowLayoutFullScreen(true);
    } catch (error) {
    }
    try {
      await win.setWindowSystemBarEnable([]);
    } catch (error) {
    }
  }

  static exitImmersive(win: window.Window): void {
    try {
      win.setWindowSystemBarEnable(['status', 'navigation']).catch(() => {
      });
      win.setWindowLayoutFullScreen(false).catch(() => {
      });
      WindowFx.applyBars(win);
    } catch (error) {
    }
  }

  static safeTop(win: window.Window): number {
    try {
      return px2vp(win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM).topRect.height);
    } catch (error) {
      return 0;
    }
  }

  static safeBottom(win: window.Window): number {
    let h: number = 0;
    try {
      h = px2vp(win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR).bottomRect.height);
    } catch (error) {
      h = 0;
    }
    if (!(h > 0)) {
      try {
        h = px2vp(win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM).bottomRect.height);
      } catch (error) {
        h = 0;
      }
    }
    return h > 0 ? h : 16;
  }
}
