"""用固定上游原始 Kotlin 生成 Rust 差分夹具；不改写参考算法。"""
from __future__ import annotations

import argparse
import hashlib
import gzip
import json
import os
from pathlib import Path
import random
import subprocess
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
REVISION = "070ca1a9b2e491654f70c105bca9939968023940"
CORE = "app/src/main/java/io/legado/app/feature/reader/core/"
FILES = ["layout/ChineseLineBreaker.kt", "layout/ReaderPaginator.kt", "model/ReaderPage.kt",
         "model/ReaderBookmarkBadge.kt", "model/ReaderEmphasisUnderlineRun.kt", "model/ReaderUnderlineRun.kt",
         "style/ReaderCharacterStyle.kt", "layout/ReaderChapterBlockMeasurer.kt"]


def cases() -> list[dict]:
    rng = random.Random(20261012)
    out = []
    words = [list("中文测试标点，“你好！”世界。"), list("abc don't café 123 test-word"),
             ["甲", "😀", "乙", "e\u0301", "𠀀", "👨‍👩‍👧‍👦", "。", "”"],
             list('"英文引号"（“连续”）;:！'), ["", "a", "", "中", " ", "’", "١", "𝟛"]]
    for i in range(180):
        clusters = [rng.choice(words[i % len(words)]) for _ in range(rng.randint(0, 50))]
        spacing = rng.choice([0, 0.3, 1.25, -0.25])
        width = rng.choice([1, 17, 32, 67, 120])
        value = dict(clusters=clusters, widthsPx=[rng.choice([0, 3.25, 8, 16, 16.3]) + spacing for _ in clusters],
                     indentCharacters=0, widthPx=width, ideographWidthPx=16+spacing,
                     letterSpacingPx=spacing, firstLineWidthPx=max(0, width-rng.choice([0, 16, 32])))
        out.append(dict(name=f"break-{i:03}", kind="break", input=value))
    style = dict(colorArgb=-16777216, fontSizePx=16)

    def paragraph(text, position=0, **extra):
        return dict(type="paragraph", value=dict(text=text, clusters=list(text),
                    clusterWidthsPx=[8 if ch.isascii() else 16 for ch in text], style=style,
                    chapterPosition=position, **extra))

    def inline(i):
        items = []
        pos = 12
        for j in range(rng.randint(4, 25)):
            t = rng.choice(["text", "text", "text", "image", "roleCast", "bgmScene"])
            if t == "text":
                s = dict(style, fontSizePx=rng.choice([12, 16, 24]), matchSpacingBeforePx=rng.choice([0, 2]),
                         matchSpacingAfterPx=rng.choice([0, 1.5]), linePadTopPx=rng.choice([0, 2]), linePadBottomPx=rng.choice([0, 3]))
                if j % 5 == 0:
                    s["backgroundImage"] = dict(source="bubble.9.png", fit=3, scale=1.2,
                                               contentInsetLeftPx=2, contentInsetRightPx=3,
                                               contentInsetTopPx=4, contentInsetBottomPx=5, contentBandHeightPx=10)
                value = rng.choice(["甲", "e\u0301", "😀", " ", "a", "。", "“", "”"])
                items.append(dict(type=t, value=value, widthPx=rng.choice([8,16,23.5]), style=s,
                                  chapterPosition=pos, baselineShiftPx=rng.choice([0,-3,4]),
                                  lineHeightPx=rng.choice([18,24,32]), baselineOffsetPx=rng.choice([14,18,24])))
                pos += len(value.encode("utf-16-le")) // 2
            elif t == "image":
                items.append(dict(type=t, source="image", widthPx=17, heightPx=rng.choice([20,38]),
                                  chapterPosition=pos, lineFinalWidthPx=8))
                pos += 1
            elif t == "roleCast":
                items.append(dict(type=t, widthPx=24, heightPx=19, chapterPosition=pos,
                                  raw="<<甲>>", name="甲", voicePoolLabel="角色", quoteOrdinal=j, voiceEffectMark=j%2==0))
                pos += 5
            else:
                items.append(dict(type=t, widthPx=20, heightPx=28, chapterPosition=pos,
                                  paragraphIndex=i, poolName="音乐", trackName="曲目"))
        return dict(type="inlineParagraph", items=items, indentCharacters=2, alignment=rng.choice(["start","center","end","justify"]),
                    lineHeightPx=24, baselineOffsetPx=18, baseTextSizePx=16,
                    lineSpacingMultiplier=rng.choice([1,1.25]), letterSpacingPx=0.3, restLineIndentWidthPx=4,
                    leadingIndentItems=1, justifyAtWordBoundaries=i%2==0,
                    decorations=[dict(kind="quote" if i%2 else "bullet", colorArgb=None, sizePx=2, leadingOffsetPx=1)])

    for i in range(80):
        config = dict(chapterIndex=2,chapterTitle="对照章节",viewportWidthPx=rng.choice([65,121,241]),
                      viewportHeightPx=rng.choice([52,87,140]),paddingLeftPx=3.25,paddingTopPx=4,
                      paddingRightPx=2.5,paddingBottomPx=5,lineHeightPx=24,baselineOffsetPx=18,
                      paragraphSpacingPx=7,letterSpacingPx=rng.choice([0,0.3,1.25]),columnCount=1+i%2,
                      lineSpacingMultiplier=1.2,continuousScroll=i%3==0,textBottomJustify=i%4==0,
                      chapterEndPaddingPx=20,htmlLineSpacingAddPx=2,titleTopSpacingPx=3,
                      titleBottomSpacingPx=5,titleParagraphSpacingPx=8,titleSegmentSpacingPx=2,
                      titlePageCenterVertical=i%7==0,singleImageStyle=i%8==0,
                      castOptions=dict(enabled=True,profiles={"甲":dict(characterId="角色1",avatarUri="avatar")}))
        if i%5==0:
            config["pageUnderline"]=dict(colorArgb=-1,widthPx=1,offsetPx=2,extendToColumn=i%10==0,dashed=True)
        blocks = [paragraph("标题",isTitle=True,alignment="center")]
        for j in range(4):
            if i%3==0: blocks.append(inline(i))
            else: blocks.append(paragraph("中文“段落！” English don't split 😀。"*rng.randint(1,3),30+j*150,
                                          indentCharacters=2,alignment=rng.choice(["start","justify","center","end"])))
            if j==1:
                blocks.extend([dict(type="blankLine",chapterPosition=50,lineHeightPx=10,lineSpacingMultiplier=1.1),
                               dict(type="rule",colorArgb=-1,widthPx=1.5,verticalPaddingPx=3,dashed=True)])
            if j==2:
                blocks.append(dict(type="image",source="image",intrinsicWidthPx=180,intrinsicHeightPx=300,
                                   chapterPosition=70,scaleMode=rng.choice(["fitWidth","fitPage","containNoUpscale"]),
                                   pageBreakBefore=i%2==0,pageBreakAfter=i%4==0))
        if i%6==0: blocks.insert(3,dict(type="pageBreak"))
        out.append(dict(name=f"pages-{i:03}",kind="pages",input=dict(config=config,blocks=blocks)))
    return out


