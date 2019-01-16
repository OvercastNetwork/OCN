require_dependency 'minecraft/protocol/data'

module Minecraft
    module Protocol
        module Packet
            module Serverbound
                def direction
                    :serverbound
                end
            end

            module Clientbound
                def direction
                    :clientbound
                end
            end

            class << self
                def packets
                    # protocol -> direction -> packet_id -> class
                    @packets ||= Hash.default{ Hash.default{ {} } }
                end

                def read(io, protocol, direction)
                    decoder = Decoder.new(io)
                    decoder.varint # length
                    decoder.varint # ID
                    packet_id = decoder.values[1]

                    unless cls = Packet.packets[protocol.to_sym][direction.to_sym][packet_id]
                        raise "Unknown packet #{protocol}:#{direction}:#{packet_id}"
                    end

                    decoder.values.clear
                    cls.transcode_fields(decoder)
                    cls.new(*decoder.values)
                end
            end

            class Base
                class << self
                    attr :packet_id

                    def id(packet_id)
                        @packet_id = packet_id
                        Packet.packets[protocol][direction][packet_id] = self
                    end

                    def inspect
                        "#{protocol}:#{direction}:#{base_name}(#{packet_id})"
                    end

                    def fields
                        @fields ||= {}
                    end

                    def field(name, type)
                        index = fields.size
                        fields[name.to_sym] = type.to_sym

                        define_method name do
                            @values[index]
                        end

                        define_method "#{name}=" do |value|
                            @values[index] = value
                        end
                    end

                    def transcode_fields(stream)
                        fields.values.each do |type|
                            stream.__send__(type)
                        end
                    end
                end

                def initialize(*values, **fields)
                    @values = values
                    self.class.fields.each do |name, _|
                        @values << fields[name]
                    end
                end

                def inspect
                    "#{self.class.inspect}{#{self.class.fields.map{|name, _| "#{name}=#{__send__(name).inspect}"}.join(' ')}}"
                end

                def write(io)
                    io.write(encode)
                end

                def encode
                    encoded = ""
                    encoder = Encoder.new(StringIO.new(encoded))
                    encoder.values << self.class.packet_id
                    encoder.values.concat(@values)

                    encoder.varint # packet_id
                    self.class.transcode_fields(encoder)

                    prefix = ""
                    encoder = Encoder.new(StringIO.new(prefix))
                    encoder.values << encoded.size
                    encoder.varint # length

                    prefix + encoded
                end
            end
        end
    end
end
