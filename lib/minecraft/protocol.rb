require_dependency 'minecraft/protocol/packet'

module Minecraft
    module Protocol

        VERSION = 316
        PROTOCOLS = [:handshaking, :status, :login, :play]

        class ServerInfo
            attr :json,
                 :version, :protocol,
                 :max_players, :online_players,
                 :description, :icon,
                 :map_name, :map_icon,
                 :participants, :observers

            def decode_icon(uri)
                if uri && uri =~ %r{^data:image/png;base64,(.*)$}m
                    Base64.decode64($1)
                end
            end

            def initialize(json)
                @json = json
                if version = json['version']
                    @version = version['name']
                    @protocol = version['protocol']
                end
                if players = json['players']
                    @max_players = players['max']
                    @online_players = players['online']
                end
                @description = json['description']
                if icon = json['favicon']
                    @icon = decode_icon(icon)
                end
                if pgm = json['pgm']
                    @participants = pgm['participants'].to_i
                    @observers = pgm['observers'].to_i

                    if map = pgm['map']
                        @map_name = map['name']
                        @map_icon = decode_icon(map['icon'])
                    end
                end
            end

            def pgm?
                json.key?('pgm')
            end
        end

        class Client
            def initialize(host:, port: 25565)
                @host = host
                @port = port
                @io = TCPSocket.new(host, port)
                @protocol = :handshaking
            end

            def read
                packet = Packet.read(@io, @protocol, :clientbound)
                puts "<<< #{packet.inspect}"
                packet
            end

            def write(packet)
                puts ">>> #{packet.inspect}"
                packet.write(@io)
                if packet.is_a?(Packet::Handshaking::In::SetProtocol)
                    @protocol = PROTOCOLS[packet.next_state]
                end
            end

            def handshake(protocol)
                write Packet::Handshaking::In::SetProtocol.new(
                    protocol_version: VERSION,
                    server_address: @host,
                    server_port: @port,
                    next_state: PROTOCOLS.index(protocol)
                )
            end

            def ping(payload = nil)
                handshake(:status)
                write(Packet::Status::In::Ping.new(payload: payload || Time.now.to_i))
                response = read.payload
                @io.close
                response
            end

            def status
                handshake(:status)
                write(Packet::Status::In::Start.new)
                json = JSON.parse(read.json)
                @io.close
                ServerInfo.new(json)
            end
        end

        class << self
            def ping(host:, port: 25565, payload: nil)
                Client.new(host: host, port: port).ping(payload)
            end

            def status(host:, port: 25565)
                Client.new(host: host, port: port).status
            end
        end
    end
end
