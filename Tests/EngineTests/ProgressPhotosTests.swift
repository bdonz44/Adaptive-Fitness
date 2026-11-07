import Foundation
import Testing
@testable import Hybrid12Engine

@Suite struct ProgressPhotosTests {
    let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/Chicago")!; return c }()
    let now = Date(timeIntervalSince1970: 1_793_000_000)
    func ago(_ d: Int) -> Date { cal.date(byAdding: .day, value: -d, to: now)! }

    var photos: [ProgressPhoto] {
        [ProgressPhoto(date: ago(28), pose: .front, file: "a"), ProgressPhoto(date: ago(28), pose: .side, file: "b"),
         ProgressPhoto(date: ago(10), pose: .front, file: "c"), ProgressPhoto(date: ago(10).addingTimeInterval(60), pose: .front, file: "d")]
    }

    @Test func ghostIsTheNewestPhotoOfThatPose() {
        #expect(ProgressPhotos.latest(photos, pose: .front)?.file == "d")
        #expect(ProgressPhotos.latest(photos, pose: .side)?.file == "b")
        #expect(ProgressPhotos.latest(photos, pose: .back) == nil)
        #expect(ProgressPhotos.latest(photos, pose: .front, before: ago(20))?.file == "a")
    }

    @Test func daysAndDue() {
        #expect(ProgressPhotos.days(photos, calendar: cal).count == 2)
        #expect(ProgressPhotos.photo(photos, pose: .front, on: ago(10), calendar: cal)?.file == "d")
        #expect(ProgressPhotos.daysUntilDue(photos, now: now, calendar: cal) == 4)
        #expect(ProgressPhotos.daysUntilDue([], now: now, calendar: cal) == nil)
    }
}
