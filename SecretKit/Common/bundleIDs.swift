//
//  bundleIDs.swift
//  SecretKit
//
//  Created by Alex lavallee on 12/27/20.
//  Copyright © 2020 Max Goedjen. All rights reserved.
//

import Foundation


extension Bundle {
    public var agentBundleID: String {(self.bundleIdentifier?.replacingOccurrences(of: "Host", with: "SecretAgent"))!}
    public var hostBundleID: String {(self.bundleIdentifier?.replacingOccurrences(of: "SecretAgent", with: "Host"))!}
}