def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--java-home",type=Path,required=True)
    parser.add_argument("--gradle-cache",type=Path,default=Path.home()/".gradle/caches/modules-2/files-2.1")
    parser.add_argument("--proxy")
    parser.add_argument("--output",type=Path,default=ROOT/"rust/legado-layout/tests/fixtures/md3.json.gz")
    args=parser.parse_args()
    scratch=ROOT/"flutter_legado/build/reader-layout-audit/md3/oracle"
    scratch.mkdir(parents=True,exist_ok=True)
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({"https":args.proxy} if args.proxy else {}))
    sources={}
    for relative in FILES:
        url=f"https://raw.githubusercontent.com/HapeLee/legado-with-MD3/{REVISION}/{CORE}{relative}"
        data=opener.open(url,timeout=40).read()
        path=scratch/Path(relative).name
        path.write_bytes(data)
        sources[relative]=hashlib.sha256(data).hexdigest()
    # 只取原测量模块的两份数据声明；该文件其余部分依赖协程、HTML 与平台测量，不进入 oracle。
    declaration=(scratch/"ReaderChapterBlockMeasurer.kt").read_text(encoding="utf-8")
    declaration=declaration[declaration.index("enum class ReaderParagraphDecorationKind"):declaration.index("data class ReaderImageDimensions")]
    (scratch/"Decoration.kt").write_text("package io.legado.app.feature.reader.core.layout\n"+declaration,encoding="utf-8")
    (scratch/"Stable.kt").write_text("package androidx.compose.runtime\nannotation class Stable\n",encoding="utf-8")
    required=["kotlin-compiler-embeddable-2.3.0.jar","kotlin-stdlib-2.3.0.jar","kotlin-reflect-1.6.10.jar",
              "trove4j-1.0.20200330.jar","annotations-13.0.jar","kotlinx-coroutines-core-jvm-1.9.0.jar","gson-2.12.0.jar"]
    jars=[]
    for name in required:
        matches=list(args.gradle_cache.rglob(name))
        if not matches: raise SystemExit(f"缺少参考编译器依赖：{name}；请指定已有 Gradle 缓存")
        jars.append(matches[0])
    classpath=os.pathsep.join(map(str,jars))
    java=args.java_home/"bin"/("java.exe" if os.name=="nt" else "java")
    kotlin=[scratch/Path(p).name for p in FILES if not p.endswith("ReaderChapterBlockMeasurer.kt")]
    kotlin.extend([scratch/"Stable.kt",scratch/"Decoration.kt",ROOT/"rust/legado-layout/tests/reference/Oracle.kt"])
    classes=scratch/"classes"
    subprocess.run([str(java),"-Dfile.encoding=UTF-8","-cp",classpath,"org.jetbrains.kotlin.cli.jvm.K2JVMCompiler",
                    "-no-stdlib","-no-reflect","-classpath",classpath,"-d",str(classes),*map(str,kotlin)],check=True)
    matrix=cases()
    input_path=scratch/"input.jsonl"
    input_path.write_text("\n".join(json.dumps(case,ensure_ascii=False) for case in matrix),encoding="utf-8")
    result=subprocess.run([str(java),"-Dfile.encoding=UTF-8","-cp",str(classes)+os.pathsep+classpath,
                           "io.legado.app.feature.reader.core.layout.OracleKt",str(input_path)],check=True,capture_output=True,encoding="utf-8")
    expected={row["name"]:row["expected"] for row in map(json.loads,result.stdout.splitlines())}
    if len(expected)!=len(matrix): raise SystemExit("Kotlin 未输出完整矩阵")
    for case in matrix: case["expected"]=expected[case["name"]]
    runtime=subprocess.run([str(java),"-version"],capture_output=True,text=True,check=True).stderr
    args.output.parent.mkdir(parents=True,exist_ok=True)
    data=(json.dumps(dict(upstreamRevision=REVISION,javaRuntime=runtime,
                         sourceSha256=sources,cases=matrix),ensure_ascii=False,separators=(",",":"))+"\n").encode("utf-8")
    args.output.write_bytes(gzip.compress(data,mtime=0))
    print(f"原始 Kotlin 生成 {len(matrix)} 组夹具：{args.output}")


if __name__=="__main__": main()
