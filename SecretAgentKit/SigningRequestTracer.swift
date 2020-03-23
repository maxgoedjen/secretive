import Foundation
import AppKit
import Security

struct SigningRequestTracer {

    func provenance(from fileHandleReader: FileHandleReader) -> SigningRequestProvenance {
        let firstInfo = process(from: fileHandleReader.pidOfConnectedProcess)

        var provenance = SigningRequestProvenance(root: firstInfo)
        while NSRunningApplication(processIdentifier: provenance.origin.pid) == nil && provenance.origin.parentPID != nil {
            provenance.chain.append(process(from: provenance.origin.parentPID!))
        }
        return provenance
    }

    func pidAndNameInfo(from pid: Int32) -> kinfo_proc {
        var len = MemoryLayout<kinfo_proc>.size
        let infoPointer = UnsafeMutableRawPointer.allocate(byteCount: len, alignment: 1)
        var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        sysctl(&name, UInt32(name.count), infoPointer, &len, nil, 0)
        return infoPointer.load(as: kinfo_proc.self)
    }

    func process(from pid: Int32) -> SigningRequestProvenance.Process {
        var pidAndNameInfo = self.pidAndNameInfo(from: pid)
        let ppid = pidAndNameInfo.kp_eproc.e_ppid != 0 ? pidAndNameInfo.kp_eproc.e_ppid : nil
        let procName = String(cString: &pidAndNameInfo.kp_proc.p_comm.0)
        let pathPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(MAXPATHLEN))
        _ = proc_pidpath(pid, pathPointer, UInt32(MAXPATHLEN))
        let path = String(cString: pathPointer)
        var secCode: Unmanaged<SecCode>!
        let flags: SecCSFlags = [.considerExpiration, .enforceRevocationChecks]
        SecCodeCreateWithPID(pid, SecCSFlags(), &secCode)
        let valid = SecCodeCheckValidity(secCode.takeRetainedValue(), flags, nil) == errSecSuccess
        return SigningRequestProvenance.Process(pid: pid, name: procName, path: path, validSignature: valid, parentPID: ppid)
    }

}
