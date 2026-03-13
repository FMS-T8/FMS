extension Int {
    var formattedDuration: String {
        let hours = self / 60
        let minutes = self % 60
        return "\(hours)h \(minutes)m"
    }
}
