import { C } from '../common/Theme';
import { drawGlyph } from '../common/Icons';

@Component
export struct GlyphIcon {
  @StorageLink('uiTick') @Watch('paint') uiTick: number = 0;
  @Prop @Watch('paint') glyphName: string = '';
  @Prop @Watch('paint') glyphSize: number = 18;
  @Prop @Watch('paint') glyphColor: string = C.tx2;
  @Prop @Watch('paint') glyphWeight: number = 1.7;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  paint(): void {
    const c: CanvasRenderingContext2D = this.ctx;
    const k: number = this.glyphSize / 24;
    c.clearRect(0, 0, this.glyphSize, this.glyphSize);
    c.strokeStyle = this.glyphColor;
    c.lineWidth = this.glyphWeight * k;
    c.lineCap = 'round';
    c.lineJoin = 'round';
    drawGlyph(c, this.glyphName, k);
    c.stroke();
  }

  build() {
    Canvas(this.ctx)
      .width(this.glyphSize)
      .height(this.glyphSize)
      .onReady(() => {
        this.paint();
      })
  }
}
