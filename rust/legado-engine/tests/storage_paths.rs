use legado_engine::EngineContext;

#[test]
fn memory_directories_share_with_clones_and_release_with_the_last_storage_capability() {
    let first = EngineContext::in_memory().unwrap();
    let second = EngineContext::in_memory().unwrap();
    let storage = first.storage().clone();
    let path = storage.data_directory("ruleData").unwrap();
    assert_eq!(path, first.storage().data_directory("ruleData").unwrap());
    assert_ne!(path, second.storage().data_directory("ruleData").unwrap());
    std::fs::create_dir_all(&path).unwrap();
    std::fs::write(path.join("owned"), "内容").unwrap();
    drop(first);
    assert!(path.exists());
    drop(storage);
    assert!(!path.exists());
}

#[test]
fn data_directory_rejects_absolute_parent_and_multi_component_names() {
    let engine = EngineContext::in_memory().unwrap();
    for name in ["", ".", "..", "../outside", "one/two", "/absolute"] {
        assert!(
            engine.storage().data_directory(name).is_err(),
            "应拒绝 {name}"
        );
    }
}
