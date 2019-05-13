extension Optional {
    public mutating func take() -> Wrapped? {
        let x = self
        self = nil
        return x
    }
}
