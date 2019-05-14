import Foundation

public final class IDPool {
    private var ids: Set<Int>
    
    public init() {
        self.ids = Set()
    }
    
    public func create() -> IDHolder {
        var id = 1
        while ids.contains(id) {
            id += 1
        }
        ids.insert(id)
        return IDHolder(pool: self,
                        id: id)
    }
    
    public func release(id: Int) {
        ids.remove(id)
    }
}

public final class IDHolder {
    private weak var pool: IDPool?
    public var id: Int
    
    public init(pool: IDPool,
                id: Int)
    {
        self.pool = pool
        self.id = id
    }
    
    deinit {
        pool?.release(id: id)
    }
}
