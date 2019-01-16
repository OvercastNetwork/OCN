require_dependency 'minecraft/protocol/packet'

module Minecraft
    module Protocol
        module Packet
            module Status
                class Base < Packet::Base
                    def self.protocol
                        :status
                    end
                end

                module In
                    class Base < Status::Base
                        extend Serverbound
                    end

                    class Start < Base
                        id 0
                    end

                    class Ping < Base
                        id 1
                        field :payload, :long
                    end
                end

                module Out
                    class Base < Status::Base
                        extend Clientbound
                    end

                    class ServerInfo < Base
                        id 0
                        field :json, :string
                    end

                    class Pong < Base
                        id 1
                        field :payload, :long
                    end
                end
            end
        end
    end
end
