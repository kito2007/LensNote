//
//  FilterPresetTests.swift
//  LensNoteTests
//
//  Req 9.3 — FilterPreset.forConcept 키워드 매핑 검증.
//

import Testing
@testable import LensNote

struct FilterPresetTests {

    /// (a) 매핑된 키워드 입력 → 해당 프리셋 name 반환.
    @Test("매핑 키워드 → 해당 프리셋")
    func mappedKeywordReturnsPreset() {
        #expect(FilterPreset.forConcept("무드").name == "Cinematic")
        #expect(FilterPreset.forConcept("야경").name == "Night Mood")
        #expect(FilterPreset.forConcept("인물").name == "Portrait")
    }

    /// (b) 빈 문자열 입력 → "Standard".
    @Test("빈 문자열 → Standard")
    func emptyReturnsStandard() {
        #expect(FilterPreset.forConcept("").name == "Standard")
        #expect(FilterPreset.forConcept("   ").name == "Standard")
    }

    /// (c) 매핑되지 않은 키워드 입력 → "Standard".
    @Test("미매핑 키워드 → Standard")
    func unmappedReturnsStandard() {
        #expect(FilterPreset.forConcept("zzqqxx").name == "Standard")
    }
}
