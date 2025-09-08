#import <Foundation/Foundation.h>
#import <Security/Security.h>


// Forward declarations

// from libproc.h
int proc_pidpath(int pid, void * buffer, uint32_t  buffersize);

// from SecTask.h
OSStatus SecCodeCreateWithPID(int32_t, SecCSFlags, SecCodeRef *);

//! Project version number for SecretAgentKit.
FOUNDATION_EXPORT double SecretAgentKitVersionNumber;

//! Project version string for SecretAgentKit.
FOUNDATION_EXPORT const unsigned char SecretAgentKitVersionString[];


