import { FT } from '../common/Theme';
import { t } from '../common/I18n';

interface GuideStep {
  anchor: string;
  zones: boolean;
  group: string;
  need: string;
  title: string;
  body: string;
}

const STEPS: GuideStep[] = [
  {
    anchor: 'comic_top_back',
    zones: false,
    group: t('顶栏'),
    need: '',
    title: t('返回'),
    body: t('左上角这个键退出阅读器，回到书架或详情页。刚读到的页码已经存下来了，下次打开直接续上。顶栏自动收起时，先点屏幕中间把它叫出来。')
  },
  {
    anchor: 'comic_top_title',
    zones: false,
    group: t('顶栏'),
    need: '',
    title: t('书名与页码'),
    body: t('上面一行是书名，太长会被省略号截断；下面一行是「第 x / y 页」。若末尾多了「· 隐身」，说明本次阅读不记进度、不上报时长。')
  },
  {
    anchor: 'comic_prog_pos',
    zones: false,
    group: t('进度'),
    need: '',
    title: t('页码计数'),
    body: t('当前页 / 总页数。拖动右边的进度条时，这个数字会临时变成目标页，松手才真正跳过去。')
  },
  {
    anchor: 'comic_prog_slider',
    zones: false,
    group: t('进度'),
    need: '',
    title: t('进度条'),
    body: t('拖动只预览页码、不跳页，松手才跳；直接点轨道任意位置也会立刻跳过去。几百页的长篇比一页页翻快得多。')
  },
  {
    anchor: 'comic_prog_pct',
    zones: false,
    group: t('进度'),
    need: '',
    title: t('全书百分比'),
    body: t('当前页在全书的位置。薄册子变化快，厚书里每 1% 都可能是几十页，用它判断还剩多少更直观。')
  },
  {
    anchor: 'comic_prog_prev',
    zones: false,
    group: t('进度'),
    need: '',
    title: t('上一页'),
    body: t('退一页，双页模式下退一整屏两页。也可以点屏幕左侧三分之一。')
  },
  {
    anchor: 'comic_prog_next',
    zones: false,
    group: t('进度'),
    need: '',
    title: t('下一页'),
    body: t('进一页，双页模式进一整屏两页。也可以点屏幕右侧三分之一。')
  },
  {
    anchor: 'comic_tool_thumbs',
    zones: false,
    group: t('工具'),
    need: 'thumbs',
    title: t('缩略图'),
    body: t('点一下在底栏上方拉开缩略图条，再点一下收起。缩略图条打开期间这个图标是金色。')
  },
  {
    anchor: 'comic_thumbs_strip',
    zones: false,
    group: t('工具'),
    need: 'thumbs',
    title: t('缩略图条'),
    body: t('横向滑动浏览全书每一页，当前页带金色边框，点任意一张直接跳过去。快速滑动时先转圈、停下再出图，避免一次解码上百张。')
  },
  {
    anchor: 'comic_tool_settings',
    zones: false,
    group: t('工具'),
    need: 'panel',
    title: t('画质与版式'),
    body: t('点开底栏上方的设置面板：版式三选、裁白边、校色、三档画质。改动即时生效，退出阅读器后也会记住。')
  },
  {
    anchor: 'comic_panel_mode',
    zones: false,
    group: t('版式'),
    need: 'panel',
    title: t('版式'),
    body: t('单页一次一张；双页一次两张，奇数页会自动归到偶数页起始；连续滚动上下滑到底自动接下一页。右侧数字是当前缩放倍数。')
  },
  {
    anchor: 'comic_panel_crop',
    zones: false,
    group: t('版式'),
    need: 'panel',
    title: t('裁白边'),
    body: t('自动切掉扫描页四周的白边，画面更大更饱满，适合白边很宽的老扫描件。本身满幅的彩页打开反而会切到内容。')
  },
  {
    anchor: 'comic_panel_enhance',
    zones: false,
    group: t('版式'),
    need: 'panel',
    title: t('校色'),
    body: t('提亮并压暗部，发灰的扫描件能看清细节。彩页打开可能偏色，看彩页时建议关掉。')
  },
  {
    anchor: 'comic_panel_quality',
    zones: false,
    group: t('版式'),
    need: 'panel',
    title: t('画质'),
    body: t('省流最省流量也最模糊，标准日常够用，高清最清楚但吃流量与内存。切换后当前页会重新加载一次。')
  },
  {
    anchor: 'comic_panel_guide',
    zones: false,
    group: t('版式'),
    need: 'panel',
    title: t('操作指引'),
    body: t('就是当前这个引导，随时可以重看一遍。它在面板最后一行，右侧标注「逐步演示」。')
  },
  {
    anchor: 'comic_tool_bookmark',
    zones: false,
    group: t('工具'),
    need: '',
    title: t('书签'),
    body: t('全书唯一的书签开关，金色表示当前页已标记，再点一次取消。放在底栏是为了单手够得到。')
  },
  {
    anchor: '',
    zones: true,
    group: t('交互'),
    need: '',
    title: t('触控有效区域'),
    body: t('屏幕横向分三块：左侧三分之一上一页，中间三分之一呼出或收起工具栏，右侧三分之一下一页。放大状态下三块都不响应。')
  },
  {
    anchor: '',
    zones: false,
    group: t('交互'),
    need: '',
    title: t('手势'),
    body: t('双指捏合最大放大到 4 倍，放大后单指拖动查看局部；长按以触点为中心放大 1.5 倍，松开还原。放大时翻页请用进度条或缩略图。')
  },
  {
    anchor: 'comic_guide_bottom',
    zones: false,
    group: t('交互'),
    need: '',
    title: t('自动收起'),
    body: t('两条栏在 3.2 秒无操作后自动收起，把整页画面让出来。点屏幕中间唤出，再点一次立刻收起。翻页不会把工具栏叫出来。')
  }
];

