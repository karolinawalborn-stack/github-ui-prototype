import Foundation

protocol AppStorageProtocol {
    func loadSelectedModel() -> String?
    func saveSelectedModel(_ modelID: String)
}

final class MockAppStorage: AppStorageProtocol {
    private var selectedModelID: String?

    func loadSelectedModel() -> String? { selectedModelID }

    func saveSelectedModel(_ modelID: String) {
        selectedModelID = modelID
    }
}
