import Foundation
#if os(Windows)
import WinSDK
#endif

#if canImport(System)
import System

public typealias FilePath = System.FilePath
public typealias FileDescriptor = System.FileDescriptor
public typealias Errno = System.Errno
#else
import SystemPackage

public typealias FilePath = SystemPackage.FilePath
public typealias FileDescriptor = SystemPackage.FileDescriptor
public typealias Errno = SystemPackage.Errno

extension URL {
    public init?(filePath: FilePath) {
        self.init(filePath: filePath.string)
    }
}

extension FilePath {
    public init?(_ url: URL) {
        guard url.isFileURL else { return nil }
        self.init(url.path)
    }
}
#endif

extension FileDescriptor {
    /// Writes every byte, waiting for capacity if the descriptor is nonblocking.
    package func writeAllWaiting(_ bytes: UnsafeRawBufferPointer) throws {
        var offset = 0
        while offset < bytes.count {
            do {
                // Swift System retries EINTR; retain the offset when a write is partial.
                let count = try write(UnsafeRawBufferPointer(rebasing: bytes[offset...]))
                guard count > 0 else { throw Errno.ioError }
                offset += count
            } catch let error as Errno where error == .resourceTemporarilyUnavailable || error == .wouldBlock {
                #if os(Windows)
                // CRT file descriptors are never nonblocking
                throw error
                #else
                var descriptor = pollfd(fd: rawValue, events: Int16(POLLOUT), revents: 0)
                while true {
                    try Task.checkCancellation()
                    // periodically wake up to check for cancellation
                    let result = poll(&descriptor, 1, 100)
                    if result > 0 { break }
                    if result == -1 {
                        let error = Errno(rawValue: errno)
                        guard error != .interrupted else { continue }
                        throw error
                    }
                }
                // Retry write to report terminal errors (including POLLERR/POLLNVAL).
                #endif
            }
        }
    }

    public enum LockMode {
        case shared
        case exclusive

        #if !os(Windows)
        fileprivate var raw: CInt {
            switch self {
            case .shared: LOCK_SH
            case .exclusive: LOCK_EX
            }
        }
        #endif
    }

    public func tryLock(mode: LockMode) throws -> Bool {
        #if os(Windows)
        let handle = HANDLE(bitPattern: _get_osfhandle(rawValue))
        guard let handle, handle != INVALID_HANDLE_VALUE else { throw Errno.badFileDescriptor }
        var flags = DWORD(LOCKFILE_FAIL_IMMEDIATELY)
        if mode == .exclusive { flags |= DWORD(LOCKFILE_EXCLUSIVE_LOCK) }
        var overlapped = OVERLAPPED()
        if LockFileEx(handle, flags, 0, DWORD.max, DWORD.max, &overlapped) {
            return true
        }
        if GetLastError() == DWORD(ERROR_LOCK_VIOLATION) {
            return false
        }
        throw Errno.ioError
        #else
        if flock(rawValue, mode.raw | LOCK_NB) == 0 {
            return true
        }
        let err = errno
        if err == EWOULDBLOCK {
            return false
        }
        throw Errno(rawValue: err)
        #endif
    }
}
