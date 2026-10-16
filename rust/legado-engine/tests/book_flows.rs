//! 真实详情→目录→正文链，交错来源/书籍和深链不借用其他流程变量。
#![cfg(feature = "quickjs")]
use legado_engine::EngineContext;
use legado_fetcher::{deps::FetcherDeps, web_book};
use serde_json::{Value, json};

fn deps(engine: &EngineContext) -> FetcherDeps {
    FetcherDeps::new(engine.network().client().unwrap())
        .with_web_book_state(engine.web_book_state().clone())
        .with_js_resources(engine.js_resources().clone())
        .with_rate_limiter(engine.rate_limiter().clone())
}

#[test]
fn http_rules_keep_book_flow_across_interleaving_sources_and_deep_links() {
    use std::{
        io::{Read, Write},
        time::{Duration, Instant},
    };
    let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
    listener.set_nonblocking(true).unwrap();
    let base = format!("http://{}", listener.local_addr().unwrap());
    let server_base = base.clone();
    let fixture = std::thread::spawn(move || {
        let deadline = Instant::now() + Duration::from_secs(20);
        for _ in 0..17 {
            let (mut socket, _) = loop {
                match listener.accept() {
                    Ok(value) => break value,
                    Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                        assert!(Instant::now() < deadline, "阅读链请求未到达夹具");
                        std::thread::sleep(Duration::from_millis(5));
                    }
                    Err(error) => panic!("夹具失败: {error}"),
                }
            };
            socket.set_nonblocking(false).unwrap();
            socket
                .set_read_timeout(Some(Duration::from_secs(3)))
                .unwrap();
            let mut bytes = Vec::new();
            let mut chunk = [0; 1024];
            while !bytes.windows(4).any(|b| b == b"\r\n\r\n") {
                let n = socket.read(&mut chunk).unwrap();
                assert!(n > 0);
                bytes.extend_from_slice(&chunk[..n]);
            }
            let request = String::from_utf8(bytes).unwrap();
            let path = request.split_whitespace().nth(1).unwrap();
            let name = path.rsplit('/').next().unwrap();
            let body = if path.starts_with("/info/") {
                json!({"name":name,"toc":format!("{server_base}/toc/{name}")}).to_string()
            } else if path.starts_with("/toc/") {
                json!([{"url":format!("{server_base}/content/{name}")}]).to_string()
            } else {
                "正文".to_string()
            };
            write!(socket,"HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",body.len()).unwrap();
        }
    });
    let engine = EngineContext::in_memory().unwrap();
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .unwrap();
    runtime.block_on(async {
        let source=|tag:&str|json!({
            "bookSourceUrl":format!("https://flow-{tag}.test"),
            "ruleBookInfo":{
                "name":format!("@js:var n=JSON.parse(src).name;java.put('flow','{tag}-'+n);if(book.putVariable)book.putVariable('mark','{tag}-'+n);n"),
                "tocUrl":"$.toc"
            },
            "ruleToc":{"chapterList":"$[*]","chapterName":"@js:java.get('flow')+'|'+java.get('mark')","chapterUrl":"$.url"},
            "ruleContent":{"content":"@js:java.get('flow')+'|'+java.get('mark')+'|'+book.name"}
        }).to_string();
        let a=source("A");let b=source("B");
        let one=format!("{base}/info/one");let two=format!("{base}/info/two");
        for (source,url) in [(&a,&one),(&a,&two),(&b,&one)] {
            for _ in 0..2 { web_book::webbook_info(deps(&engine),source,url).await.unwrap(); }
        }
        let mut chapters=Vec::new();
        for (source,url,name,expected) in [(&a,&one,"one","A-one|A-one"),(&a,&two,"two","A-two|A-two"),(&b,&one,"one","B-one|B-one")] {
            let toc=format!("{base}/toc/{name}");
            let raw=web_book::webbook_chapters(deps(&engine),source,url,&toc,"").await.unwrap();
            let list:Vec<Value>=serde_json::from_str(&raw).unwrap();
            assert_eq!(list[0]["title"],expected);
            chapters.push(list[0].to_string());
        }
        for ((source,chapter),expected) in [(&a,&chapters[0]),(&a,&chapters[1]),(&b,&chapters[2])].into_iter().zip(["A-one|A-one|one","A-two|A-two|two","B-one|B-one|one"]) {
            assert_eq!(web_book::webbook_content(deps(&engine),source,chapter).await.unwrap(),expected);
        }
        let deep=json!({"url":format!("{base}/deep"),"title":"深链","index":0,"is_vip":false,"is_volume":false}).to_string();
        assert_eq!(web_book::webbook_content(deps(&engine),&a,&deep).await.unwrap(),"||");
        assert_eq!(web_book::webbook_content(deps(&engine),&a,&chapters[0]).await.unwrap(),"A-one|A-one|one");
        // 已换源书的稳定主键与详情取址点不同，不以请求URL覆盖显式书籍能力。
        use legado_core::web_book::BookSourceFetcher;
        let stable="https://old-origin.test/stable-key";
        let mut source:legado_core::models::BookSource=serde_json::from_str(&a).unwrap();
        source.rule_toc.as_mut().unwrap().chapter_name=Some("@js:java.get('scopeTest')".into());
        source.rule_content.as_mut().unwrap().content=Some("@js:java.get('scopeTest')+'|'+java.get('mark')+'|'+book.bookUrl".into());
        let scoped=deps(&engine).for_book(&source.book_source_url,stable);
        scoped.js.variable_scope().unwrap().put_flow_variable("scopeTest","stable-only").unwrap();
        web_book::record_book_meta_from_info(&scoped,&source.book_source_url,stable,
            &legado_core::web_book::WebBookInfo::new("原书名","作者",stable,format!("{base}/toc/one")));
        let fetcher=web_book::RealBookSourceFetcher::with_deps(scoped.clone());
        let info=fetcher.get_book_info(&source,&one).await.unwrap();
        assert_eq!(info.book_url,one);
        assert_eq!(scoped.js.variable_scope().unwrap().get_book_variable(stable,"mark").unwrap().as_deref(),Some("A-one"));
        let chapters=fetcher.get_chapters_with_book_key_and_vars(&source,&one,stable,Some(&format!("{base}/toc/one")),None,&Default::default()).await.unwrap();
        assert_eq!(chapters[0].title,"stable-only");
        assert_eq!(fetcher.get_content(&source,&chapters[0]).await.unwrap(),format!("stable-only|A-one|{stable}"));

    });
    fixture.join().unwrap();
}

