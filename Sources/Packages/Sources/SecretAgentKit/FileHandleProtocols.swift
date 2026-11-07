import Foundation
import Darwin

extension FileHandle {

    public var pidOfConnectedProcess: Int32 {
        var pid: Int32 = 0
        var len = socklen_t(MemoryLayout<Int32>.size)
        let res = unsafe getsockopt(fileDescriptor, SOL_LOCAL, LOCAL_PEERPID, &pid, &len)
        return res == 0 ? pid : 0
    }

    public var auditTokenOfConnectedProcess: audit_token_t? {
        var token = audit_token_t()
        var len = socklen_t(MemoryLayout<audit_token_t>.size)
        let res = unsafe getsockopt(fileDescriptor, SOL_LOCAL, LOCAL_PEERTOKEN, &token, &len)
        guard res == 0 else { return nil }
        return token
    }

    public var peerUID: uid_t? {
        var uid: uid_t = 0
        var gid: gid_t = 0
        let res = unsafe getpeereid(fileDescriptor, &uid, &gid)
        guard res == 0 else { return nil }
        return uid
    }

}
