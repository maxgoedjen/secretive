import Foundation
import XCTest
@testable import SecretKit
@testable import SecureEnclaveSecretKit
@testable import SmartCardSecretKit

class OpenSSHReaderTests: XCTestCase {

    func testSignatureRequest() {
        let reader = OpenSSHReader(data: Constants.signatureRequest)
        let hash = reader.readNextChunk()
        XCTAssert(hash == Data(base64Encoded: "AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBEqCbkJbOHy5S1wVCaJoKPmpS0egM4frMqllgnlRRQ/Uvnn6EVS8oV03cPA2Bz0EdESyRKA/sbmn0aBtgjIwGELxu45UXEW1TEz6TxyS0u3vuIqR3Wo1CrQWRDnkrG/pBQ=="))
        let dataToSign = reader.readNextChunk()
        XCTAssert(dataToSign == Data(base64Encoded: "AAAAICi5xf1ixOestUlxdjvt/BDcM+rzhwy7Vo8cW5YcxA8+MgAAAANnaXQAAAAOc3NoLWNvbm5lY3Rpb24AAAAJcHVibGlja2V5AQAAABNlY2RzYS1zaGEyLW5pc3RwMzg0AAAAiAAAABNlY2RzYS1zaGEyLW5pc3RwMzg0AAAACG5pc3RwMzg0AAAAYQRKgm5CWzh8uUtcFQmiaCj5qUtHoDOH6zKpZYJ5UUUP1L55+hFUvKFdN3DwNgc9BHREskSgP7G5p9GgbYIyMBhC8buOVFxFtUxM+k8cktLt77iKkd1qNQq0FkQ55Kxv6QU="))
        let empty = reader.readNextChunk()
        XCTAssert(empty.isEmpty)
    }

}

extension OpenSSHReaderTests {

    enum Constants {
        static let signatureRequest = Data(base64Encoded: "AAAAiAAAABNlY2RzYS1zaGEyLW5pc3RwMzg0AAAACG5pc3RwMzg0AAAAYQRKgm5CWzh8uUtcFQmiaCj5qUtHoDOH6zKpZYJ5UUUP1L55+hFUvKFdN3DwNgc9BHREskSgP7G5p9GgbYIyMBhC8buOVFxFtUxM+k8cktLt77iKkd1qNQq0FkQ55Kxv6QUAAADvAAAAICi5xf1ixOestUlxdjvt/BDcM+rzhwy7Vo8cW5YcxA8+MgAAAANnaXQAAAAOc3NoLWNvbm5lY3Rpb24AAAAJcHVibGlja2V5AQAAABNlY2RzYS1zaGEyLW5pc3RwMzg0AAAAiAAAABNlY2RzYS1zaGEyLW5pc3RwMzg0AAAACG5pc3RwMzg0AAAAYQRKgm5CWzh8uUtcFQmiaCj5qUtHoDOH6zKpZYJ5UUUP1L55+hFUvKFdN3DwNgc9BHREskSgP7G5p9GgbYIyMBhC8buOVFxFtUxM+k8cktLt77iKkd1qNQq0FkQ55Kxv6QUAAAAA")!
    }

}
