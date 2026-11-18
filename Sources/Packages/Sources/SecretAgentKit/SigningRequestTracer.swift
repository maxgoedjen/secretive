import Foundation
import AppKit
import Security
import SecretKit

/// An object responsible for generating ``SecretKit.SigningRequestProvenance`` objects.
struct SigningRequestTracer {
}

extension SigningRequestTracer {

    /// Generates a ``SecretKit.SigningRequestProvenance`` from a ``FileHandle``.
    /// - Parameter fileHandle: The reader involved in processing the request.
    /// - Returns: A ``SecretKit.SigningRequestProvenance`` describing the origin of the request.
    func provenance(from fileHandle: FileHandle) -> SigningRequestProvenance {
        let firstInfo = process(from: fileHandle.pidOfConnectedProcess)
        var provenance = SigningRequestProvenance(root: firstInfo)
        while NSRunningApplication(processIdentifier: provenance.origin.pid) == nil && provenance.origin.parentPID != nil {
            provenance.chain.append(process(from: provenance.origin.parentPID!))
        }
        return provenance
    }

    /// Generates a `kinfo_proc` representation of the provided process ID.
    /// - Parameter pid: The process ID to look up.
    /// - Returns: a `kinfo_proc` struct describing the process ID.
    func pidAndNameInfo(from pid: Int32) -> kinfo_proc {
        var len = unsafe MemoryLayout<kinfo_proc>.size
        let infoPointer = UnsafeMutableRawPointer.allocate(byteCount: len, alignment: 1)
        var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        unsafe sysctl(&name, UInt32(name.count), infoPointer, &len, nil, 0)
        return unsafe infoPointer.load(as: kinfo_proc.self)
    }

    /// Generates a ``SecretKit.SigningRequestProvenance.Process`` from a provided process ID.
    /// - Parameter pid: The process ID to look up.
    /// - Returns: A ``SecretKit.SigningRequestProvenance.Process`` describing the process.
    func process(from pid: Int32) -> SigningRequestProvenance.Process {
        var pidAndNameInfo = unsafe self.pidAndNameInfo(from: pid)
        let ppid = unsafe pidAndNameInfo.kp_eproc.e_ppid != 0 ? pidAndNameInfo.kp_eproc.e_ppid : nil
        let procName = unsafe withUnsafeMutablePointer(to: &pidAndNameInfo.kp_proc.p_comm.0) { pointer in
            unsafe String(cString: pointer)
        }

        let pathPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(MAXPATHLEN))
        _ = unsafe proc_pidpath(pid, pathPointer, UInt32(MAXPATHLEN))

