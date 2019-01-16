require_dependency 'minecraft/protocol/packet'

module Minecraft
    module Protocol
        module Packet
            module Handshaking
                class Base < Packet::Base
                    def self.protocol
                        :handshaking
                    end
                end

                module In
                    class Base < Handshaking::Base
                        extend Serverbound
                    end

                    class SetProtocol < Base
                        id 0
                        field :protocol_version, :varint
                        field :server_address, :string
                        field :server_port, :ushort
                        field :next_state, :varint
                    end
                end

                module Out
                    class Base < Handshaking::Base
                        extend Clientbound
                    end
                end
            end
        end
    end
end
