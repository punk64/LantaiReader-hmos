export class ProgressMarks {
  private static marks: Map<string, number> = new Map<string, number>();
  private static forced: Map<string, boolean> = new Map<string, boolean>();
  private static timer: number = -1;

  static put(id: string, page: number, pages: number = 0, wasDone: boolean = false): void {
    if (id.length === 0 || page < 0) {
      return;
    }
    const pinned: boolean = ProgressMarks.forced.delete(id);
    const before: number | undefined = ProgressMarks.marks.get(id);
    const finished: boolean = wasDone || (before !== undefined && pages > 0 && before >= pages);
    const open: boolean = pages > 0 && page < pages;
    if (before === page) {
      if (pinned) {
        ProgressMarks.bump();
      }
      return;
    }
    ProgressMarks.marks.set(id, page);
    if (finished && open) {
      ProgressMarks.flush();
      AppStorage.setOrCreate('markRev', Date.now());
      return;
    }
    ProgressMarks.bump();
  }

  static settle(id: string, completed: boolean, pages: number): void {
    if (id.length === 0) {
      return;
    }
    ProgressMarks.forced.delete(id);
    if (!completed) {
      ProgressMarks.marks.set(id, 0);
    } else if (pages > 0) {
      ProgressMarks.marks.set(id, pages);
    } else {
      ProgressMarks.forced.set(id, true);
    }
    ProgressMarks.flush();
    AppStorage.setOrCreate('markRev', Date.now());
  }

  static pageOf(id: string, fallback: number): number {
    const hit: number | undefined = ProgressMarks.marks.get(id);
    return hit === undefined ? fallback : hit;
  }

  static doneOf(id: string, fallback: boolean, page: number, pages: number): boolean {
    const pinned: boolean | undefined = ProgressMarks.forced.get(id);
    if (pinned !== undefined) {
      return pinned;
    }
    if (ProgressMarks.marks.has(id) && pages > 0) {
      return page >= pages;
    }
    return fallback;
  }

  static drop(id: string): void {
    let changed: boolean = ProgressMarks.marks.delete(id);
    if (ProgressMarks.forced.delete(id)) {
      changed = true;
    }
    if (changed) {
      ProgressMarks.bump();
    }
  }

  static flush(): void {
    if (ProgressMarks.timer >= 0) {
      clearTimeout(ProgressMarks.timer);
      ProgressMarks.timer = -1;
    }
    AppStorage.setOrCreate('progressVer', Date.now());
  }

  private static bump(): void {
    if (ProgressMarks.timer >= 0) {
      return;
    }
    ProgressMarks.timer = setTimeout(() => {
      ProgressMarks.timer = -1;
      AppStorage.setOrCreate('progressVer', Date.now());
    }, 250);
  }
}