        let path = unsafe String(cString: pathPointer)
        var secCode: Unmanaged<SecCode>!
        let flags: SecCSFlags = [.considerExpiration, .enforceRevocationChecks]
        unsafe SecCodeCreateWithPID(pid, SecCSFlags(), &secCode)
        let code = unsafe secCode.takeRetainedValue()
        let valid = SecCodeCheckValidity(code, flags, nil) == errSecSuccess
        return SigningRequestProvenance.Process(pid: pid, processName: procName, appName: appName(for: pid), iconURL: iconURL(for: pid), path: path, validSignature: valid, parentPID: ppid, processGroupID: unsafe pidAndNameInfo.kp_eproc.e_pgid, arguments: arguments(for: pid), workingDirectory: workingDirectory(for: pid), protected: isProtected(code))
    }

    /// Looks up the arguments a process ID was launched with.
    /// - Parameter pid: The process ID to look up.
    /// - Returns: The process's arguments, if they can be read.
    func arguments(for pid: Int32) -> [String]? {
        argumentArea(for: pid).flatMap(arguments(from:))
    }

    /// Reads the argument area of a process ID, which holds its argument count, executable path, arguments and environment.
    /// - Parameter pid: The process ID to look up.
    /// - Returns: The raw contents of the process's argument area, if it can be read.
    func argumentArea(for pid: Int32) -> [UInt8]? {
        var name: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var length = 0
        guard unsafe sysctl(&name, UInt32(name.count), nil, &length, nil, 0) == 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: length)
        guard unsafe sysctl(&name, UInt32(name.count), &buffer, &length, nil, 0) == 0 else { return nil }
        return Array(buffer.prefix(length))
    }

    /// Parses the arguments out of a process's argument area.
    /// - Parameter area: The raw contents of a process's argument area.
    /// - Returns: The process's arguments, if the area is well formed.
    /// - Note: The kernel pads the executable path with NULs up to a pointer boundary, so the arguments start at the next boundary. Skipping every NUL after the path instead would also swallow an empty first argument.
    func arguments(from area: [UInt8]) -> [String]? {
        let countSize = MemoryLayout<Int32>.size
        guard area.count >= countSize, let pathEnd = area[countSize...].firstIndex(of: 0) else { return nil }
        let argc = area.prefix(countSize).reversed().reduce(0) { $0 << 8 | Int($1) }
        let alignment = MemoryLayout<Int>.size
        let paddedPathLength = (pathEnd - countSize + alignment) / alignment * alignment
        let arguments = area.dropFirst(countSize + paddedPathLength)
            .split(separator: 0, maxSplits: argc, omittingEmptySubsequences: false)
        guard arguments.count > argc else { return nil }
        return arguments.prefix(argc).map { String(decoding: $0, as: UTF8.self) }
    }

    /// Looks up the current working directory of a process ID.
    /// - Parameter pid: The process ID to look up.
    /// - Returns: The process's working directory, if it can be read.
    func workingDirectory(for pid: Int32) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard unsafe proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        return withUnsafeMutablePointer(to: &info.pvi_cdir.vip_path.0) { pointer in
            unsafe String(cString: pointer)
        }
    }

    /// Checks whether other processes are prevented from modifying a running process.
    /// - Parameter code: The running code to check.
    /// - Returns: A boolean describing whether or not the process is protected from modification.
    func isProtected(_ code: SecCode) -> Bool {
        var information: CFDictionary?
        guard unsafe SecCodeCopySigningInformation(unsafeBitCast(code, to: SecStaticCode.self), SecCSFlags(rawValue: kSecCSDynamicInformation), &information) == errSecSuccess,
              let rawStatus = (information as? [CFString: Any])?[kSecCodeInfoStatus] as? UInt32 else { return false }
        let status = SecCodeStatus(rawValue: rawStatus)
        guard status.contains(.valid), status.isDisjoint(with: [.debugged, .getTaskAllow]) else { return false }
        return status.contains([.platform, .runtime]) || (!status.isDisjoint(with: [.platform, .runtime]) && !status.isDisjoint(with: [.forcedLibraryValidation, .requireLibraryValidation]))
    }

    /// Looks up the URL for the icon of a process ID, if it has one.
    /// - Parameter pid: The process ID to look up.
    /// - Returns: A URL to the icon, if the process has one.
    func iconURL(for pid: Int32) -> URL? {
        do {
            if let app = NSRunningApplication(processIdentifier: pid), let icon = app.icon?.tiffRepresentation {
                let temporaryURL = URL(fileURLWithPath: (NSTemporaryDirectory() as NSString).appendingPathComponent("\(app.bundleIdentifier ?? UUID().uuidString).png"))
                if FileManager.default.fileExists(atPath: temporaryURL.path) {
                    return temporaryURL
                }
                let bitmap = NSBitmapImageRep(data: icon)
                try bitmap?.representation(using: .png, properties: [:])?.write(to: temporaryURL)
                return temporaryURL
            }
        } catch {
        }
        return nil
    }

    /// Looks up the application name of a process ID, if it has one.
    /// - Parameter pid: The process ID to look up.
    /// - Returns: The process's display name, if the process has one.
    func appName(for pid: Int32) -> String? {
        NSRunningApplication(processIdentifier: pid)?.localizedName
    }

}

//// from cs_blobs.h
private extension SecCodeStatus {
    static let getTaskAllow = SecCodeStatus(rawValue: 0x00000004)
    static let forcedLibraryValidation = SecCodeStatus(rawValue: 0x00000010)
    static let requireLibraryValidation = SecCodeStatus(rawValue: 0x00002000)
    static let runtime = SecCodeStatus(rawValue: 0x00010000)
}

//// from SecTask.h
@_silgen_name("SecCodeCreateWithPID")
@discardableResult func SecCodeCreateWithPID(_: Int32, _: SecCSFlags, _: UnsafeMutablePointer<Unmanaged<SecCode>?>!) -> OSStatus