@Component
export struct ReaderGuide {
  @Link @Watch('redraw') visible: boolean;
  @Link @Watch('redraw') index: number;
  @Prop safeTop: number = 0;
  @Prop safeBottom: number = 0;
  onNeed: (need: string) => void = () => {
  };
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  @State private cw: number = 0;
  @State private ch: number = 0;
  @State private bh: number = 196;
  @State private hole: number[] = [0, 0, 0, 0];

  private redrawToken: number = 0;

  redraw(): void {
    const token: number = ++this.redrawToken;
    this.measure();
    this.paint();
    this.want();
    setTimeout(() => {
      if (token !== this.redrawToken) {
        return;
      }
      this.measure();
      this.paint();
    }, 0);
    setTimeout(() => {
      if (token !== this.redrawToken) {
        return;
      }
      this.measure();
      this.paint();
    }, 340);
  }

  private want(): void {
    if (!this.visible) {
      this.onNeed('');
      return;
    }
    this.onNeed(this.step().need);
  }

  private step(): GuideStep {
    const i: number = Math.min(Math.max(0, this.index), STEPS.length - 1);
    return STEPS[i];
  }

  private boxOfId(id: string): number[] {
    if (id.length === 0) {
      return [0, 0, 0, 0];
    }
    try {
      const utils = this.getUIContext().getComponentUtils();
      const root = utils.getRectangleById('comic_guide_root');
      const node = utils.getRectangleById(id);
      if (node.size.width <= 0 || node.size.height <= 0) {
        return [0, 0, 0, 0];
      }
      return [
        px2vp(node.windowOffset.x - root.windowOffset.x),
        px2vp(node.windowOffset.y - root.windowOffset.y),
        px2vp(node.size.width),
        px2vp(node.size.height)
      ];
    } catch (error) {
      return [0, 0, 0, 0];
    }
  }

