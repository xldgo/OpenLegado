use super::*;

#[test]
fn highlight_rule_presets_match_upstream_samples() {
    let rules = presets().unwrap();
    let mut ids = std::collections::HashSet::new();
    for mut rule in rules.clone() {
        assert!(ids.insert(rule.uuid.clone()));
        let style = HighlightStyle::parse(&rule.style).unwrap();
        rule.isEnabled = true;
        let matched = match_text(
            &[rule.clone()],
            &style.sample_text,
            style.target_scope == 1,
            None,
        )
        .unwrap();
        assert!(!matched.is_empty(), "{}未命中自带样例", rule.name);
    }
    let mut emphasis = rules.into_iter().find(|r| r.name == "重点强调").unwrap();
    emphasis.isEnabled = true;
    assert!(
        match_text(&[emphasis], "他走进房间，轻轻关上门。", false, None)
            .unwrap()
            .is_empty()
    );
}

#[test]
fn highlight_rule_import_roundtrip_and_unicode_ranges() {
    let rules = parse_document(r#"[{"id":"portable-rule","name":"样式","pattern":"😀甲","targetScope":2,"bgColor":-256,"textColor":4278190080,"underlineMode":5,"underlineSvgPath":"M0 0 L10 2","fontWeight":700,"bgImage":"assets://paper.png","bgImageFit":3,"letterSpacingBefore":4,"sampleText":"前😀甲后"}]"#).unwrap();
    let copy = parse_document(&export_document(&rules).unwrap()).unwrap();
    assert_eq!(rules, copy);
    let matches = match_text(&copy, "前😀甲后", false, None).unwrap();
    assert_eq!((matches[0].start, matches[0].end), (1, 4));
    assert!(
        match_text(&copy, "前😀甲后", true, None)
            .unwrap()
            .is_empty()
    );
    assert!(parse_document(r#"[{"id":"x","pattern":"["}]"#).is_err());
}

#[test]
fn highlight_rule_priority_and_config_binding_share_one_execution_path() {
    let rules = parse_document(r#"[
      {"id":"wide","pattern":"甲乙丙","bgColor":-256,"letterSpacingBefore":4,"letterSpacingAfter":6},
      {"id":"inner","pattern":"乙","textColor":-65536,"position":1,"configName":"[\"夜间\"]"}
    ]"#).unwrap();
    let matches = match_text(&rules, "甲乙丙", false, Some("夜间")).unwrap();
    assert_eq!(
        matches.iter().map(|r| (r.start, r.end)).collect::<Vec<_>>(),
        vec![(0, 1), (1, 2), (2, 3)]
    );
    let styles: Vec<_> = matches
        .iter()
        .map(|m| HighlightStyle::parse(&m.style).unwrap())
        .collect();
    assert_eq!(styles[0].letter_spacing_before, 4.0);
    assert_eq!(styles[0].letter_spacing_after, 0.0);
    assert_eq!(styles[1].bg_color, None);
    assert_eq!(styles[2].letter_spacing_after, 6.0);
    assert_eq!(
        match_text(&rules, "甲乙丙", false, Some("日间"))
            .unwrap()
            .len(),
        1
    );
}
