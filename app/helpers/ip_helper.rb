module IpHelper

    def describe_user_ip(user)
        describe_ip(user.mc_last_sign_in_ip)
    end

    def describe_ip(ip = nil)
        location = locate_ip(ip)
        if location[:real_region_name] == 'Unknown'
            location[:real_region_name]
        else
            [
                location[:city_name],
                location[:real_region_name],
                location[:country_name]
            ].reject(&:blank?).join(', ')
        end
    end

    def locate_ip(ip = nil)
        if city = GEOIP.city(ip)
            city.to_hash
        else
            ip = '127.0.0.1'
            name = 'Unknown'
            tag = 'N/A'
            id = -1
            {
                request: ip,
                ip: ip,
                country_code2: tag,
                country_code3: tag,
                country_name: name,
                continent_code: tag,
                region_name: name,
                city_name: name,
                postal_code: id,
                latitude: id,
                longitude: id,
                dma_code: id,
                area_code: id,
                timezone: name,
                real_region_name: name
            }
        end
    end

end
