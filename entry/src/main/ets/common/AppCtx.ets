import { common } from '@kit.AbilityKit';

export class AppCtx {
  private static ctx: common.UIAbilityContext | null = null;

  static set(ctx: common.UIAbilityContext): void {
    AppCtx.ctx = ctx;
  }

  static get(): common.UIAbilityContext | null {
    return AppCtx.ctx;
  }
}
