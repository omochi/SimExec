import Foundation
import FineJSON

private enum ResultCodingKeys : CodingKey {
    case value
    case error
}

public func decodeResult<T>(from decoder: Decoder,
                            errorTypes: [CodableErrorTypeInfo])
    throws -> Result<T, Error>
    where T : Decodable
{
    let c = try decoder.container(keyedBy: ResultCodingKeys.self)
    if c.contains(.error) {
        let error = try decodeDecodableError(from: c,
                                             forKey: .error,
                                             errorTypes: errorTypes)
        return Result.failure(error)
    }
    let value = try c.decode(T.self, forKey: .value)
    return Result.success(value)
}

public func encodeResult<T>(_ result: Result<T, Error>,
                            to encoder: Encoder,
                            errorTypes: [CodableErrorTypeInfo])
    throws
    where T : Encodable
{
    var c = encoder.container(keyedBy: ResultCodingKeys.self)
    switch result {
    case .success(let value):
        try c.encode(value, forKey: .value)
    case .failure(let error):
        try encodeEncodableError(error, to: &c, forKey: .error,
                                 errorTypes: errorTypes)
    }
}

private enum ErrorContainerCodingKeys : CodingKey {
    case type
    case value
}

private func decodeDecodableError<K>(from container: KeyedDecodingContainer<K>,
                                     forKey key: K,
                                  errorTypes: [CodableErrorTypeInfo]) throws -> Error
    where K : CodingKey
{
    let c = try container.nestedContainer(keyedBy: ErrorContainerCodingKeys.self,
                                          forKey: key)
    let typeName = try c.decode(String.self, forKey: .type)
    guard let typeInfo = (errorTypes.first { $0.name == typeName }) else {
        throw DecodingError.custom(message: "unknown error type: \(typeName)",
            codingPath: container.codingPath,
            location: container.sourceLocation)
    }
    let error: Error = try typeInfo.type.dispatch_KeyedDecodingContainer_decode(container: c, forKey: .value)
    return error
}

private func encodeEncodableError<K>(_ error: Error,
                                     to container: inout KeyedEncodingContainer<K>,
                                     forKey key: K,
                                     errorTypes: [CodableErrorTypeInfo]) throws
    where K : CodingKey
{
    var c = container.nestedContainer(keyedBy: ErrorContainerCodingKeys.self,
                                      forKey: key)
    
    let (typeInfo, error) = errorToEncodableError(error, errorTypes: errorTypes)
    
    try c.encode(typeInfo.name, forKey: .type)
    try error.dispatch_KeyedEncodingContainer_encode(container: &c, forKey: .value)
}

private func errorToEncodableError(_ error: Error,
                                   errorTypes: [CodableErrorTypeInfo])
    -> (CodableErrorTypeInfo, CodableError)
{
    let originalType = type(of: error)
    
    if let typeInfo = (errorTypes.first { $0.type == originalType }) {
        return (typeInfo, error as! CodableError)
    }
    
    let message = "\(error)"
    let typeInfo = CodableErrorTypeInfo(type: MessageError.self)
    return (typeInfo, MessageError(message))
}
