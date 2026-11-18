import SecretKit
import Foundation

extension SigningRequestProvenance {

    static let test = SigningRequestProvenance(root: .init(pid: 0, processName: "test", appName: nil, iconURL: nil, path: "/", validSignature: true, parentPID: 0))

}

extension AgentTests {

    func storeList(with secrets: [Stub.Secret]) async -> SecretStoreList {
        let store = Stub.Store()
        store.secrets.append(contentsOf: secrets)
        let storeList = SecretStoreList()
        storeList.add(store: store)
        return storeList
    }

    enum Constants {

        enum Requests {
            static let requestIdentities = Data(base64Encoded: "AAAAAQs=")!
            static let requestSignatureWithNoneMatching = Data(base64Encoded: "AAABhA0AAACIAAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBEqCbkJbOHy5S1wVCaJoKPmpS0egM4frMqllgnlRRQ/Uvnn6EVS8oV03cPA2Bz0EdESyRKA/sbmn0aBtgjIwGELxu45UXEW1TEz6TxyS0u3vuIqR3Wo1CrQWRDnkrG/pBQAAAO8AAAAgbqmrqPUtJ8mmrtaSVexjMYyXWNqjHSnoto7zgv86xvcyAAAAA2dpdAAAAA5zc2gtY29ubmVjdGlvbgAAAAlwdWJsaWNrZXkBAAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAACIAAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBEqCbkJbOHy5S1wVCaJoKPmpS0egM4frMqllgnlRRQ/Uvnn6EVS8oV03cPA2Bz0EdESyRKA/sbmn0aBtgjIwGELxu45UXEW1TEz6TxyS0u3vuIqR3Wo1CrQWRDnkrG/pBQAAAAA=")!
            static let requestSignature = Data(base64Encoded: "AAABRA0AAABoAAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBKzOkUiVJEcACMtAd9X7xalbc0FYZyhbmv2dsWl4IP2GWIi+RcsaHQNw+nAIQ8CKEYmLnl0VLDp5Ef8KMhgIy08AAADPAAAAIBIFsbCZ4/dhBmLNGHm0GKj7EJ4N8k/jXRxlyg+LFIYzMgAAAANnaXQAAAAOc3NoLWNvbm5lY3Rpb24AAAAJcHVibGlja2V5AQAAABNlY2RzYS1zaGEyLW5pc3RwMjU2AAAAaAAAABNlY2RzYS1zaGEyLW5pc3RwMjU2AAAACG5pc3RwMjU2AAAAQQSszpFIlSRHAAjLQHfV+8WpW3NBWGcoW5r9nbFpeCD9hliIvkXLGh0DcPpwCEPAihGJi55dFSw6eRH/CjIYCMtPAAAAAA==")!
        }

        enum Responses {
            static let requestIdentitiesEmpty = Data(base64Encoded: "AAAABQwAAAAA")!
            static let requestIdentitiesMultiple = Data(base64Encoded: "AAABLwwAAAACAAAAaAAAABNlY2RzYS1zaGEyLW5pc3RwMjU2AAAACG5pc3RwMjU2AAAAQQSszpFIlSRHAAjLQHfV+8WpW3NBWGcoW5r9nbFpeCD9hliIvkXLGh0DcPpwCEPAihGJi55dFSw6eRH/CjIYCMtPAAAAFWVjZHNhLTI1NkBleGFtcGxlLmNvbQAAAIgAAAATZWNkc2Etc2hhMi1uaXN0cDM4NAAAAAhuaXN0cDM4NAAAAGEEspLMDmreMJverQkqKC9zF9ZUasn5uSWkbRlz1jNTCtuyH1KKm+VImL6wdAj47SbzwM6lEEC24AdfrR64P9i/bnS2i83v/4wQVtcZn+Et13QGgWlZst8lxCPzTookaVwMAAAAFWVjZHNhLTM4NEBleGFtcGxlLmNvbQ==")!
            static let requestFailure = Data(base64Encoded: "AAAAAQU=")!
        }

        enum Secrets {
            static let ecdsa256Secret =  Stub.Secret(keySize: 256, publicKey: Data(base64Encoded: "BKzOkUiVJEcACMtAd9X7xalbc0FYZyhbmv2dsWl4IP2GWIi+RcsaHQNw+nAIQ8CKEYmLnl0VLDp5Ef8KMhgIy08=")!, privateKey: Data(base64Encoded: "BKzOkUiVJEcACMtAd9X7xalbc0FYZyhbmv2dsWl4IP2GWIi+RcsaHQNw+nAIQ8CKEYmLnl0VLDp5Ef8KMhgIy09nw780wy/TSfUmzj15iJkV234AaCLNl+H8qFL6qK8VIg==")!)
            static let ecdsa384Secret =  Stub.Secret(keySize: 384, publicKey: Data(base64Encoded: "BLKSzA5q3jCb3q0JKigvcxfWVGrJ+bklpG0Zc9YzUwrbsh9SipvlSJi+sHQI+O0m88DOpRBAtuAHX60euD/Yv250tovN7/+MEFbXGZ/hLdd0BoFpWbLfJcQj806KJGlcDA==")!, privateKey: Data(base64Encoded: "BLKSzA5q3jCb3q0JKigvcxfWVGrJ+bklpG0Zc9YzUwrbsh9SipvlSJi+sHQI+O0m88DOpRBAtuAHX60euD/Yv250tovN7/+MEFbXGZ/hLdd0BoFpWbLfJcQj806KJGlcDHNapAOzrt9E+9QC4/KYoXS7Uw4pmdAz53uIj02tttiq3c0ZyIQ7XoscWWRqRrz8Kw==")!)
        }

    }

}
