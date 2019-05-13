extension Result {
    public var value: Success? {
        switch self {
        case .success(let v): return v
        case .failure: return nil
        }
    }
    
    public var error: Failure? {
        switch self {
        case .success: return nil
        case .failure(let e): return e
        }
    }
    
    public init(value: Success?, error: Failure?) {
        if let value = value {
            self = .success(value)
        } else {
            self = .failure(error!)
        }
    }
}
