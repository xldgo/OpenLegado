//! 期望值来自原始 Kotlin，不从 Rust 实现回填。
use base64::{Engine, engine::general_purpose::STANDARD};
use legado_layout::{
    line_breaker::{BreakInput, break_lines},
    model::{Block, Config},
    paginator::{PaginationSession, paginate},
};
use serde_json::{Value, json};

fn fixture() -> Value {
    let decoder = flate2::read::GzDecoder::new(&include_bytes!("fixtures/md3.json.gz")[..]);
    serde_json::from_reader(decoder).unwrap()
}
fn compare(actual: &Value, expected: &Value, path: &str) {
    match (actual, expected) {
        (Value::Number(a), Value::Number(b)) => {
            if a.is_i64() && b.is_i64() {
                assert_eq!(a, b, "{path}");
            } else {
                let a = a.as_f64().unwrap();
                let b = b.as_f64().unwrap();
                // 上游 Float 的十进制序列化与 Value 中 f32 转 f64 的舍入差别。
                let tolerance = 0.0001f64.max(b.abs() * 2.0 * f32::EPSILON as f64);
                assert!(
                    (a - b).abs() <= tolerance,
                    "{path}: {a} != {b}, 误差上限 {tolerance}"
                );
            }
        }
        (Value::Array(a), Value::Array(b)) => {
            assert_eq!(a.len(), b.len(), "{path} 数量");
            for (i, (a, b)) in a.iter().zip(b).enumerate() {
                compare(a, b, &format!("{path}[{i}]"));
            }
        }
        (Value::Object(a), Value::Object(b)) => {
            assert_eq!(
                a.keys().collect::<Vec<_>>(),
                b.keys().collect::<Vec<_>>(),
                "{path} 字段"
            );
            for (k, a) in a {
                compare(a, &b[k], &format!("{path}.{k}"));
            }
        }
        _ => assert_eq!(actual, expected, "{path}"),
    }
}
#[test]
fn original_kotlin_line_breaks_match_all_cases() {
    let f = fixture();
    assert_eq!(f["upstreamRevision"], legado_layout::UPSTREAM_REVISION);
    for case in f["cases"]
        .as_array()
        .unwrap()
        .iter()
        .filter(|c| c["kind"] == "break")
    {
        let input: BreakInput = serde_json::from_value(case["input"].clone()).unwrap();
        let actual = serde_json::to_value(break_lines(&input).unwrap()).unwrap();
        compare(&actual, &case["expected"], case["name"].as_str().unwrap());
    }
}
#[test]
fn original_kotlin_pagination_and_all_inline_types_match() {
    for case in fixture()["cases"]
        .as_array()
        .unwrap()
        .iter()
        .filter(|c| c["kind"] == "pages")
    {
        let config: Config = serde_json::from_value(case["input"]["config"].clone()).unwrap();
        let blocks: Vec<Block> = serde_json::from_value(case["input"]["blocks"].clone()).unwrap();
        let actual = serde_json::to_value(paginate(blocks, config).unwrap()).unwrap();
        compare(&actual, &case["expected"], case["name"].as_str().unwrap());
    }
}

fn unpack_wire(pages: Vec<legado_layout::model::Page>) -> Value {
    let packed = serde_json::to_value(legado_layout::wire::pack_pages(pages)).unwrap();
    assert!(packed.get("elementEncoding").is_none());
    let geometry = STANDARD
        .decode(packed["glyphs"]["geometry"].as_str().unwrap())
        .unwrap();
    let positions = STANDARD
        .decode(packed["glyphs"]["positions"].as_str().unwrap())
        .unwrap();
    let text: Vec<u16> = packed["glyphs"]["text"]
        .as_str()
        .unwrap()
        .encode_utf16()
        .collect();
    let number =
        |index: usize| f32::from_le_bytes(geometry[index * 4..index * 4 + 4].try_into().unwrap());
    let position = |index: usize| {
        u32::from_le_bytes(positions[index * 4..index * 4 + 4].try_into().unwrap()) as usize
    };
    let mut pages = packed["pages"].clone();
    for page in pages.as_array_mut().unwrap() {
        for element in page["elements"].as_array_mut().unwrap() {
            if !element.is_u64() {
                continue;
            }
            let index = element.as_u64().unwrap() as usize;
            let start = if index == 0 {
                0
            } else {
                position((index - 1) * 4 + 3)
            };
            let value = String::from_utf16(&text[start..position(index * 4 + 3)]).unwrap();
            let mut full = json!({
                "type":"text", "bounds":{"left":number(index*5),"top":number(index*5+1),"right":number(index*5+2),"bottom":number(index*5+3)},
                "baselinePx":number(index*5+4),"value":value,"chapterPosition":position(index*4),"paragraphIndex":position(index*4+1),
                "style":packed["textStyles"][position(index*4+2)],
                "selected":false,"emphasized":false,"readAloud":false,"searchResult":false,
                "continuesBackgroundRun":false,"link":null,"markingId":null,"emphasisUnderline":null,
                "backgroundFrameTopPx":0.0,"backgroundFrameBottomPx":0.0,
                "backgroundFrameLeftPx":0.0,"backgroundFrameRightPx":0.0,
            });
            if let Some(extras) = packed["glyphs"]["extras"][index.to_string()].as_object() {
                full.as_object_mut().unwrap().extend(extras.clone());
            }
            *element = full;
        }
    }
    pages
}

