import Testing
@testable import MacbyCore

@Suite struct ContentHasherTests {
    @Test func sameTextProducesSameHash() {
        #expect(ContentHasher.hash(text: "hello") == ContentHasher.hash(text: "hello"))
    }

    @Test func differentTextProducesDifferentHash() {
        #expect(ContentHasher.hash(text: "hello") != ContentHasher.hash(text: "world"))
    }

    @Test func fileURLHashIsOrderIndependent() {
        let a = ContentHasher.hash(fileURLs: ["/a", "/b"])
        let b = ContentHasher.hash(fileURLs: ["/b", "/a"])
        #expect(a == b)
    }
}