  private measure(): void {
    const box: number[] = this.boxOfId(this.step().anchor);
    if (box[2] > 0 && box[3] > 0) {
      if (Math.abs(box[0] - this.hole[0]) > 0.5 || Math.abs(box[1] - this.hole[1]) > 0.5 ||
        Math.abs(box[2] - this.hole[2]) > 0.5 || Math.abs(box[3] - this.hole[3]) > 0.5) {
        this.hole = box;
      }
    } else if (this.hole[2] > 0) {
      this.hole = [0, 0, 0, 0];
    }
  }

  private padded(box: number[]): number[] {
    const p: number = 7;
    const x: number = Math.max(0, box[0] - p);
    const y: number = Math.max(0, box[1] - p);
    const w: number = Math.min(this.cw - x, box[2] + p * 2);
    const h: number = Math.min(this.ch - y, box[3] + p * 2);
    return [x, y, w, h];
  }

  private roundPath(c: CanvasRenderingContext2D, x: number, y: number, w: number, h: number,
    r: number): void {
    const radius: number = Math.min(r, w / 2, h / 2);
    c.beginPath();
    c.moveTo(x + radius, y);
    c.lineTo(x + w - radius, y);
    c.arcTo(x + w, y, x + w, y + radius, radius);
    c.lineTo(x + w, y + h - radius);
    c.arcTo(x + w, y + h, x + w - radius, y + h, radius);
    c.lineTo(x + radius, y + h);
    c.arcTo(x, y + h, x, y + h - radius, radius);
    c.lineTo(x, y + radius);
    c.arcTo(x, y, x + radius, y, radius);
    c.closePath();
  }

  private paint(): void {
    const c: CanvasRenderingContext2D = this.ctx;
    if (this.cw <= 0 || this.ch <= 0) {
      return;
    }
    c.clearRect(0, 0, this.cw, this.ch);
    c.fillStyle = 'rgba(3,4,5,0.80)';
    c.fillRect(0, 0, this.cw, this.ch);

    if (this.step().zones) {
      const top: number = this.safeTop + 52;
      const bottom: number = this.safeBottom + 120;
      const height: number = Math.max(0, this.ch - top - bottom);
      const w: number = this.cw;
      c.fillStyle = 'rgba(120,158,196,0.34)';
      c.fillRect(0, top, w * 0.30, height);
      c.fillStyle = 'rgba(227,195,119,0.26)';
      c.fillRect(w * 0.30, top, w * 0.40, height);
      c.fillStyle = 'rgba(196,142,104,0.34)';
      c.fillRect(w * 0.70, top, w * 0.30, height);
      c.strokeStyle = 'rgba(227,195,119,0.92)';
      c.lineWidth = 1.5;
      c.beginPath();
      c.moveTo(w * 0.30, top);
      c.lineTo(w * 0.30, top + height);
      c.moveTo(w * 0.70, top);
      c.lineTo(w * 0.70, top + height);
      c.moveTo(0, top);
      c.lineTo(w, top);
      c.moveTo(0, top + height);
      c.lineTo(w, top + height);
      c.stroke();
      return;
    }

    const box: number[] = this.hole;
    if (box[2] <= 0 || box[3] <= 0) {
      return;
    }
    const p: number[] = this.padded(box);
    c.save();
    c.globalCompositeOperation = 'destination-out';
    this.roundPath(c, p[0], p[1], p[2], p[3], 14);
    c.fill();
    c.restore();

    c.save();
    this.roundPath(c, p[0], p[1], p[2], p[3], 14);
    c.strokeStyle = 'rgba(227,195,119,0.30)';
    c.lineWidth = 6;
    c.stroke();
    c.strokeStyle = 'rgba(240,211,146,0.95)';
    c.lineWidth = 1.6;
    c.stroke();
    c.restore();
  }

  private bubbleW(): number {
    const max: number = Math.min(340, this.cw - 28);
    return max > 210 ? max : 210;
  }