#[test]
fn compact_wire_keeps_all_upstream_elements_styles_and_geometry() {
    for case in fixture()["cases"]
        .as_array()
        .unwrap()
        .iter()
        .filter(|c| c["kind"] == "pages")
    {
        let config: Config = serde_json::from_value(case["input"]["config"].clone()).unwrap();
        let blocks: Vec<Block> = serde_json::from_value(case["input"]["blocks"].clone()).unwrap();
        let round_trip: Vec<legado_layout::model::Page> =
            serde_json::from_value(case["expected"].clone()).unwrap();
        compare(
            &serde_json::to_value(round_trip).unwrap(),
            &case["expected"],
            "页面模型往返",
        );
        compare(
            &unpack_wire(paginate(blocks, config).unwrap()),
            &case["expected"],
            case["name"].as_str().unwrap(),
        );
    }
}

#[test]
fn compact_wire_keeps_runtime_flags_and_nondefault_fields() {
    let f = fixture();
    let input = &f["cases"]
        .as_array()
        .unwrap()
        .iter()
        .find(|c| c["kind"] == "pages")
        .unwrap()["input"];
    let config: Config = serde_json::from_value(input["config"].clone()).unwrap();
    let blocks: Vec<Block> = serde_json::from_value(input["blocks"].clone()).unwrap();
    let mut pages = paginate(blocks, config).unwrap();
    let glyph = pages
        .iter_mut()
        .flat_map(|p| p.elements.iter_mut())
        .find_map(|e| e.text.as_mut())
        .unwrap();
    glyph.selected = true;
    glyph.read_aloud = true;
    glyph.search_result = true;
    glyph.continues_background_run = true;
    glyph.link = Some("https://example.test/段落".into());
    glyph.marking_id = Some("标记".into());
    glyph.emphasis_underline = Some(json!({"colorArgb":-1}));
    glyph.background_frame_top_px = 1.25;
    glyph.background_frame_right_px = -2.5;
    let expected = serde_json::to_value(&pages).unwrap();
    compare(&unpack_wire(pages), &expected, "运行时字形字段");
}
#[test]
fn incremental_sessions_keep_batch_boundaries_and_text() {
    for case in fixture()["cases"]
        .as_array()
        .unwrap()
        .iter()
        .filter(|c| c["kind"] == "pages")
    {
        let config: Config = serde_json::from_value(case["input"]["config"].clone()).unwrap();
        let blocks: Vec<Block> = serde_json::from_value(case["input"]["blocks"].clone()).unwrap();
        let mut session = PaginationSession::new(config).unwrap();
        let mut pages = vec![];
        for block in blocks {
            pages.extend(session.accept(block).unwrap());
        }
        pages.extend(session.finish().unwrap());
        compare(
            &serde_json::to_value(pages).unwrap(),
            &case["expected"],
            case["name"].as_str().unwrap(),
        );
        assert!(session.finish().is_err());
    }
}
#[test]
fn invalid_geometry_and_cluster_contract_are_rejected() {
    let f = fixture();
    let input = &f["cases"]
        .as_array()
        .unwrap()
        .iter()
        .find(|c| c["kind"] == "pages")
        .unwrap()["input"];
    let mut config: Config = serde_json::from_value(input["config"].clone()).unwrap();
    config.column_count = 0;
    assert!(PaginationSession::new(config.clone()).is_err());
    config.column_count = 3;
    assert!(PaginationSession::new(config.clone()).is_err());
    config.column_count = 1;
    config.line_height_px = 0.0;
    assert!(PaginationSession::new(config).is_err());
    let mut nan: Config = serde_json::from_value(input["config"].clone()).unwrap();
    nan.letter_spacing_px = f32::NAN;
    assert!(PaginationSession::new(nan).is_err());
    let mut p = input["blocks"][0].clone();
    p["value"]["text"] = json!("错误正文");
    let c: Config = serde_json::from_value(input["config"].clone()).unwrap();
    assert!(paginate(vec![serde_json::from_value(p).unwrap()], c).is_err());
    let mut b: BreakInput = serde_json::from_value(f["cases"][1]["input"].clone()).unwrap();
    b.widths_px.clear();
    assert!(break_lines(&b).is_err());
    let mut unknown = input["config"].clone();
    unknown["unexpected"] = json!(1);
    assert!(serde_json::from_value::<Config>(unknown).is_err());
}

