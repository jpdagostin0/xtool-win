#if os(Windows)
	import Foundation
	import ucrt
	import WinSDK

	// Windows has neither <cpio.h> nor the POSIX *at() family. Directory descriptors aren't a thing either, so
	// these only support AT_FDCWD and resolve paths against the current directory.

	let C_ISDIR: CInt = 0o040000
	let C_ISREG: CInt = 0o100000
	let C_ISLNK: CInt = 0o120000
	let C_ISVTX: CInt = 0o001000
	let MAGIC = "070707"

	let AT_FDCWD: CInt = -100

	typealias mode_t = CInt

	/// Converts an archive path into an absolute `\\?\` path, which isn't subject to MAX_PATH.
	private func extendedPath(_ path: String) -> String {
		var components = path.hasPrefix("/") ? [] : FileManager.default.currentDirectoryPath
			.split(whereSeparator: { $0 == "/" || $0 == "\\" })
			.map(String.init)
		for component in path.split(whereSeparator: { $0 == "/" || $0 == "\\" }) {
			switch component {
				case ".":
					continue
				case "..":
					_ = components.popLast()
				default:
					components.append(String(component))
			}
		}
		return #"\\?\"# + components.joined(separator: "\\")
	}

	private func withWidePath<T>(_ path: String, _ body: (UnsafePointer<WCHAR>) -> T) -> T {
		extendedPath(path).withCString(encodedAs: UTF16.self, body)
	}

	private func setErrno() {
		// Approximate, but enough for perror to be meaningful
		switch Int32(GetLastError()) {
			case ERROR_FILE_NOT_FOUND, ERROR_PATH_NOT_FOUND:
				_set_errno(ENOENT)
			case ERROR_ALREADY_EXISTS, ERROR_FILE_EXISTS:
				_set_errno(EEXIST)
			case ERROR_ACCESS_DENIED, ERROR_PRIVILEGE_NOT_HELD:
				_set_errno(EACCES)
			default:
				_set_errno(EIO)
		}
	}

	func openat(_ dirfd: CInt, _ path: String, _ flags: CInt, _ mode: mode_t) -> CInt {
		precondition(dirfd == AT_FDCWD)
		let handle = withWidePath(path) {
			CreateFileW($0, DWORD(GENERIC_WRITE), 0, nil, DWORD(CREATE_ALWAYS), DWORD(FILE_ATTRIBUTE_NORMAL), nil)
		}
		guard let handle, handle != INVALID_HANDLE_VALUE else {
			setErrno()
			return -1
		}
		let fd = _open_osfhandle(Int(bitPattern: handle), _O_WRONLY | _O_BINARY)
		if fd < 0 {
			CloseHandle(handle)
		}
		return fd
	}

	func pwrite(_ fd: CInt, _ buffer: UnsafeRawPointer?, _ count: Int, _ offset: Int64) -> Int {
		guard let handle = HANDLE(bitPattern: _get_osfhandle(fd)) else {
			_set_errno(EBADF)
			return -1
		}
		var overlapped = OVERLAPPED()
		overlapped.Offset = DWORD(truncatingIfNeeded: offset)
		overlapped.OffsetHigh = DWORD(truncatingIfNeeded: offset >> 32)
		var written: DWORD = 0
		guard WriteFile(handle, buffer, DWORD(count), &written, &overlapped) else {
			setErrno()
			return -1
		}
		return Int(written)
	}

	func mkdirat(_ dirfd: CInt, _ path: String, _ mode: mode_t) -> CInt {
		precondition(dirfd == AT_FDCWD)
		guard withWidePath(path, { CreateDirectoryW($0, nil) }) else {
			setErrno()
			return -1
		}
		return 0
	}

	func linkat(_ olddirfd: CInt, _ oldpath: String, _ newdirfd: CInt, _ newpath: String, _ flags: CInt) -> CInt {
		precondition(olddirfd == AT_FDCWD && newdirfd == AT_FDCWD)
		let success = withWidePath(oldpath) { old in
			withWidePath(newpath) { new in
				CreateHardLinkW(new, old, nil)
			}
		}
		guard success else {
			setErrno()
			return -1
		}
		return 0
	}

	func symlinkat(_ target: String, _ newdirfd: CInt, _ linkpath: String) -> CInt {
		precondition(newdirfd == AT_FDCWD)
		// Must be called after the target has been extracted, so we can tell whether it's a directory
		let resolved: String
		if target.hasPrefix("/") {
			resolved = target
		} else if let slash = linkpath.lastIndex(of: "/") {
			resolved = linkpath[..<slash] + "/" + target
		} else {
			resolved = target
		}
		let attributes = withWidePath(resolved) { GetFileAttributesW($0) }
		var flags = DWORD(SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE)
		if attributes != INVALID_FILE_ATTRIBUTES && attributes & DWORD(FILE_ATTRIBUTE_DIRECTORY) != 0 {
			flags |= DWORD(SYMBOLIC_LINK_FLAG_DIRECTORY)
		}
		let windowsTarget = target.replacingOccurrences(of: "/", with: "\\")
		let success = withWidePath(linkpath) { link in
			windowsTarget.withCString(encodedAs: UTF16.self) { target in
				CreateSymbolicLinkW(link, target, flags)
			}
		}
		guard success != 0 else {
			setErrno()
			return -1
		}
		return 0
	}

	func fchmodat(_ dirfd: CInt, _ path: String, _ mode: mode_t, _ flags: CInt) -> CInt {
		// No sticky bit on Windows
		0
	}
#endif
