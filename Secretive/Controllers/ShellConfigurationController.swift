import Foundation
import Cocoa

struct ShellConfigurationController {
    
    let socketPath = (NSHomeDirectory().replacingOccurrences(of: "com.maxgoedjen.Secretive.Host", with: "com.maxgoedjen.Secretive.SecretAgent") as NSString).appendingPathComponent("socket.ssh") as String
    
    var shellInstructions: [ShellConfigInstruction] {
        [
            ShellConfigInstruction(shell: "zsh",
                                   shellConfigDirectory: "~/",
                                   shellConfigFilename: ".zshrc",
                                   text: "export SSH_AUTH_SOCK=\(socketPath)"),
            ShellConfigInstruction(shell: "bash",
                                   shellConfigDirectory: "~/",
                                   shellConfigFilename: ".bashrc",
                                   text: "export SSH_AUTH_SOCK=\(socketPath)"),
            ShellConfigInstruction(shell: "fish",
                                   shellConfigDirectory: "~/.config/fish",
                                   shellConfigFilename: "config.fish",
                                   text: "set -x SSH_AUTH_SOCK \(socketPath)"),
        ]
        
    }
    
    
    func addToShell(shellInstructions: ShellConfigInstruction) -> Bool {
        let openPanel = NSOpenPanel()
        // This is sync, so no need to strongly retain
        let delegate = Delegate(name: shellInstructions.shellConfigFilename)
        openPanel.delegate = delegate
        openPanel.message = "Select \(shellInstructions.shellConfigFilename) to let Secretive configure your shell automatically."
        openPanel.prompt = "Add to \(shellInstructions.shellConfigFilename)"
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.showsHiddenFiles = true
        openPanel.directoryURL = URL(fileURLWithPath: shellInstructions.shellConfigDirectory)
        openPanel.nameFieldStringValue = shellInstructions.shellConfigFilename
        openPanel.allowedContentTypes = [.symbolicLink, .data, .plainText]
        openPanel.runModal()
        guard let fileURL = openPanel.urls.first else { return false }
        let handle: FileHandle
        do {
            handle = try FileHandle(forUpdating: fileURL)
            guard let existing = try handle.readToEnd(),
                  let existingString = String(data: existing, encoding: .utf8) else { return false }
            guard !existingString.contains(shellInstructions.text) else {
                return true
            }
            try handle.seekToEnd()
        } catch {
            return false
        }
        handle.write("\n# Secretive Config\n\(shellInstructions.text)\n".data(using: .utf8)!)
        return true
    }
    
}