  private bubbleX(): number {
    const width: number = this.bubbleW();
    if (this.step().zones || this.hole[2] <= 0) {
      return Math.max(14, (this.cw - width) / 2);
    }
    return Math.min(Math.max(14, this.hole[0] + this.hole[2] / 2 - width / 2),
      Math.max(14, this.cw - width - 14));
  }

  private bubbleY(): number {
    const edge: number = 14;
    const h: number = this.bh;
    if (this.step().zones || this.hole[2] <= 0) {
      return Math.max(this.safeTop + edge, (this.ch - h) / 2 - 40);
    }
    const below: number = this.hole[1] + this.hole[3] + 18;
    const above: number = this.hole[1] - h - 18;
    const roomBelow: number = this.ch - this.safeBottom - edge - below;
    const roomAbove: number = above - this.safeTop - edge;
    if (roomBelow >= h) {
      return below;
    }
    if (roomAbove >= 0) {
      return above;
    }
    return Math.max(this.safeTop + edge, Math.min(below, this.ch - h - edge));
  }

  @Builder
  bubble() {
    Column({ space: 0 }) {
      Row() {
        Text(`${this.step().group} · ${this.index + 1} / ${STEPS.length}`)
          .fontSize(9.5)
          .fontFamily(FT.mono)
          .letterSpacing(1)
          .fontColor('#bfa163')
        Blank()
        Text(t('跳过'))
          .fontSize(10.5)
          .fontColor('#8d887c')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .onClick(() => {
            this.visible = false;
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 6 })

      Text(this.step().title)
        .fontSize(16)
        .fontFamily(FT.disp)
        .fontColor('#f0ebdf')
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 6 })
      Text(this.step().body)
        .fontSize(12)
        .lineHeight(21)
        .fontColor('#bab5a9')
        .alignSelf(ItemAlign.Start)
      Row() {
        Text(t('上一步'))
          .fontSize(11.5)
          .fontColor(this.index > 0 ? '#d8d2c4' : '#5b574e')
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .borderRadius(9)
          .border({ width: 1, color: this.index > 0 ? '#41453f' : '#2b2e2c' })
          .onClick(() => {
            if (this.index > 0) {
              this.index = this.index - 1;
            }
          })
        Blank()
        Row() {
          Text(this.index >= STEPS.length - 1 ? t('开始阅读') : t('下一步'))
            .fontSize(11.5)
            .fontColor('#1a1c1a')
        }
        .padding({ left: 16, right: 16, top: 7, bottom: 7 })
        .borderRadius(9)
        .backgroundColor('#E3C377')
        .onClick(() => {
          if (this.index >= STEPS.length - 1) {
            this.visible = false;
          } else {
            this.index = this.index + 1;
          }
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 14 })
    }
    .width(this.bubbleW())
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor('#15171a')
    .borderRadius(16)
    .border({ width: 1, color: '#6d5b2c' })
    .shadow({ radius: 28, color: '#a6000000', offsetY: 12 })
    .position({ x: this.bubbleX(), y: this.bubbleY() })
    .onAreaChange((oldArea: Area, newArea: Area) => {
      const h: number = typeof newArea.height === 'number' ? newArea.height as number : parseFloat(`${newArea.height}`);
      if (h > 0 && Math.abs(h - this.bh) > 0.5) {
        this.bh = h;
      }
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Canvas(this.ctx)
        .width('100%')
        .height('100%')
        .onClick(() => {
        })
        .onReady(() => {
          this.measure();
          this.paint();
        })
        .onAreaChange((oldArea: Area, newArea: Area) => {
          this.cw = typeof newArea.width === 'number' ? newArea.width as number : parseFloat(`${newArea.width}`);
          this.ch = typeof newArea.height === 'number' ? newArea.height as number : parseFloat(`${newArea.height}`);
          this.redraw();
        })
      this.bubble()
    }
    .width('100%')
    .height('100%')
  }
}
