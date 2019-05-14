import XCTest
import Network
import SimExec
import SimExecAgent

final class TransportTests: XCTestCase {
    func testFileSend() throws {
        let exp = expectation(description: "")
        
        let fs1 = FileSystem(applicationName: "fs1")
        let fs2 = FileSystem(applicationName: "fs2")
        
        var conn1: JSONConnection!
        var conn2: JSONConnection!
        
        createConnectionPair(fs1: fs1, fs2: fs2) { (pair) in
            do {
                let pair = try pair.get()
                
                conn1 = pair.0
                conn2 = pair.1
                
                conn1.errorHandler = { (error) in
                    XCTFail("\(error)")
                }
                conn2.errorHandler = { (error) in
                    XCTFail("\(error)")
                }
                
                var si = 0
                
                var send: (() -> Void)?
                
                send = {
                    let file = resourceDirectory
                        .appendingPathComponent("SimExecAgentTests")
                        .appendingPathComponent("image\(si).png")
                    conn1.send(file: file,
                               completionHandler: {
                                si += 1
                                if si == 3 {
                                    return
                                }
                                send!()
                    })
                }
                
                send!()
                
                var ri = 0
                
                let expectedSizes = [
                    CGSize(width: 600, height: 600),
                    CGSize(width: 700, height: 600),
                    CGSize(width: 800, height: 600)
                ]
                
                conn2.fileHandler = { (file) in
                    let image = NSImage(contentsOf: file)!
                    
                    XCTAssertEqual(image.size, expectedSizes[ri])                    
                    
                    ri += 1
                    if ri == 3 {
                        exp.fulfill()
                        return
                    }
                }
            } catch {
                XCTFail("\(error)")
            }
        }
        
        wait(for: [exp], timeout: 30)
    }
    
    private func createConnectionPair(fs1: FileSystem,
                                      fs2: FileSystem,
                                      handler: @escaping (Result<(JSONConnection, JSONConnection), Error>) -> Void)
    {
        do {
            let port = NWEndpoint.Port(31514)
            var listen: NWListener? = try NWListener(using: NWParameters(tls: nil),
                                                     on: port)
            
            let nwConn2 = NWConnection(host: "localhost",
                                       port: port,
                                       using: NWParameters(tls: nil))
            let conn2 = JSONConnection(connection: nwConn2,
                                       fileSystem: fs2)
            conn2.errorHandler = { (error) in
                listen = nil
                handler(.failure(error))
            }

            listen!.stateUpdateHandler = { (state) in
                switch state {
                case .failed(let error):
                    listen = nil
                    handler(.failure(error))
                default:
                    break
                }
            }
            listen!.newConnectionHandler = { (nwConn1) in
                let conn1 = JSONConnection(connection: nwConn1,
                                           fileSystem: fs1)
                conn1.start(queue: .main)
                let pair = (conn1, conn2)
                listen?.cancel()
                listen = nil
                handler(.success(pair))
            }
            listen!.start(queue: .main)
            
            conn2.start(queue: .main)
        } catch {
            handler(.failure(error))
        }
    }
        
}
