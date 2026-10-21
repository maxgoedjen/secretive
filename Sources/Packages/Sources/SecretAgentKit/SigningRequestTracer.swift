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
    /// - Returns: a `kinfo_proc` struct describing the process ID. Zeroed if the lookup fails.
    func pidAndNameInfo(from pid: Int32) -> kinfo_proc {
        var info = unsafe kinfo_proc()
        var len = unsafe MemoryLayout<kinfo_proc>.size
        var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        unsafe sysctl(&name, UInt32(name.count), &info, &len, nil, 0)
        return unsafe info
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

        let pathBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(MAXPATHLEN))
        defer { unsafe pathBuffer.deallocate() }
        unsafe pathBuffer.initialize(repeating: 0, count: Int(MAXPATHLEN))
        _ = unsafe proc_pidpath(pid, pathBuffer, UInt32(MAXPATHLEN))
        let path = unsafe String(cString: pathBuffer)
        var secCode: Unmanaged<SecCode>!
        let flags: SecCSFlags = [.considerExpiration, .enforceRevocationChecks]
        unsafe SecCodeCreateWithPID(pid, SecCSFlags(), &secCode)
        let valid = unsafe SecCodeCheckValidity(secCode.takeRetainedValue(), flags, nil) == errSecSuccess
        return SigningRequestProvenance.Process(pid: pid, processName: procName, appName: appName(for: pid), iconURL: iconURL(for: pid), path: path, validSignature: valid, parentPID: ppid)
    }

    /// Looks up the URL for the icon of a process ID, if it has one.
    /// - Parameter pid: The process ID to look up.
    /// - Returns: A URL to the icon, if the process has one.
    /// - Note: The icon is rendered once at ``Constants/iconSize`` and cached on disk. Encoding every representation of a modern app icon produces tens of megabytes per call, and the tracer runs on the main actor for every connection, so the intermediate objects are released here rather than at the end of the run loop iteration.
    func iconURL(for pid: Int32) -> URL? {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }
        let temporaryURL = URL(fileURLWithPath: (NSTemporaryDirectory() as NSString).appendingPathComponent("\(app.bundleIdentifier ?? UUID().uuidString).png"))
        if FileManager.default.fileExists(atPath: temporaryURL.path) {
            return temporaryURL
        }
        return autoreleasepool {
            guard let icon = app.icon else { return nil }
            var rect = NSRect(origin: .zero, size: Constants.iconSize)
            guard let cgImage = unsafe icon.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return nil }
            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { return nil }
            do {
                try png.write(to: temporaryURL)
            } catch {
                return nil
            }
            return temporaryURL
        }
    }

    /// Looks up the application name of a process ID, if it has one.
    /// - Parameter pid: The process ID to look up.
    /// - Returns: The process's display name, if the process has one.
    func appName(for pid: Int32) -> String? {
        NSRunningApplication(processIdentifier: pid)?.localizedName
    }

}

extension SigningRequestTracer {

    enum Constants {
        /// The size, in points, at which application icons are rendered for notifications.
        static let iconSize = NSSize(width: 256, height: 256)
    }

}

//// from SecTask.h
@_silgen_name("SecCodeCreateWithPID")
@discardableResult func SecCodeCreateWithPID(_: Int32, _: SecCSFlags, _: UnsafeMutablePointer<Unmanaged<SecCode>?>!) -> OSStatus
