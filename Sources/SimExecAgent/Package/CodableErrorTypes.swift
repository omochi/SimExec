import Foundation
import SimExec

private let _errorTypes: [CodableError.Type] = [
    MessageError.self
]

public let codableErrorTypes: [CodableErrorTypeInfo] =
    _errorTypes.map { (t) in
        CodableErrorTypeInfo(type: t)
}
