/// The middle value, or the mean of the two middle values for an even count (as Python's
/// `statistics.median`, which hr-tracker uses). `values` must not be empty.
func median(of values: [Double]) -> Double {
    let sorted = values.sorted()
    let middle = sorted.count / 2
    return sorted.count.isMultiple(of: 2)
        ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
}
