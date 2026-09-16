import Foundation

struct POItem: Identifiable, Codable, Hashable {
    var id = UUID().uuidString
    let poNumber: String
    let batchName: String
    let timestamp: String
}
