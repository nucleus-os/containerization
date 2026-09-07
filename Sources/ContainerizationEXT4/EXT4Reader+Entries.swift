//===----------------------------------------------------------------------===//
// Copyright © 2025 Apple Inc. and the Containerization project authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//===----------------------------------------------------------------------===//

import Foundation
import SystemPackage

extension EXT4.EXT4Reader {
    /// One name the image holds, and the inode it names.
    ///
    /// Two entries sharing an inode are two names for one file, which is what
    /// a hard link is. Reporting the inode rather than resolving it is what
    /// lets a caller tell that apart from two files with equal contents.
    public struct Entry: Sendable, Hashable {
        public let path: FilePath
        public let inode: EXT4.InodeNumber
        public let mode: UInt16

        public var isDirectory: Bool { mode & 0xF000 == 0x4000 }
        public var isSymbolicLink: Bool { mode & 0xF000 == 0xA000 }
        public var isRegularFile: Bool { mode & 0xF000 == 0x8000 }
        public var permissions: UInt16 { mode & 0o7777 }
    }

    /// Every name the image holds, ordered by path.
    ///
    /// `export` answers a similar question by writing an archive, and an
    /// archive is a lossy way to ask it: a hard link's two names cannot both
    /// survive unless the format and the extractor agree on ordering, so a
    /// caller checking whether the image kept a link cannot tell a lost link
    /// from a lossy export. Reading the inode table answers directly.
    public func entries() throws -> [Entry] {
        var found: [Entry] = []
        var pending = Array(unsafe self.tree.root.pointee.children)
        while let itemPtr = pending.popLast() {
            let item = unsafe itemPtr.pointee
            unsafe pending.append(contentsOf: item.children)
            guard let path = unsafe item.path else { continue }
            let inode = try self.getInode(number: unsafe item.inode)
            found.append(
                Entry(
                    path: FilePath("/" + path.description),
                    inode: unsafe item.inode,
                    mode: inode.mode))
        }
        return found.sorted { $0.path.string < $1.path.string }
    }
}
