import { textToSpeech } from '@kit.CoreSpeechKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { common, wantAgent } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'TtsProbe';

@Entry
@Component
struct TtsProbe {
  @State lines: string[] = [];
  @State engState: string = '未建引擎';
  @State busy: string = '';
  private eng: textToSpeech.TextToSpeechEngine | null = null;
  private t0: number = Date.now();
  private seq: number = 0;
  private dataCount: number = 0;

  private log(msg: string): void {
    const line: string = `+${Date.now() - this.t0} ${msg}`;
    hilog.info(0x0000, TAG, '%{public}s', msg);
    this.lines.unshift(line);
    if (this.lines.length > 400) {
      this.lines = this.lines.slice(0, 400);
    }
  }

  private listener(): textToSpeech.SpeakListener {
    return {
      onStart: (requestId: string): void => {
        this.log(`START ${requestId}`);
      },
      onComplete: (requestId: string, response: textToSpeech.CompleteResponse): void => {
        this.log(`DONE ${requestId} type=${response.type}`);
      },
      onStop: (requestId: string): void => {
        this.log(`STOP ${requestId}`);
      },
      onError: (requestId: string, errorCode: number, errorMessage: string): void => {
        this.log(`ERR ${requestId} ${errorCode} ${errorMessage}`);
      },
      onData: (requestId: string, audio: ArrayBuffer, response: textToSpeech.SynthesisResponse): void => {
        this.dataCount += 1;
        if (this.dataCount % 20 === 0) {
          this.log(`DATA ${requestId} seq=${response.sequence} n=${this.dataCount}`);
        }
      }
    };
  }

  private async listVoices(): Promise<void> {
    try {
      const q: textToSpeech.VoiceQuery = { requestId: 'vq1', online: 1 };
      const voices: textToSpeech.VoiceInfo[] = await textToSpeech.listVoices(q);
      this.log(`voices count=${voices.length}`);
      voices.forEach((v: textToSpeech.VoiceInfo) => {
        this.log(`V ${v.person} ${v.language} ${v.gender} ${v.status} ${v.description}`);
      });
    } catch (e) {
      this.log(`voices fail ${JSON.stringify(e)}`);
    }
  }

  private async mkEngine(bg: boolean): Promise<void> {
    try {
      if (this.eng !== null) {
        this.eng.shutdown();
        this.eng = null;
      }
      const extra: Record<string, Object> = {
        'style': 'interaction-broadcast',
        'locate': 'CN',
        'name': bg ? 'ProbeTtsA' : 'ProbeTtsB',
        'isBackStage': bg
      };
      const p: textToSpeech.CreateEngineParams = {
        language: 'zh-CN',
        person: 0,
        online: 1,
        extraParams: extra
      };
      this.eng = await textToSpeech.createEngine(p);
      this.eng.setListener(this.listener());
      this.engState = bg ? 'A 已建 后台' : 'B 已建 前台';
      this.log(`engine ok backStage=${bg}`);
    } catch (e) {
      this.engState = '建引擎失败';
      this.log(`engine fail ${JSON.stringify(e)}`);
    }
  }

  private async playSeq(n: number): Promise<void> {
    if (this.eng === null) {
      this.log('no engine');
      return;
    }
    this.t0 = Date.now();
    for (let i = 1; i <= n; i++) {
      const req: string = `q${this.seq}-${i}`;
      const sp: textToSpeech.SpeakParams = {
        requestId: req,
        extraParams: {
          'queueMode': 0,
          'speed': 1,
          'volume': 1,
          'pitch': 1,
          'playType': 1,
          'soundChannel': 3
        }
      };
      try {
        this.eng.speak(`第${i}句，队列顺序测试。`, sp);
      } catch (e) {
        this.log(`speak ${i} fail ${JSON.stringify(e)}`);
      }
    }
    this.seq += 1;
    this.log(`queued ${n} sentences`);
  }

  private onStop(): void {
    if (this.eng === null) {
      return;
    }
    this.log('call stop');
    this.eng.stop();
  }

  private checkBusy(): void {
    if (this.eng === null) {
      this.log('no engine');
      return;
    }
    const b: boolean = this.eng.isBusy();
    this.busy = b ? 'busy' : 'idle';
    this.log(`isBusy=${b}`);
  }

  private async longText(): Promise<void> {
    if (this.eng === null) {
      this.log('no engine');
      return;
    }
    let big: string = '';
    for (let i = 0; i < 10001; i++) {
      big += '测';
    }
    const sp: textToSpeech.SpeakParams = {
      requestId: `big${this.seq}`,
      extraParams: { 'queueMode': 0, 'playType': 1, 'soundChannel': 3 }
    };
    this.seq += 1;
    try {
      this.eng.speak(big, sp);
      this.log('long text accepted');
    } catch (e) {
      this.log(`long text fail ${JSON.stringify(e)}`);
    }
  }

  private async bgTaskOn(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const info: wantAgent.WantAgentInfo = {
        wants: [{ bundleName: ctx.abilityInfo.bundleName, abilityName: ctx.abilityInfo.name }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const agent = await wantAgent.getWantAgent(info);
      await backgroundTaskManager.startBackgroundRunning(ctx,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, agent);
      this.log('bg task ON');
    } catch (e) {
      this.log(`bg task fail ${JSON.stringify(e)}`);
    }
  }

  private async bgTaskOff(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      await backgroundTaskManager.stopBackgroundRunning(ctx);
      this.log('bg task OFF');
    } catch (e) {
      this.log(`bg off fail ${JSON.stringify(e)}`);
    }
  }

  @Builder
  btn(label: string, act: () => void) {
    Button(label)
      .fontSize(11)
      .height(30)
      .margin(3)
      .padding({ left: 8, right: 8 })
      .backgroundColor('#2F6BFF')
      .onClick(act)
  }

  build() {
    Column() {
      Row() {
        Text('TTS 探针')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text(this.engState)
          .fontSize(11)
          .fontColor('#666')
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8 })

      Flex({ wrap: FlexWrap.Wrap }) {
        this.btn('1 列音色', () => { this.listVoices(); })
        this.btn('2A 引擎后台', () => { this.mkEngine(true); })
        this.btn('2B 引擎前台', () => { this.mkEngine(false); })
        this.btn('3 连播6句', () => { this.playSeq(6); })
        this.btn('4 连播60句', () => { this.playSeq(60); })
        this.btn('5 长时任务开', () => { this.bgTaskOn(); })
        this.btn('5b 长时任务关', () => { this.bgTaskOff(); })
        this.btn('6 超长10001', () => { this.longText(); })
        this.btn('7 stop', () => { this.onStop(); })
        this.btn('8 isBusy', () => { this.checkBusy(); })
        this.btn('9 清屏', () => { this.lines = []; this.t0 = Date.now(); })
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 4 })

      Divider().margin({ top: 4, bottom: 4 })

      List() {
        ForEach(this.lines, (item: string, idx: number) => {
          ListItem() {
            Text(item)
              .fontSize(11)
              .fontColor('#222')
              .width('100%')
              .textAlign(TextAlign.Start)
          }
        }, (item: string, idx: number) => `${idx}_${item}`)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 12, right: 12 })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
