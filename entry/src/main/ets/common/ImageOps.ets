import { image } from '@kit.ImageKit';
import { taskpool } from '@kit.ArkTS';

interface PixelAdjust {
  pixels: ArrayBuffer;
  width: number;
  height: number;
  left: number;
  top: number;
}

@Concurrent
function adjustPixels(pixels: ArrayBuffer, width: number, height: number,
  crop: boolean, enhance: boolean): PixelAdjust {
  const buf: Uint8Array = new Uint8Array(pixels);
  const edges: number[] = [0, 0, 0, 0];
  if (crop) {
    const dy: number = Math.max(6, Math.floor(height * 0.1));
    const dx: number = Math.max(6, Math.floor(width * 0.1));
    for (let side: number = 0; side < 4; side++) {
      const vertical: boolean = side < 2;
      const far: boolean = side === 1 || side === 3;
      const depth: number = vertical ? dy : dx;
      const span: number = vertical ? width : height;
      const origin: number = (vertical ? height : width) - depth;
      const ref: number = far ? origin : 0;
      let bgR: number = 0;
      let bgG: number = 0;
      let bgB: number = 0;
      let count: number = 0;
      for (let t: number = 0; t < span; t += 8) {
        const y: number = vertical ? ref : t;
        const x: number = vertical ? t : ref;
        const at: number = (y * width + x) * 4;
        bgR += buf[at];
        bgG += buf[at + 1];
        bgB += buf[at + 2];
        count++;
      }
      if (count === 0) {
        continue;
      }
      bgR = bgR / count;
      bgG = bgG / count;
      bgB = bgB / count;
      for (let step: number = 0; step < depth; step++) {
        const line: number = far ? depth - 1 - step : step;
        const pos: number = far ? origin + line : line;
        let diff: number = 0;
        for (let t: number = 0; t < span; t += 12) {
          const y: number = vertical ? pos : t;
          const x: number = vertical ? t : pos;
          const at: number = (y * width + x) * 4;
          const d: number = Math.abs(buf[at] - bgR) + Math.abs(buf[at + 1] - bgG)
            + Math.abs(buf[at + 2] - bgB);
          if (d > 42) {
            diff++;
          }
        }
        if (diff > 2) {
          edges[side] = far ? depth - line : line;
          break;
        }
      }
    }
  }
  const top: number = edges[0];
  const bottom: number = edges[1];
  const left: number = edges[2];
  const right: number = edges[3];
  const nw: number = width - left - right;
  const nh: number = height - top - bottom;
  const doCrop: boolean = crop && nw > 0 && nh > 0
    && nw >= width * 0.35 && nh >= height * 0.35
    && (top + bottom + left + right) > 0;
  const outW: number = doCrop ? nw : width;
  const outH: number = doCrop ? nh : height;
  const ox: number = doCrop ? left : 0;
  const oy: number = doCrop ? top : 0;
  if (!enhance) {
    const plain: PixelAdjust = { pixels: pixels, width: outW, height: outH, left: ox, top: oy };
    return plain;
  }
  const lut: number[] = [];
  for (let v: number = 0; v < 256; v++) {
    const n: number = (v - 128) * 1.08 + 128 - 4;
    lut.push(Math.min(255, Math.max(0, Math.round(n))));
  }
  if (!doCrop) {
    for (let index: number = 0; index < buf.length; index += 4) {
      buf[index] = lut[buf[index]];
      buf[index + 1] = lut[buf[index + 1]];
      buf[index + 2] = lut[buf[index + 2]];
    }
    const whole: PixelAdjust = { pixels: pixels, width: width, height: height, left: 0, top: 0 };
    return whole;
  }
  const target: ArrayBuffer = new ArrayBuffer(outW * outH * 4);
  const dst: Uint8Array = new Uint8Array(target);
  for (let y: number = 0; y < outH; y++) {
    const row: number = (oy + y) * width + ox;
    const out: number = y * outW;
    for (let x: number = 0; x < outW; x++) {
      const src: number = (row + x) * 4;
      const at: number = (out + x) * 4;
      dst[at] = lut[buf[src]];
      dst[at + 1] = lut[buf[src + 1]];
      dst[at + 2] = lut[buf[src + 2]];
      dst[at + 3] = buf[src + 3];
    }
  }
  const tuned: PixelAdjust = { pixels: target, width: outW, height: outH, left: ox, top: oy };
  return tuned;
}

export class ImageOps {
  static async tune(pixel: image.PixelMap, crop: boolean, enhance: boolean): Promise<void> {
    if (!crop && !enhance) {
      return;
    }
    const info: image.ImageInfo = await pixel.getImageInfo();
    const w: number = info.size.width;
    const h: number = info.size.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    const source: image.PositionArea = {
      pixels: new ArrayBuffer(w * h * 4),
      offset: 0,
      stride: w * 4,
      region: {
        size: { width: w, height: h },
        x: 0,
        y: 0
      }
    };
    await pixel.readPixels(source);
    const task: taskpool.Task = new taskpool.Task(adjustPixels, source.pixels, w, h, crop, enhance);
    const adjust: PixelAdjust = await taskpool.execute(task) as PixelAdjust;
    if (adjust.width !== w || adjust.height !== h) {
      const region: image.Region = {
        size: { width: adjust.width, height: adjust.height },
        x: adjust.left,
        y: adjust.top
      };
      await pixel.crop(region);
    }
    if (!enhance) {
      return;
    }
    const target: image.PositionArea = {
      pixels: adjust.pixels,
      offset: 0,
      stride: adjust.width * 4,
      region: {
        size: { width: adjust.width, height: adjust.height },
        x: 0,
        y: 0
      }
    };
    await pixel.writePixels(target);
  }
}
