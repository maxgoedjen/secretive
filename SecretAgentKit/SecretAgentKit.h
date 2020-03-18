//
//  SecretAgentKit.h
//  SecretAgentKit
//
//  Created by Max Goedjen on 2/22/20.
//  Copyright © 2020 Max Goedjen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>

// Forward declaration of proc_pidpath from libproc.h
int proc_pidpath(int pid, void * buffer, uint32_t  buffersize);

OSStatus SecCodeCreateWithPID(int32_t, SecCSFlags, SecCodeRef *);

//! Project version number for SecretAgentKit.
FOUNDATION_EXPORT double SecretAgentKitVersionNumber;

//! Project version string for SecretAgentKit.
FOUNDATION_EXPORT const unsigned char SecretAgentKitVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <SecretAgentKit/PublicHeader.h>