#[test]
fn review_extension_stays_with_legal_text_tail_and_has_no_source_length() {
    let config:Config=serde_json::from_value(json!({"chapterIndex":0,"chapterTitle":"测试","viewportWidthPx":64,"viewportHeightPx":55,"paddingLeftPx":0,"paddingTopPx":0,"paddingRightPx":0,"paddingBottomPx":0,"lineHeightPx":20,"baselineOffsetPx":15})).unwrap();
    let items:Vec<Value>="甲乙丙丁戊己庚。".chars().enumerate().map(|(i,c)|json!({"type":"text","value":c.to_string(),"widthPx":16,"style":{"colorArgb":-1,"fontSizePx":16},"chapterPosition":i})).chain(std::iter::once(json!({"type":"review","widthPx":40,"heightPx":24,"chapterPosition":8,"paragraphIndex":1,"reviewKey":"段评","count":123,"baselineOffsetPx":18,"compactWidthPx":18,"compactHeightPx":18}))).collect();
    let block:Block=serde_json::from_value(json!({"type":"inlineParagraph","items":items,"indentCharacters":0,"alignment":"justify","lineHeightPx":20,"baselineOffsetPx":15,"baseTextSizePx":16})).unwrap();
    let pages = paginate(vec![block.clone()], config.clone()).unwrap();
    let text = pages.iter().map(|p| p.text.as_str()).collect::<String>();
    assert_eq!(text, "甲乙丙丁戊己庚。");
    let last = pages.last().unwrap();
    let review = last.elements.iter().find(|e| e.kind == "review").unwrap();
    let tail: Vec<_> = last
        .elements
        .iter()
        .filter(|e| {
            e.kind == "text"
                && e.bounds.top
                    == last
                        .elements
                        .iter()
                        .rfind(|e| e.kind == "text")
                        .unwrap()
                        .bounds
                        .top
        })
        .collect();
    assert_eq!(
        tail.iter()
            .map(|e| e.text.as_ref().unwrap().value.as_str())
            .collect::<String>(),
        "庚。"
    );
    assert_eq!(
        review.data["baselinePx"],
        json!(tail.last().unwrap().text.as_ref().unwrap().baseline_px)
    );
    assert_eq!(review.bounds.right - review.bounds.left, 18.0);
    let mut narrow = config;
    narrow.viewport_width_px = 20;
    assert!(paginate(vec![block], narrow).is_err());
}

#[test]
fn external_cancellation_stops_an_existing_session() {
    use std::sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    };
    let f = fixture();
    let v = &f["cases"]
        .as_array()
        .unwrap()
        .iter()
        .find(|v| v["kind"] == "pages")
        .unwrap()["input"];
    let mut session =
        PaginationSession::new(serde_json::from_value(v["config"].clone()).unwrap()).unwrap();
    let token = Arc::new(AtomicBool::new(false));
    session.set_cancellation(token.clone());
    session
        .accept(serde_json::from_value(v["blocks"][0].clone()).unwrap())
        .unwrap();
    token.store(true, Ordering::Release);
    assert!(
        session
            .accept(serde_json::from_value(v["blocks"][1].clone()).unwrap())
            .is_err()
    );
    assert!(session.finish().is_err());
}