#[test]
fn main_js_continuity_uses_explicit_book_scope_and_independent_engines() {
    let one = EngineContext::in_memory().unwrap();
    let two = EngineContext::in_memory().unwrap();
    let source=json!({"bookSourceUrl":"https://main-flow.test", "mainJs":r#"
        function object(v){return typeof v==='string'?JSON.parse(v):v;}
        function getBookInfo(book){book=object(book);java.__lgStorePut('flow',book.bookUrl);java.__lgBookVarSet(book.bookUrl,'mark',book.bookUrl);return {name:book.bookUrl};}
        function getChapters(book){book=object(book);return [{title:java.__lgStoreGet('flow'),url:book.bookUrl+'/chapter'}];}
        function getContent(chapter,book){book=object(book);return java.__lgStoreGet('flow')+'|'+java.__lgBookVarGet(book.bookUrl,'mark');}
    "#}).to_string();
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .unwrap();
    runtime.block_on(async {
        for book in ["https://book.test/a", "https://book.test/b"] {
            web_book::webbook_info(deps(&one), &source, book)
                .await
                .unwrap();
        }
        let mut chapters = Vec::new();
        for book in ["https://book.test/a", "https://book.test/b"] {
            let raw = web_book::webbook_chapters(deps(&one), &source, book, "", "")
                .await
                .unwrap();
            let list: Vec<Value> = serde_json::from_str(&raw).unwrap();
            assert_eq!(list[0]["title"], book);
            chapters.push(list[0].to_string());
        }
        for (index, book) in ["https://book.test/a", "https://book.test/b"]
            .into_iter()
            .enumerate()
        {
            assert_eq!(
                web_book::webbook_content(deps(&one), &source, &chapters[index])
                    .await
                    .unwrap(),
                format!("{book}|{book}")
            );
            assert_eq!(
                web_book::webbook_content(deps(&two), &source, &chapters[index])
                    .await
                    .unwrap(),
                "|"
            );
        }
    });
}
