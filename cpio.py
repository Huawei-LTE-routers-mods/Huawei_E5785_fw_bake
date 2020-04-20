import os

CHUNK_HDR_LEN = 110
ATTR_IS_DIR = 0o40000

class Chunk:
    def __str__(self):
        return (f"Chunk{{"
                    f"{self.magic=:#x}, "
                    f"{self.ino=}, "
                    f"{self.mode=:#o}, "
                    f"{self.uid=}, "
                    f"{self.gid=}, "
                    f"{self.nlink=}, "
                    f"{self.mtime=}, "
                    f"{self.filesize=}, "
                    f"{self.devmajor=}, "
                    f"{self.devminor=}, "
                    f"{self.rdevmajor=}, "
                    f"{self.rdevminor=}, "
                    f"{self.namesize=}, "
                    f"{self.check=}, "
                    f"{self.filename=}, "
                    f"{len(self.data)=}, "
                f"}}")

class Cpio:
    def __init__(self, filename):
        self.f = open(filename, "rb")

        self.chunks = []
        while chunk := self.read_next_chunk():
            self.chunks.append(chunk)
            if chunk.filename == b'TRAILER!!!\x00':
                break

        # end_padding = -self.f.tell() % 512
        # if end_padding != 0:
        #     if (self.f.read(end_padding) != b"\x00" * end_padding):
        #         raise ValueError("Bad end padding")

        # if self.f.read(1):
        #     raise ValueError("Some data in the end")

        self.nextino = max(chunk.ino for chunk in self.chunks) + 1


    def read_next_chunk(self):
        chunk = Chunk()

        magic = self.f.read(6)
        if len(magic) == 0:
            return None

        chunk.magic = int(magic, 16)
        if chunk.magic != 0x070701:
            raise ValueError(f"bad magic {hex(chunk.magic)}")

        chunk.ino = int(self.f.read(8), 16)
        chunk.mode = int(self.f.read(8), 16)
        chunk.uid = int(self.f.read(8), 16)
        chunk.gid = int(self.f.read(8), 16)
        chunk.nlink = int(self.f.read(8), 16)
        chunk.mtime = int(self.f.read(8), 16)
        chunk.filesize = int(self.f.read(8), 16)
        chunk.devmajor = int(self.f.read(8), 16)
        chunk.devminor = int(self.f.read(8), 16)
        chunk.rdevmajor = int(self.f.read(8), 16)
        chunk.rdevminor = int(self.f.read(8), 16)
        chunk.namesize = int(self.f.read(8), 16)
        chunk.check = int(self.f.read(8), 16)

        chunk.filename = self.f.read(chunk.namesize)

        padding1_len = - (110 + chunk.namesize) % 4
        self.f.read(padding1_len)

        chunk.data = self.f.read(chunk.filesize)
        padding2_len = - (chunk.filesize) % 4
        self.f.read(padding2_len)

        return chunk

    def write_chunks(self, filename):
        out_file = open(filename, "wb")

        for chunk in self.chunks:
            out_file.write(f"{chunk.magic:06X}".encode())
            out_file.write(f"{chunk.ino:08X}".encode())
            out_file.write(f"{chunk.mode:08X}".encode())
            out_file.write(f"{chunk.uid:08X}".encode())
            out_file.write(f"{chunk.gid:08X}".encode())
            out_file.write(f"{chunk.nlink:08X}".encode())
            out_file.write(f"{chunk.mtime:08X}".encode())
            out_file.write(f"{chunk.filesize:08X}".encode())
            out_file.write(f"{chunk.devmajor:08X}".encode())
            out_file.write(f"{chunk.devminor:08X}".encode())
            out_file.write(f"{chunk.rdevmajor:08X}".encode())
            out_file.write(f"{chunk.rdevminor:08X}".encode())
            out_file.write(f"{chunk.namesize:08X}".encode())
            out_file.write(f"{chunk.check:08X}".encode())

            out_file.write(chunk.filename)
            padding1_len = - (110 + chunk.namesize) % 4
            out_file.write(b"\x00" * padding1_len)

            out_file.write(chunk.data)
            padding2_len = - (chunk.filesize) % 4
            out_file.write(b"\x00" * padding2_len)

        end_padding = -out_file.tell() % 512
        if end_padding != 0:
            out_file.write(b"\x00" * end_padding)
        out_file.close()


    def delete_chunk_by_filename(self, filename):
        if isinstance(filename, str):
            filename = filename.encode() + b"\x00"

        self.chunks = [chunk for chunk in self.chunks if chunk.filename != filename]


    def inject_file(self, filename, mode, uid, gid, mtime, data):
        if isinstance(filename, str):
            filename = filename.encode() + b"\x00"

        if mode & ATTR_IS_DIR:
            for chunk in self.chunks:
                if chunk.filename == filename:
                    # do not create dir if exists
                    return

        self.delete_chunk_by_filename(filename)

        chunk = Chunk()
        chunk.magic = self.chunks[0].magic
        chunk.ino = self.nextino
        self.nextino += 1
        chunk.mode = mode
        chunk.uid = uid
        chunk.gid = gid
        chunk.nlink = 1
        chunk.mtime = int(mtime)
        chunk.filesize = len(data)
        chunk.devmajor= self.chunks[0].devmajor
        chunk.devminor= self.chunks[0].devminor
        chunk.rdevmajor= self.chunks[0].rdevmajor
        chunk.rdevminor= self.chunks[0].rdevminor
        chunk.namesize = len(filename)
        chunk.check = self.chunks[0].check

        chunk.filename = filename
        chunk.data = data

        self.chunks.insert(-1, chunk)


    def inject_fs_file(self, filename, uid=0, gid=0, mode=0o0777, newname=""):
        fileinfo = os.stat(filename)

        try:
            data = open(filename, "rb").read()
        except IsADirectoryError:
            data = b""


        if not newname:
            newname = filename

        self.inject_file(newname, mode, uid, gid, fileinfo.st_mtime, data)


    def get_chunks_by_filename(self, filename):
        if isinstance(filename, str):
            filename = filename.encode() + b"\x00"
        return [chunk for chunk in self.chunks if chunk.filename == filename]


    def rename_file(self, from_file, to_file, fail_if_absent=True):
        if isinstance(from_file, str):
            from_file = from_file.encode() + b"\x00"
        if isinstance(to_file, str):
            to_file = to_file.encode() + b"\x00"

        chunks_file = self.get_chunks_by_filename(from_file)
        if not chunks_file:
            if not fail_if_absent:
                return
            raise ValueError(f"file {from_file} is not exists while trying to rename it")
        elif len(chunks_file) > 1:
            raise ValueError(f"more than one {from_file} while trying to rename it")

        chunk = chunks_file[0]
        self.delete_chunk_by_filename(from_file)

        self.inject_file(to_file, chunk.mode, chunk.uid, chunk.gid, chunk.mtime, chunk.data)
