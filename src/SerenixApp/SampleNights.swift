import Foundation
import SerenixCore

/// Hand-built Nights and Loads for checking the Today screen on the phone before the specs that
/// compute them ship (plan 002, task 8). Shown only while Debug's "Show sample Nights" is on;
/// nothing here is stored.
///
/// 21 Days ending today, so stepping back through them shows: the first 3 Nights Calibrating; a
/// Day with no Night (5 Days ago); a Night without SpO2 (3 Days ago); a Day without a Load (4 Days
/// ago); and every band and Zone, with today Ready and In range, yesterday Steady and Watch, and
/// the Day before Take it easy and Out of range. The other Nights sit near Baselines of HRV 60 ms, Resting HR 52 bpm,
/// respiratory rate 14.0 br/min and skin temperature 34.0 °C.
enum SampleNights {
    /// How many Days the samples cover, ending today.
    private static let days = 21
    /// Days back from today with no Night.
    private static let dayWithoutANight = 5
    /// Days back from today whose Night has no SpO2.
    private static let nightWithoutSpO2 = 3
    /// Days back from today with no Load.
    private static let dayWithoutALoad = 4

    static func make(now: Date, calendar: Calendar) -> (nights: [Night], dayLoads: [DayLoad]) {
        var nights: [Night] = []
        var dayLoads: [DayLoad] = []
        for daysBack in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -daysBack, to: now) else {
                continue
            }
            let day = Day(containing: date, in: calendar.timeZone)
            let load = daysBack == dayWithoutALoad ? nil : 30 + (daysBack * 7) % 50
            dayLoads.append(DayLoad(day: day, load: load))
            guard daysBack != dayWithoutANight else { continue }
            nights.append(night(on: day, daysBack: daysBack, calendar: calendar))
        }
        return (nights, dayLoads)
    }

    /// One Night, with values picked by how many Days back it is.
    private static func night(on day: Day, daysBack: Int, calendar: Calendar) -> Night {
        // A small, repeating wobble around the Baselines for the ordinary Nights.
        let wobble = Double([0, 2, -1, 3, -2, 1, -3][daysBack % 7])
        var values = (
            readiness: 70 + Int(wobble) * 3,
            sleepScore: 78 + Int(wobble) * 2,
            hrv: 60 + wobble,
            restingHR: 52 + wobble / 3,
            respiratoryRate: 14.0 + wobble / 10,
            skinTemperature: 34.0 + wobble / 20,
            spo2: Optional(96.0)
        )
        switch daysBack {
        case 0:  // Ready, everything In range.
            values = (82, 88, 68.4, 49, 14.2, 34.1, 97)
        case 1:  // Steady, everything on Watch.
            values = (55, 70, 55, 54, 14.8, 34.5, 93)
        case 2:  // Take it easy, everything Out of range.
            values = (25, 45, 48, 58, 15.5, 34.9, 90)
        case nightWithoutSpO2:
            values.spo2 = nil
        default:
            break
        }
        let finalWake = time(on: day, hour: 6, minute: 50 - daysBack % 4 * 5, calendar: calendar)
        let sleepOnset = finalWake.map {
            $0.addingTimeInterval(-8 * 3600 + Double(daysBack % 3) * 900)
        }
        let timeAsleep = sleepOnset.flatMap { onset in
            finalWake.map { $0.timeIntervalSince(onset) - 1800 - Double(daysBack % 4) * 300 }
        }
        return Night(
            day: day,
            sleepScore: values.sleepScore,
            readiness: values.readiness,
            restingHR: values.restingHR,
            hrv: values.hrv,
            respiratoryRate: values.respiratoryRate,
            skinTemperature: values.skinTemperature,
            spo2: values.spo2,
            sleepOnset: sleepOnset,
            finalWake: finalWake,
            timeAsleep: timeAsleep,
            timeInBedStart: sleepOnset?.addingTimeInterval(-15 * 60),
            timeInBedEnd: finalWake?.addingTimeInterval(10 * 60)
        )
    }

    /// The time on `day` in the calendar's time zone.
    private static func time(on day: Day, hour: Int, minute: Int, calendar: Calendar) -> Date? {
        calendar.date(
            from: DateComponents(
                year: day.year,
                month: day.month,
                day: day.dayOfMonth,
                hour: hour,
                minute: minute
            )
        )
    }
}
