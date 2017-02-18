module Minecraft
    module Protocol
        class Transcoder
            def values
                @values ||= []
            end

            def initialize(io)
                @io = io
            end

            def pack(length, format)
                raise NoMethodError
            end

            def byte
                pack(1, 'c')
            end

            def ubyte
                pack(1, 'C')
            end

            def short
                pack(2, 's>')
            end

            def ushort
                pack(2, 'S>')
            end

            def integer
                pack(4, 'i>')
            end

            def long
                pack(8, 'q>')
            end

            def float
                pack(4, 'g')
            end

            def double
                pack(8, 'G')
            end
        end

        class Decoder < Transcoder
            def pack(length, format)
                values << @io.read(length).unpack(format)[0]
            end

            def varnum(len)
                n = v = 0
                loop do
                    b = @io.read(1).ord
                    v |= (b & 0x7f) << (7 * n)
                    break if b & 0x80 == 0
                    n += 1
                    raise "VarInt too long" if n > len
                end
                values << v
            end

            def varint
                varnum(5)
            end

            def varlong
                varnum(10)
            end

            def string
                varint
                values << @io.read(values.pop)
            end
        end

        class Encoder < Transcoder
            def pack(length, format)
                @io.write([values.shift].pack(format))
            end

            def varint
                v = values.shift % 0x1_0000_0000
                loop do
                    b = v & 0x7f
                    v >>= 7
                    b |= 0x80 unless v == 0
                    @io.putc(b)
                    break if v == 0
                end
            end

            def varlong
                varint
            end

            def string
                v = values.shift
                values.unshift(v.size)
                varint
                @io.write(v)
            end
        end
    end
end
