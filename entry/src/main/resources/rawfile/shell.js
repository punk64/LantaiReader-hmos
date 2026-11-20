(function () {
  'use strict';

  var DICT_EN = {
    '第四个键开始朗读本章，从上次听到的那一句接着读，不是从头。长按这一键＝从当前屏幕第一句开始；长按正文任意位置＝从那条金色虚线处开始，只剩几句没听完时用这两个最快。屏幕浮出朗读球，球面是封面中央，金环是本章进度，播放中球外有一圈微光。点球展开控制条：左端封面圆点收回，中间是上一句、播放 / 暂停、下一句与页码，「音色」切音色，末尾 × 关闭。整条可拖动，松手吸附到最近的边，展开 2 秒无操作会自动收回并贴边。当前句金色高亮并自动滚动，读完本章自动接下章，退出阅读器回到书架也继续播，只有点 × 才彻底结束。语速、语气、语调、间隙与音色在阅读设置里。': 'The fourth key reads this chapter from the last sentence heard, not from the start. Long-press it to begin at the first sentence on screen; long-press anywhere in the text to begin at the gold dashed line — fastest when only a few sentences remain. A reading orb floats up with the cover at its center and a gold ring for chapter progress, glowing softly during playback. Tap it to expand controls: cover dot to collapse, previous / play-pause / next and page number, "Voice" to switch timbre, and X to close. The bar is draggable and snaps to the nearest edge; after 2 seconds idle it collapses and docks. The current sentence highlights and auto-scrolls; at chapter end it continues to the next, and keeps playing even after you return to the shelf — only X fully stops it. Speed, prosody, pitch, gap and voice are in reading settings.',
    '语气四档是整段听感的主开关：平实不加修饰；沉稳放慢压低；轻快稍快提亮；讲述最慢、音高与音量略抬，适合小说。语调在语气之上再压一档高低，间隙把全篇停顿一起收紧或放宽。这三项随时可改，正在读的会从当前这句按新参数重来，不跳句也不停。自动语气打开后按标点、句长与段落安排停顿与轻重，不识别语义，偏保守但对话多的段落明显自然；关掉就是一律平的旧读法。强调让叠词与拟声词轻微加重，依赖自动语气。音色只列系统里已安装的发音人，切换时同样从当前句续上。': 'The four prosody styles are the main switch for overall feel: Plain adds no ornament; Calm slows and lowers; Lively speeds up and brightens; Story is slowest with slightly raised pitch and volume, ideal for fiction. Pitch adds one more level of high/low on top of prosody, and Gap tightens or loosens pauses throughout. All three can be changed anytime; what is playing restarts from the current sentence with the new settings, without skipping or stopping. Auto prosody uses punctuation, sentence length and paragraphs for pauses and stress — it does not understand meaning, stays conservative, but feels noticeably more natural in dialogue-heavy passages; turning it off gives the old flat reading. Emphasis slightly stresses reduplication and onomatopoeia and depends on auto prosody. Voices lists only installed system speakers; switching continues from the current sentence too.',
    ' · 停在第 ': ' · stopped at ',
    ' · 阅读': ' · Read',
    ' 书签 · ': ' bookmarks · ',
    ' 分': ' min',
    ' 分 ': ' min ',
    ' 分钟前': ' min ago',
    ' 卷 · 第 ': ' Vol. · No. ',
    ' 句开始': '',
    ' 处 · ': ' matches · ',
    ' 天前': ' d ago',
    ' 字': ' chars',
    ' 小时前': ' h ago',
    ' 时 ': ' h ',
    ' 标注': ' marks',
    ' 秒': ' s',
    ' 章': ' chapter',
    ' 章 · 共 ': ' Ch. · of ',
    ' 章加书签': '',
    ' 章已有书签': ' already bookmarked',
    ' 给第 ': ' Bookmark Ch. ',
    ' 节': ' section',
    ' 页': ' page',
    '">删除': '">Delete',
    '">编辑': '">Edit',
    '% 处': '% matches',
    '」': '"',
    '万': '0k',
    '三区轻点': 'Three-zone tap',
    '三档筛选：全部 / 书签 / 标注，标题栏右侧显示书签与标注各多少条。': 'Three filters: All / Bookmarks / Marks; the header shows counts on the right.',
    '三组读数：卷 / 节位置、本章进度、全书百分比。手机宽度下上一章 / 下一章按钮会隐藏，翻页请用左右轻点或进度条。': 'Three readouts: volume/section position, chapter progress and book percentage. On narrow screens the prev/next buttons hide; use side taps or the progress bar.',
    '上一本': 'Prev book',
    '上一步': 'Previous',
    '上一章': 'Prev chapter',
    '上面一行是书名，下面一行是当前章名与「第 n / N 章」，翻页时跟着变。开启隐身阅读时书名后会多一个「隐身」标记。': 'The top line is the title, the line below shows the current chapter and "n / N", updating as you turn pages. Incognito adds an "Incognito" tag after the title.',
    '下一本': 'Next book',
    '下一步': 'Next',
    '下一章': 'Next chapter',
    '下划线': 'Underline',
    '中': 'Normal',
    '中文': 'Chinese',
    '中间 44%': 'Center 44%',
    '主题': 'Theme',
    '书名与章节': 'Title & chapter',
    '书签': 'Bookmark',
    '书签与标注': 'Bookmarks & marks',
    '书签保存失败：': 'Bookmark save failed: ',
    '书籍或章节不存在': 'Book or chapter not found',
    '五个入口并排在底栏最下一排：目录、全书搜索、标注与笔记、朗读、阅读设置，点一下直接展开对应面板，不再经一层转发。当前面板对应的键位变金色。': 'Five entries in the bottom row: contents, full-text search, marks & notes, read aloud and settings. Tap to open the panel directly; the active key turns gold.',
    '五档：纸白、牛皮纸、护眼、墨黑、夜间。点圆点直接换，正文与工具栏配色会一起变。': 'Five options: Paper, Sepia, Green, Ink, Night. Tap a swatch to switch; text and toolbar colors change together.',
    '交互': 'Interaction',
    '从右往左': 'Right to left',
    '从左往右': 'Left to right',
    '从第 ': 'From sentence ',
    '从这里朗读': 'Read from here',
    '低': 'Low',
    '保存': 'Save',
    '保存失败：': 'Save failed: ',
    '全书 ': 'Book ',
    '全书完': 'End of book',
    '全书搜索': 'Search book',
    '全部': 'All',
    '兰台 · ': 'Lantai · ',
    '关闭原书样式使用兰台排版，字号与行距调整才会生效；打开可还原出版社版式。': 'Turn off to use Lantai layout (font size and line height apply); turn on to restore the publisher style.',
    '其他': 'Other',
    '内容渲染超时': 'Content render timeout',
    '写一条笔记': 'Write a note',
    '写笔记': 'Write note',
    '分页模式下方向决定左右点击区；连续滚动时方向不生效。': 'In paged mode direction sets the tap zones; it has no effect in continuous scroll.',
    '刚刚': 'Just now',
    '删除失败：': 'Delete failed: ',
    '功能栏': 'Action bar',
    '加书签': 'Add bookmark',
    '加载中': 'Loading',
    '单栏分页': 'Single-column pages',
    '卷': 'Volume',
    '卷 ': 'Vol. ',
    '卷标题用「卷」标注，节显示章号；右侧数字是本章字数，一万以上按「万」显示。当前章高亮并自动滚到屏幕中间。': 'Volumes are marked "Vol." and sections show chapter numbers; the right-side number is the word count (shown as "0k" above ten thousand). The current chapter is highlighted and scrolled to center.',
    '原书': 'Original',
    '原书样式': 'Original style',
    '双栏分页': 'Two-column pages',
    '取消': 'Cancel',
    '叠词与拟声词轻微加重，需在自动语气开启时生效；误判时关闭即可。': 'Slightly emphasizes reduplication and onomatopoeia; requires auto prosody. Disable if misjudged.',
    '右上角叉号关闭目录。也可以点面板外的空白处，或按系统返回键 —— 返回键会先关面板，不会直接退出阅读器。': 'The top-right X closes contents. You can also tap outside or press Back, which closes the panel first instead of exiting the reader.',
    '右上角这个键随时重看这套引导。第一次打开一本书会自动演示一遍，之后不再自动弹出；顶栏收起时先点屏幕中间把它叫出来。': 'The top-right button replays this guide anytime. It shows automatically on first open, then never again; when the top bar is hidden, tap the center first.',
    '右侧 28%': 'Right 28%',
    '后端不可用': 'Backend unavailable',
    '唤出 / 收起': 'Show / hide',
    '图片未能加载': 'Image failed to load',
    '墨黑': 'Ink',
    '复制': 'Copy',
    '复制失败': 'Copy failed',
    '夜间': 'Night',
    '字体': 'Font',
    '字号': 'Font size',
    '字号 A- / A+ 逐级调（13~32）；下面依次是行距紧中松、段距窄中宽、字体、首行缩进开关、版心（每行字数，26~64）、原书样式。': 'Font size A-/A+ (13-32); below are line height tight/normal/loose, paragraph gap, font, first-line indent, page width (26-64 chars) and original style.',
    '宋体': 'Serif',
    '宽': 'Wide',
    '屏幕常亮': 'Keep screen on',
    '屏幕常亮申请被拒绝': 'Keep screen on request denied',
    '屏幕常亮需要 HTTPS 或 localhost': 'Keep screen on requires HTTPS or localhost',
    '屏幕常亮：阅读时不熄屏。隐身阅读：本次不写进度、不上报时长，也不会出现在统计里。': 'Keep screen on: no sleep while reading. Incognito: no progress or time recorded, and the session stays out of stats.',
    '左 28% 往回、右 28% 往前、只有中间 44% 能唤出或收起操作栏。连续滚动时左右各滚近一屏；切到单栏 / 双栏翻页后，左右各翻一页。翻页与上下滚动都不会把操作栏叫出来。': 'Left 28% goes back, right 28% goes forward; only the middle 44% shows/hides the toolbar. In continuous scroll the sides scroll one screen; in paged mode they turn one page. Neither summons the toolbar.',
    '左上角退出阅读器，回到书架或详情页。进度已经存下来了，下次打开直接续上。操作栏自动收起时，先点屏幕中间把它叫出来。': 'The top-left button exits the reader to the shelf or details page. Your position is saved for next time. When the toolbar auto-hides, tap the center to bring it back.',
    '左侧 28%': 'Left 28%',
    '已保存「': 'Saved "',
    '已在第 ': 'At position ',
    '已复制': 'Copied',
    '已恢复记录进度': 'Progress recording restored',
    '已更新': 'Updated',
    '已读 ': 'Read ',
    '帮助': 'Help',
    '常': 'Normal',
    '平实': 'Plain',
    '底栏': 'Bottom bar',
    '底栏 · 进度与功能': 'Bottom bar · progress & actions',
    '底栏最左侧第一个键打开目录面板。全书按卷 / 节两级列出，当前章高亮，点任意一行立刻跳过去。再点一次这个键收起。': 'The leftmost bottom key opens contents. Chapters are listed by volume/section with the current one highlighted; tap any row to jump. Tap again to close.',
    '底色': 'Background',
    '开启点按翻页后，左右区域点一下即翻页，正文链接优先跳转；关闭后只有链接可点。中间区域点一下呼出工具栏。': 'With tap-to-turn on, tap left/right to turn pages (text links take priority); off means only links respond. Tap the center to show the toolbar.',
    '开始阅读': 'Start reading',
    '强调': 'Emphasis',
    '往前一屏': 'Forward one screen',
    '往回一屏': 'Back one screen',
    '快': 'Fast',
    '想法、出处、待查…': 'Idea, source, to check…',
    '慢': 'Slow',
    '打不开这本书': 'Cannot open this book',
    '护眼': 'Green',
    '拖动定位，点键开面板': 'Drag to seek; tap a key to open a panel',
    '拖动时三组读数实时预览目标位置，松手才跳；点轨道任意位置也直接跳。拖到别的章时，本章进度会显示为「—」。': 'Dragging previews the target position; release to jump. Tap the track to jump directly. When dragging into another chapter, chapter progress shows "—".',
    '按 B 给当前章加书签；选中文字可高亮、划下划线或写笔记': 'Press B to bookmark the chapter; select text to highlight, underline or note',
    '按章节名筛选，边输边过滤，只匹配标题、不搜正文。清空输入框恢复完整目录。': 'Filter by chapter title as you type; only titles match, not body text. Clear the field to restore the full list.',
    '排版': 'Layout',
    '搜索': 'Search',
    '搜索 · 展开态': 'Search · expanded',
    '搜索书签、标注或笔记': 'Search bookmarks, marks or notes',
    '搜索失败：': 'Search failed: ',
    '搜索正文，回车开始': 'Search full text; press Enter',
    '搜索章节': 'Search chapters',
    '操作指引': 'Guide',
    '操作栏收起后，屏幕底部留一枚半透明胶囊，按卷 / 章 / 节与全书百分比显示进度。它不挡正文，也不拦点击 —— 点它等于点正文。': 'When the toolbar hides, a translucent pill stays at the bottom showing volume/chapter/section and book percentage. It neither covers text nor blocks taps — tapping it is like tapping the text.',
    '收起态胶囊': 'Collapsed pill',
    '方向': 'Direction',
    '方式': 'Method',
    '无结果': 'No results',
    '更多颜色': 'More colors',
    '更新失败：': 'Update failed: ',
    '朗读': 'Read aloud',
    '朗读不可用': 'Read aloud unavailable',
    '本章 ': 'This chapter ',
    '本章完': 'End of chapter',
    '松': 'Loose',
    '极快': 'Very fast',
    '标准': 'Standard',
    '标注': 'Marks',
    '标注 · 展开态': 'Marks · expanded',
    '标注与笔记': 'Marks & notes',
    '标注已删除': 'Mark deleted',
    '楷体': 'Kai',
    '正在搜索…': 'Searching…',
    '正在读取目录…': 'Loading contents…',
    '正在载入': 'Loading',
    '正在重排': 'Reflowing',
    '段距': 'Paragraph gap',
    '每章末尾有「上一章 · 本章完 · 下一章」接续条；在线书读到最后还能直接续到下一本。随时可在顶栏右上角的「指引」重看本引导。': 'Each chapter ends with a "Prev · End of chapter · Next" bar; online books continue to the next volume. Replay this guide anytime from "Guide" at the top right.',
    '沉稳': 'Calm',
    '没有匹配的条目': 'No matching items',
    '没有匹配的章节': 'No matching chapters',
    '没有可复制的内容': 'Nothing to copy',
    '没有可打开的书': 'No book to open',
    '没有找到「': 'Not found: ',
    '没有这个书库的阅读权限': 'No access to this library',
    '浏览器拒绝了全屏请求': 'Browser denied fullscreen',
    '点按翻页': 'Tap to turn',
    '版心': 'Page width',
    '牛皮纸': 'Sepia',
    '目录': 'Contents',
    '目录 · 关闭': 'Contents · close',
    '目录 · 搜索框': 'Contents · search',
    '目录 · 章节列表': 'Contents · chapter list',
    '窄': 'Narrow',
    '章 ': 'Ch. ',
    '章末续读': 'Chapter continuation',
    '章节还在载入': 'Chapter still loading',
    '笔记': 'Note',
    '笔记…': 'Note…',
    '第 ': 'No. ',
    '第三个键列出全书所有书签、高亮与笔记，按章节顺序排，点一条跳回原文位置。': 'The third key lists all bookmarks, highlights and notes in chapter order; tap one to jump back.',
    '第二个键打开全书搜索，跨全书所有章节搜正文关键词。首次搜索要现建索引，可能慢几秒，之后会快很多。': 'The second key opens full-text search across all chapters. The first search builds an index and may take a few seconds; later searches are fast.',
    '第五个键展开设置面板，分五组：底色、排版、翻页、朗读、阅读。改动即时生效并记住，下面逐个说。': 'The fifth key opens settings in five groups: background, layout, page turn, read aloud and reading. Changes apply instantly and are saved.',
    '系统默认': 'System default',
    '紧': 'Tight',
    '纸白': 'Paper',
    '编辑': 'Edit',
    '缩进': 'Indent',
    '网页端': 'Web version',
    '翻页': 'Page turn',
    '自动语气': 'Auto prosody',
    '自动语气按标点、句长与段落安排停顿和轻重，不识别语义；关闭后与旧版听感一致。': 'Auto prosody uses punctuation, sentence length and paragraphs for pauses and stress, without semantic understanding; turn off for the classic sound.',
    '自动隐藏，点按钮不翻页': 'Auto-hides; tapping buttons does not turn pages',
    '节 ': 'Sec. ',
    '英语': 'English',
    '行距': 'Line height',
    '讲述': 'Story',
    '设置': 'Settings',
    '设置面板最底部的「重新观看」，点一下回到当前这个引导。': 'Tap "Replay" at the bottom of settings to return to this guide.',
    '语气': 'Prosody',
    '语调': 'Pitch',
    '语速': 'Speed',
    '请求失败': 'Request failed',
    '读数': 'Readouts',
    '跳过': 'Skip',
    '轻快': 'Lively',
    '载入失败：': 'Load failed: ',
    '输入关键词后回车': 'Enter a keyword and press Enter',
    '输入关键词后回车开始搜。结果按章节列出、命中词高亮，顶部显示命中总处数与涉及章数；点一条直接跳到那一段。': 'Type a keyword and press Enter. Results are listed by chapter with matches highlighted; the top shows total matches and chapters. Tap a result to jump.',
    '返回': 'Back',
    '还没有书签和标注': 'No bookmarks or marks yet',
    '这一章没有可朗读的文字': 'No readable text in this chapter',
    '这一章没有找到标注位置': 'No mark position found in this chapter',
    '这一章还没有可锚定的位置': 'No anchorable position in this chapter',
    '这一行是「给第 N 章加书签」，点一下把当前章节位置记下来。同一章只会有一个书签，重复加会提示已存在。': 'This row bookmarks the current chapter. Each chapter has one bookmark; adding again reports it exists.',
    '这本书不在书库里': 'This book is not in the library',
    '这本书需要先安装转换器': 'This book needs a converter installed',
    '这里没有可朗读的文字': 'No readable text here',
    '进度条': 'Progress bar',
    '连不上兰台': 'Cannot reach Lantai',
    '连续滚动': 'Continuous scroll',
    '连续滚动上下滑；单栏分页一屏一页；双栏分页一屏两栏。方向（从左往右 / 从右往左）只在分页模式生效；点按翻页打开后，左右区域点一下即翻页。': 'Continuous scroll slides vertically; single-column shows one page per screen, two-column shows two. Direction (L-to-R / R-to-L) applies only in paged mode; with tap-to-turn on, tap left/right to turn.',
    '连续滚动下方向不生效，先切到分页': 'Direction has no effect in continuous scroll; switch to paged mode first',
    '选中与标注': 'Select & mark',
    '重新观看': 'Replay',
    '重看指引': 'Replay guide',
    '重试': 'Retry',
    '长按正文选中文字，浮出四色高亮、下划线、写笔记、复制、朗读这段。选中期间点左右两侧不会误翻页，轻点空白处先取消选中。': 'Long-press text to select it and reveal four highlight colors, underline, note, copy and read-aloud. Side taps won\'t turn pages while selecting; tap blank space to deselect.',
    '间隙': 'Gap',
    '阅读': 'Read',
    '阅读设置': 'Reading settings',
    '隐身': 'Incognito',
    '隐身阅读': 'Incognito reading',
    '隐身阅读 · 本次不留记录': 'Incognito · no record kept',
    '隐身阅读不写入进度、不上报时长，本次阅读不会出现在统计里。': 'Incognito writes no progress or time and this session will not appear in stats.',
    '隐身阅读已开启，本次不记录进度': 'Incognito is on; no progress is recorded',
    '需下载': 'Download needed',
    '音色': 'Voice',
    '顶栏': 'Top bar',
    '顶栏 · 按钮区': 'Top bar · buttons',
    '顶栏、目录、底栏功能栏、进度条、触控分区、选中标注与章末接续，逐步演示一遍。': 'Step-by-step tour of the top bar, contents, bottom actions, progress bar, tap zones, selection marks and chapter continuation.',
    '首次搜索要建立正文索引，请稍候…': 'First search builds the text index; please wait…',
    '高': 'High',
    '高亮': 'Highlight',
    '黑体': 'Sans',
  };

  var DICT_JA = {
    ' · 停在第 ': ' · 第 ',
    ' · 阅读': ' · 読書',
    ' 书签 · ': ' しおり · ',
    ' 卷 · 第 ': ' 巻 · 第 ',
    ' 句开始': ' 文から開始',
    ' 处 · ': ' 箇所 · ',
    ' 字': ' 字',
    ' 标注': ' 注釈',
    ' 章': ' 章',
    ' 章 · 共 ': ' 章 · 全 ',
    ' 章加书签': ' 章にしおりを追加',
    ' 章已有书签': ' 章にしおりがあります',
    ' 给第 ': ' 第 ',
    ' 节': ' 節',
    ' 页': ' ページ',
    '">删除': '">削除',
    '">编辑': '">編集',
    '% 处': '% 箇所',
    '万': '万',
    '上一本': '前の本',
    '上一步': '前へ',
    '上一章': '前の章',
    '下一本': '次の本',
    '下一步': '次へ',
    '下一章': '次の章',
    '下划线': '下線',
    '中': '中',
    '中文': '中国語',
    '主题': 'テーマ',
    '书签': 'しおり',
    '书签与标注': 'しおりと注釈',
    '书签保存失败：': 'しおりの保存に失敗：',
    '书籍或章节不存在': '書籍または章が存在しません',
    '从右往左': '右から左へ',
    '从左往右': '左から右へ',
    '从第 ': ' 第 ',
    '从这里朗读': 'ここから読み上げ',
    '保存': '保存',
    '保存失败：': '保存に失敗：',
    '全书 ': ' 書籍全体 ',
    '全书完': '全編完了',
    '全书搜索': '書籍全体を検索',
    '全部': 'すべて',
    '兰台 · ': 'Lantai · ',
    '关闭原书样式使用兰台排版，字号与行距调整才会生效；打开可还原出版社版式。': '原書のスタイルをオフにすると Lantai の組版を使用し、文字サイズと行間の調整が反映されます。オンにすると出版社の版式に戻ります。',
    '其他': 'その他',
    '内容渲染超时': 'コンテンツの描画がタイムアウト',
    '写一条笔记': 'ノートを書く',
    '写笔记': 'ノートを書く',
    '分页模式下方向决定左右点击区；连续滚动时方向不生效。': 'ページ分割モードでは方向が左右のタップ領域を決めます。連続スクロール時は方向は無効です。',
    '删除失败：': '削除に失敗：',
    '加载中': '読み込み中',
    '单栏分页': '1カラム改ページ',
    '卷': '巻',
    '卷 ': ' 巻 ',
    '原书': '原書',
    '原书样式': '原書のスタイル',
    '双栏分页': '2カラム改ページ',
    '取消': 'キャンセル',
    '叠词与拟声词轻微加重，需在自动语气开启时生效；误判时关闭即可。': '重ね言葉と擬音語をわずかに強調します。自動抑揚が有効な場合にのみ反映され、誤判定時はオフにしてください。',
    '后端不可用': 'バックエンドが利用できません',
    '图片未能加载': '画像を読み込めませんでした',
    '墨黑': '墨黒',
    '复制': 'コピー',
    '复制失败': 'コピー失敗',
    '夜间': '夜間',
    '字体': 'フォント',
    '字号': '文字サイズ',
    '宋体': '明朝体',
    '宽': '広い',
    '屏幕常亮': '画面を消灯しない',
    '屏幕常亮申请被拒绝': '画面の常時点灯申請が拒否されました',
    '屏幕常亮需要 HTTPS 或 localhost': '画面の常時点灯には HTTPS または localhost が必要です',
    '已保存「': '保存しました「',
    '已在第 ': ' 第 ',
    '已复制': 'コピーしました',
    '已恢复记录进度': '進捗記録を復元しました',
    '已更新': '更新しました',
    '已读 ': ' 既読 ',
    '帮助': 'ヘルプ',
    '常': '通常',
    '底栏 · 进度与功能': '下部バー · 進捗と機能',
    '底色': '背景色',
    '开启点按翻页后，左右区域点一下即翻页，正文链接优先跳转；关闭后只有链接可点。中间区域点一下呼出工具栏。': 'タップでページ送りを有効にすると、左右の領域をタップするだけでページが送られ、本文内のリンクが優先的に開きます。オフにするとリンクのみタップ可能になります。中央の領域をタップするとツールバーが表示されます。',
    '开始阅读': '読書を開始',
    '强调': '強調',
    '快': '速い',
    '想法、出处、待查…': 'アイデア・出典・要確認…',
    '慢': '遅い',
    '打不开这本书': 'この本を開けません',
    '护眼': '目に優しい',
    '拖动定位，点键开面板': 'ドラッグで位置指定、ボタンでパネルを開く',
    '按 B 给当前章加书签；选中文字可高亮、划下划线或写笔记': 'B キーで現在の章にしおりを追加。文字を選択するとハイライト、下線、ノートを追加できます',
    '排版': '組版',
    '搜索书签、标注或笔记': 'しおり・注釈・ノートを検索',
    '搜索失败：': '検索に失敗：',
    '搜索正文，回车开始': '本文を検索。Enter で開始',
    '搜索章节': '章を検索',
    '操作指引': '操作ガイド',
    '方向': '方向',
    '方式': '方式',
    '无结果': '結果なし',
    '更多颜色': 'その他の色',
    '更新失败：': '更新に失敗：',
    '朗读': '読み上げ',
    '朗读不可用': '読み上げを利用できません',
    '本章 ': ' 本章 ',
    '本章完': '本章完了',
    '松': '広い',
    '极快': '極速',
    '标注': '注釈',
    '标注已删除': '注釈を削除しました',
    '楷体': '楷書体',
    '正在搜索…': '検索中…',
    '正在读取目录…': '目次を読み込み中…',
    '正在载入': '読み込み中',
    '正在重排': '再組版中',
    '段距': '段落間隔',
    '没有匹配的条目': '一致する項目がありません',
    '没有匹配的章节': '一致する章がありません',
    '没有可复制的内容': 'コピーできる内容がありません',
    '没有可打开的书': '開ける本がありません',
    '没有找到「': '見つかりませんでした「',
    '没有这个书库的阅读权限': 'この書庫の閲覧権限がありません',
    '浏览器拒绝了全屏请求': 'ブラウザーが全画面リクエストを拒否しました',
    '点按翻页': 'タップでページ送り',
    '版心': '本文幅',
    '牛皮纸': 'クラフト紙',
    '目录': '目次',
    '窄': '狭い',
    '章 ': ' 章 ',
    '章节还在载入': '章を読み込み中',
    '笔记': 'ノート',
    '笔记…': 'ノート…',
    '第 ': ' 第 ',
    '系统默认': 'システム既定',
    '紧': '狭い',
    '纸白': '紙白',
    '编辑': '編集',
    '缩进': 'インデント',
    '网页端': 'Web版',
    '翻页': 'ページ送り',
    '自动语气': '自動抑揚',
    '自动语气按标点、句长与段落安排停顿和轻重，不识别语义；关闭后与旧版听感一致。': '自動抑揚は句読点、文の長さ、段落に応じて間と強弱を調整します。意味は認識しません。オフにすると旧版と同じ聞こえ方になります。',
    '自动隐藏，点按钮不翻页': '自動的に隠れ、ボタンをタップしてもページは送られません',
    '节 ': ' 節 ',
    '英语': '英語',
    '行距': '行間',
    '语气': '抑揚',
    '语调': 'ピッチ',
    '语速': '読み上げ速度',
    '请求失败': '要求に失敗',
    '跳过': 'スキップ',
    '载入失败：': '読み込みに失敗：',
    '输入关键词后回车': 'キーワードを入力して Enter',
    '返回': '戻る',
    '还没有书签和标注': 'しおりや注釈がまだありません',
    '这一章没有可朗读的文字': 'この章には読み上げられる文字がありません',
    '这一章没有找到标注位置': 'この章では注釈の位置が見つかりません',
    '这一章还没有可锚定的位置': 'この章にはまだアンカーできる位置がありません',
    '这本书不在书库里': 'この本は書庫にありません',
    '这本书需要先安装转换器': 'この本にはまずコンバーターのインストールが必要です',
    '这里没有可朗读的文字': 'ここには読み上げられる文字がありません',
    '连不上兰台': 'Lantai に接続できません',
    '连续滚动': '連続スクロール',
    '连续滚动下方向不生效，先切到分页': '連続スクロールでは方向は無効です。まずページ分割に切り替えてください',
    '重新观看': 'もう一度見る',
    '重试': '再試行',
    '间隙': '間隔',
    '阅读': '読書',
    '阅读设置': '読書設定',
    '隐身': 'シークレット',
    '隐身阅读': 'シークレット読書',
    '隐身阅读 · 本次不留记录': 'シークレット読書 · 今回は記録を残しません',
    '隐身阅读不写入进度、不上报时长，本次阅读不会出现在统计里。': 'シークレット読書では進捗も時間も記録せず、今回の読書は統計に表示されません。',
    '隐身阅读已开启，本次不记录进度': 'シークレット読書が有効です。今回は進捗を記録しません',
    '需下载': 'ダウンロードが必要',
    '音色': '音色',
    '顶栏 · 按钮区': 'トップバー · ボタン領域',
    '顶栏、目录、底栏功能栏、进度条、触控分区、选中标注与章末接续，逐步演示一遍。': 'トップバー、目次、下部バーの機能バー、プログレスバー、タッチ領域、選択注釈、章末の継続を順を追って説明します。',
    '首次搜索要建立正文索引，请稍候…': '初回検索では本文のインデックスを作成します。しばらくお待ちください…',
    '高亮': 'ハイライト',
    '黑体': 'ゴシック体',
    ' 分': ' 分',
    ' 分 ': ' 分 ',
    ' 分钟前': ' 分前',
    ' 天前': ' 日前',
    ' 小时前': ' 時間前',
    ' 时 ': ' 時 ',
    ' 秒': ' 秒',
    '」': '」',
    '三区轻点': '3領域タップ',
    '三档筛选：全部 / 书签 / 标注，标题栏右侧显示书签与标注各多少条。': '3段階の絞り込み：すべて / しおり / 注釈。タイトルバーの右側にしおりと注釈の件数が表示されます。',
    '三组读数：卷 / 节位置、本章进度、全书百分比。手机宽度下上一章 / 下一章按钮会隐藏，翻页请用左右轻点或进度条。': '3種類の表示：巻 / 節の位置、本章の進捗、書籍全体の割合。スマホ幅では前章 / 次章ボタンが非表示になり、ページ送りは左右のタップまたはプログレスバーを使用します。',
    '上面一行是书名，下面一行是当前章名与「第 n / N 章」，翻页时跟着变。开启隐身阅读时书名后会多一个「隐身」标记。': '上段は書名、下段は現在の章名と「第 n / N 章」で、ページを送ると連動して変わります。シークレット読書が有効な場合、書名の後に「シークレット」マークが付きます。',
    '中间 44%': '中央 44%',
    '书名与章节': '書名と章',
    '五个入口并排在底栏最下一排：目录、全书搜索、标注与笔记、朗读、阅读设置，点一下直接展开对应面板，不再经一层转发。当前面板对应的键位变金色。': '5つの入口が下部バーの最下段に並びます：目次、書籍全体を検索、注釈とノート、読み上げ、読書設定。タップすると直接対応パネルが開き、中継はありません。現在のパネルに対応するキーは金色になります。',
    '五档：纸白、牛皮纸、护眼、墨黑、夜间。点圆点直接换，正文与工具栏配色会一起变。': '5段階：紙白、クラフト紙、目に優しい、墨黒、夜間。丸い点をタップすると直接切り替わり、本文とツールバーの配色も同時に変わります。',
    '交互': '操作',
    '低': '低',
    '刚刚': 'たった今',
    '功能栏': '機能バー',
    '加书签': 'しおりを追加',
    '卷标题用「卷」标注，节显示章号；右侧数字是本章字数，一万以上按「万」显示。当前章高亮并自动滚到屏幕中间。': '巻のタイトルは「巻」で示し、節には章番号を表示します。右側の数字は本章の文字数で、1万以上は「万」で表示されます。現在の章はハイライトされ、自動的に画面中央へスクロールします。',
    '右上角叉号关闭目录。也可以点面板外的空白处，或按系统返回键 —— 返回键会先关面板，不会直接退出阅读器。': '右上のバツで目次を閉じます。パネル外の空白をタップするか、システムの戻るキーでも閉じられます。戻るキーはまずパネルを閉じ、リーダーは終了しません。',
    '右上角这个键随时重看这套引导。第一次打开一本书会自动演示一遍，之后不再自动弹出；顶栏收起时先点屏幕中间把它叫出来。': '右上のこのキーでいつでもこのガイドを見直せます。初めて本を開いたときに自動で一度演示され、以降は自動表示されません。トップバーが収納されている場合は、まず画面中央をタップして表示してください。',
    '右侧 28%': '右側 28%',
    '唤出 / 收起': '表示 / 収納',
    '字号 A- / A+ 逐级调（13~32）；下面依次是行距紧中松、段距窄中宽、字体、首行缩进开关、版心（每行字数，26~64）、原书样式。': '文字サイズは A- / A+ で段階的に調整（13~32）。以下、行間（狭・中・広）、段落間隔（狭・中・広）、フォント、最初の行のインデント切り替え、本文幅（1行の文字数、26~64）、原書のスタイルの順です。',
    '屏幕常亮：阅读时不熄屏。隐身阅读：本次不写进度、不上报时长，也不会出现在统计里。': '画面常時点灯：読書中に画面を消灯しません。シークレット読書：今回は進捗も時間も記録せず、統計にも表示されません。',
    '左 28% 往回、右 28% 往前、只有中间 44% 能唤出或收起操作栏。连续滚动时左右各滚近一屏；切到单栏 / 双栏翻页后，左右各翻一页。翻页与上下滚动都不会把操作栏叫出来。': '左 28% で戻り、右 28% で進み、中央 44% のみ操作バーを表示・収納できます。連続スクロールでは左右それぞれ約1画面分スクロールし、1カラム / 2カラム改ページに切り替えると左右で1ページずつ送ります。ページ送りや上下スクロールでは操作バーは表示されません。',
    '左上角退出阅读器，回到书架或详情页。进度已经存下来了，下次打开直接续上。操作栏自动收起时，先点屏幕中间把它叫出来。': '左上でリーダーを終了し、本棚または詳細ページに戻ります。進捗は保存済みで、次回起動時にそのまま再開します。操作バーが自動収納されている場合は、まず画面中央をタップして表示してください。',
    '左侧 28%': '左側 28%',
    '平实': '平実',
    '底栏': '下部バー',
    '底栏最左侧第一个键打开目录面板。全书按卷 / 节两级列出，当前章高亮，点任意一行立刻跳过去。再点一次这个键收起。': '下部バー最左の最初のキーで目次パネルを開きます。書籍全体を巻 / 節の2段階で一覧表示し、現在の章はハイライトされます。任意の行をタップすると即座にジャンプし、もう一度キーをタップすると閉じます。',
    '往前一屏': '1画面進む',
    '往回一屏': '1画面戻る',
    '拖动时三组读数实时预览目标位置，松手才跳；点轨道任意位置也直接跳。拖到别的章时，本章进度会显示为「—」。': 'ドラッグ中は3種類の表示が移動先をリアルタイムでプレビューし、指を離すとジャンプします。トラックの任意の位置をタップしても直接ジャンプします。別の章までドラッグすると、本章の進捗は「—」と表示されます。',
    '按章节名筛选，边输边过滤，只匹配标题、不搜正文。清空输入框恢复完整目录。': '章名で絞り込み。入力しながらフィルターし、タイトルのみを照合して本文は検索しません。入力欄を空にすると完全な目次に戻ります。',
    '搜索': '検索',
    '搜索 · 展开态': '検索 · 展開状態',
    '操作栏收起后，屏幕底部留一枚半透明胶囊，按卷 / 章 / 节与全书百分比显示进度。它不挡正文，也不拦点击 —— 点它等于点正文。': '操作バーを収納すると、画面下部に半透明のカプセルが残り、巻 / 章 / 節と書籍全体の割合で進捗を表示します。本文を遮らず、タップも妨げません。タップは本文をタップするのと同じです。',
    '收起态胶囊': '収納状態のカプセル',
    '标准': '標準',
    '标注 · 展开态': '注釈 · 展開状態',
    '标注与笔记': '注釈とノート',
    '每章末尾有「上一章 · 本章完 · 下一章」接续条；在线书读到最后还能直接续到下一本。随时可在顶栏右上角的「指引」重看本引导。': '各章の末尾に「前の章 · 本章完了 · 次の章」の継続バーがあります。オンライン書籍は最後まで読むと次の本へ直接進めます。トップバー右上の「ガイド」でいつでもこの案内を見直せます。',
    '沉稳': '落ち着き',
    '目录 · 关闭': '目次 · 閉じる',
    '目录 · 搜索框': '目次 · 検索欄',
    '目录 · 章节列表': '目次 · 章一覧',
    '章末续读': '章末の続き読み',
    '第三个键列出全书所有书签、高亮与笔记，按章节顺序排，点一条跳回原文位置。': '3番目のキーは書籍全体のしおり、ハイライト、ノートを章順に一覧し、1つタップすると原文の位置に戻ります。',
    '第二个键打开全书搜索，跨全书所有章节搜正文关键词。首次搜索要现建索引，可能慢几秒，之后会快很多。': '2番目のキーは書籍全体の検索を開き、全章の本文からキーワードを探します。初回検索ではインデックスを作成するため数秒かかることがありますが、以降は速くなります。',
    '第五个键展开设置面板，分五组：底色、排版、翻页、朗读、阅读。改动即时生效并记住，下面逐个说。': '5番目のキーで設定パネルを開きます。背景色、組版、ページ送り、読み上げ、読書の5グループに分かれます。変更は即時反映され記憶されます。以下で順に説明します。',
    '讲述': 'ナレーション',
    '设置': '設定',
    '设置面板最底部的「重新观看」，点一下回到当前这个引导。': '設定パネル最下部の「もう一度見る」をタップすると、このガイドに戻ります。',
    '读数': '表示値',
    '轻快': '軽快',
    '输入关键词后回车开始搜。结果按章节列出、命中词高亮，顶部显示命中总处数与涉及章数；点一条直接跳到那一段。': 'キーワードを入力して Enter で検索開始。結果は章ごとに一覧され、一致語はハイライトされます。上部に一致箇所の総数と該当章数が表示され、1つタップすると該当箇所へ直接ジャンプします。',
    '这一行是「给第 N 章加书签」，点一下把当前章节位置记下来。同一章只会有一个书签，重复加会提示已存在。': 'この行は「第 N 章にしおりを追加」です。タップすると現在の章の位置を記録します。同じ章にはしおりは1つだけで、重複して追加すると既存の提示が出ます。',
    '进度条': 'プログレスバー',
    '连续滚动上下滑；单栏分页一屏一页；双栏分页一屏两栏。方向（从左往右 / 从右往左）只在分页模式生效；点按翻页打开后，左右区域点一下即翻页。': '連続スクロールは上下にスワイプ、1カラム改ページは1画面1ページ、2カラム改ページは1画面2カラムです。方向（左から右へ / 右から左へ）は改ページモードでのみ有効です。タップでページ送りを有効にすると、左右の領域をタップするだけでページが送られます。',
    '选中与标注': '選択と注釈',
    '重看指引': 'ガイドを見直す',
    '长按正文选中文字，浮出四色高亮、下划线、写笔记、复制、朗读这段。选中期间点左右两侧不会误翻页，轻点空白处先取消选中。': '本文を長押しして文字を選択すると、4色のハイライト、下線、ノート作成、コピー、この部分の読み上げが表示されます。選択中は左右をタップしても誤ってページは送られず、空白を軽くタップすると選択が解除されます。',
    '顶栏': 'トップバー',
    '高': '高',
  };

  var LANG_TAG = (function () {
    var m = /[?&]lang=([^&]+)/.exec(window.location.search || '');
    var v = m ? decodeURIComponent(m[1]) : 'zh';
    if (v === 'en-US' || v === 'en') return 'en';
    if (v === 'ja-JP' || v === 'ja') return 'ja';
    return 'zh';
  })();
  var JA = LANG_TAG === 'ja';
  var EN = LANG_TAG === 'en';

  window.LantaiI18n = {
    t: function (key) {
      if (JA) return DICT_JA[key] || key;
      if (EN) return DICT_EN[key] || key;
      return key;
    },
    lang: function () { return JA ? 'ja-JP' : (EN ? 'en-US' : 'zh-Hans'); },
    langs: function () {
      return [
        { code: 'zh-Hans', name: '\u7b80\u4f53\u4e2d\u6587' },
        { code: 'en-US', name: 'English' },
        { code: 'ja-JP', name: '\u65e5\u672c\u8a9e' }
      ];
    },
    name: function (code) {
      if (code === 'en-US') return 'English';
      if (code === 'ja-JP') return '\u65e5\u672c\u8a9e';
      return '\u7b80\u4f53\u4e2d\u6587';
    },
    set: function () {}
  };

  var L = window.LantaiI18n;
  var stats = { get: 0, post: 0, fail: 0 };
  var timings = {};

  function httpGet(path, opts) {
    var init = { credentials: 'same-origin', headers: Object.assign({}, (opts && opts.headers) || {}) };
    if (opts && opts.signal) {
      init.signal = opts.signal;
    }
    return fetch(path, init).then(function (res) {
      if (!res.ok) {
        return res.text().catch(function () { return ''; }).then(function (text) {
          var err = new Error(text || ('HTTP ' + res.status));
          err.status = res.status;
          throw err;
        });
      }
      var type = res.headers.get('content-type') || '';
      if (type.indexOf('application/json') >= 0) {
        return res.json();
      }
      return res.text();
    });
  }

  window.LantaiRuntime = {
    request: function (path, opts) {
      var method = String((opts && opts.method) || 'GET').toUpperCase();
      if (method === 'GET') {
        stats.get += 1;
        return httpGet(path, opts).catch(function (err) {
          stats.fail += 1;
          throw err;
        });
      }
      stats.post += 1;
      try {
        if (window.lantaiBridge && window.lantaiBridge.post) {
          window.lantaiBridge.post(method, path, JSON.stringify((opts && opts.body) || null));
        }
      } catch (bridgeError) {
      }
      return Promise.resolve({ ok: true });
    }
  };

  var BOOK = null;

  window.book = function (id) {
    return BOOK && BOOK.id === id ? BOOK : null;
  };
  window.series = function () {
    return { t: (BOOK && BOOK.seriesTitle) || '' };
  };
  window.clamp = function (v, a, b) {
    return Math.max(a, Math.min(b, v));
  };
  window.esc = function (s) {
    return String(s == null ? '' : s).replace(/[&<>"]/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c];
    });
  };
  window.num = function (n) {
    return Number(n || 0).toLocaleString(JA ? 'ja-JP' : (EN ? 'en-US' : 'zh-CN'));
  };
  window.ago = function (t) {
    var d = Date.now() - t;
    if (d < 0) return window.LantaiI18n.t('刚刚');
    if (d < 36e5) return Math.max(1, Math.round(d / 6e4)) + window.LantaiI18n.t(' 分钟前');
    if (d < 864e5) return Math.round(d / 36e5) + window.LantaiI18n.t(' 小时前');
    return Math.round(d / 864e5) + window.LantaiI18n.t(' 天前');
  };
  window.dur = function (ms) {
    var s = Math.floor(ms / 1000), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60);
    if (h) return h + window.LantaiI18n.t(' 时 ') + m + window.LantaiI18n.t(' 分');
    if (m) return m + window.LantaiI18n.t(' 分 ') + (s % 60) + window.LantaiI18n.t(' 秒');
    return s + window.LantaiI18n.t(' 秒');
  };
  window.hexA = function (hex, alpha) {
    var h = String(hex || '').replace('#', '');
    if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
    var n = parseInt(h, 16);
    if (isNaN(n)) return 'rgba(201,162,75,' + alpha + ')';
    return 'rgba(' + ((n >> 16) & 255) + ',' + ((n >> 8) & 255) + ',' + (n & 255) + ',' + alpha + ')';
  };

  function secRoot() {
    var view = document.getElementById('ebView');
    return view && view.shadowRoot ? view.shadowRoot.getElementById('ebDoc') : null;
  }

  function hasChapter(n) {
    var root = secRoot();
    if (!root) {
      return false;
    }
    var node = root.querySelector('[data-ch="' + n + '"]');
    return !!node && node.childElementCount > 0;
  }

  function probeLocalStorage() {
    try {
      localStorage.setItem('lantai.probe', '1');
      var value = localStorage.getItem('lantai.probe');
      localStorage.removeItem('lantai.probe');
      return value === '1';
    } catch (error) {
      return false;
    }
  }

  function report(extra) {
    var payload = {
      href: location.href,
      origin: location.origin,
      storage: probeLocalStorage(),
      wakeLock: !!(navigator.wakeLock && navigator.wakeLock.request),
      cssHighlights: !!(window.CSS && CSS.highlights),
      shadow: !!(window.ShadowRoot),
      stats: stats,
      at: Date.now()
    };
    Object.assign(payload, extra || {});
    var text = JSON.stringify(payload);
    try {
      if (window.lantaiBridge && window.lantaiBridge.report) {
        window.lantaiBridge.report(text);
      }
    } catch (bridgeError) {
    }
  }

  function fail(title, detail) {
    var host = document.getElementById('lantaiFail');
    if (!host) {
      host = document.createElement('div');
      host.id = 'lantaiFail';
      document.body.appendChild(host);
    }
    var dark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
    host.setAttribute('style', 'position:fixed;inset:0;z-index:99;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;padding:36px;box-sizing:border-box;text-align:center;font-family:-apple-system,"HarmonyOS Sans SC",sans-serif;background:' + (dark ? '#141414' : '#fbf9f3') + ';color:' + (dark ? '#e8e6e1' : '#1f1e1a') + ';');
    host.innerHTML =
      '<div style="font-size:15px;font-weight:600">' + esc(title) + '</div>' +
      '<div style="font-size:12px;line-height:1.7;opacity:.62;max-width:340px;word-break:break-all">' + esc(detail || '') + '</div>' +
      '<button type="button" id="lantaiFailRetry" style="margin-top:10px;padding:9px 26px;border-radius:99px;border:1px solid rgba(128,128,128,.4);background:transparent;color:inherit;font-size:13px">' + esc(L.t('重试')) + '</button>';
    var retry = document.getElementById('lantaiFailRetry');
    if (retry) {
      retry.addEventListener('click', function () { location.reload(); });
    }
  }

  function boot() {
    var params = new URLSearchParams(location.search);
    var bookId = params.get('book');
    if (!bookId) {
      report({ fatal: 'no-book-param' });
      fail(L.t('没有可打开的书'), '');
      return;
    }
    var chapter = params.get('chapter') ? parseInt(params.get('chapter'), 10) : 0;
    if (!(chapter > 0)) chapter = 0;
    var began = performance.now();
    httpGet('api/lantai/v1/read/' + bookId + '/bootstrap?images=inline&w=0&window=3')
      .then(function (dto) {
        timings.bootstrapMs = Math.round(performance.now() - began);
        BOOK = {
          id: bookId,
          name: (dto.book && dto.book.title) || '',
          seriesTitle: (dto.book && dto.book.seriesTitle) || '',
          chs: dto.total || 0,
          pages: 0,
          profile: (dto.book && dto.book.profile) || 'EPUB',
          s: (dto.book && dto.book.seriesTitle) || '',
          status: 'READY'
        };
        var opened = performance.now();
        if (!window.EbookReader) {
          report({ fatal: 'reader-missing' });
          fail(L.t('打不开这本书'), 'reader-missing');
          return;
        }
        window.EbookReader.open(bookId, { boot: dto, chapter: chapter });
        var deadline = performance.now() + 10000;
        var tick = function () {
          var current = window.EbookReader.current();
          if (current.bootDone) {
            report({
              openMs: Math.round(performance.now() - opened),
              chapter: current.chapter,
              total: current.total,
              rendered: (function () {
                var root = secRoot();
                return root ? root.childElementCount : 0;
              })()
            });
            return;
          }
          if (performance.now() > deadline) {
            report({ fatal: 'open-timeout', on: true, bootstrapMs: timings.bootstrapMs });
            fail(L.t('打不开这本书'), L.t('内容渲染超时'));
            return;
          }
          requestAnimationFrame(tick);
        };
        requestAnimationFrame(tick);
      })
      .catch(function (error) {
        report({ fatal: 'bootstrap-failed', message: String((error && error.message) || error) });
        fail(L.t('连不上兰台'), String((error && error.message) || error || ''));
      });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
