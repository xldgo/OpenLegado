//! Flutter 布局测试宿主；执行同一 Rust 核心，不加载完整应用或另写参考算法。
use legado_layout::{
    model::{Block, Config},
    paginator::PaginationSession,
};
use serde::Deserialize;
use std::{fs, time::Instant};
#[derive(Deserialize)]
struct Input {
    config: Config,
    blocks: Vec<Block>,
    finish: bool,
}
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let path = std::env::args().nth(1).ok_or("缺少测试输入文件")?;
    let input: Input = serde_json::from_str(&fs::read_to_string(path)?)?;
    let start = Instant::now();
    let mut session = PaginationSession::new(input.config)?;
    let mut pages = vec![];
    for block in input.blocks {
        pages.extend(session.accept(block)?);
    }
    if input.finish {
        pages.extend(session.finish()?);
    }
    let mut reply = serde_json::to_value(legado_layout::wire::pack_pages(pages))?;
    reply["schemaVersion"] = 1.into();
    reply["sessionId"] = "test".into();
    reply["rustMicros"] = (start.elapsed().as_micros() as u64).into();
    println!("{}", reply);
    Ok(())
}
