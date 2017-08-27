class User
    module Alts
        extend ActiveSupport::Concern
        include RequestCacheable

        def alts
            request_cache.cache(:alts) do
                [] # Kubernetes normalized ips to the host ip, need to fix this with a reverse proxy
                #self.class.in(mc_ips: mc_ips).reject{|u| u == self }.sort_by(&:last_seen_by).reverse
            end
        end

        def can_index_alts?(scope, user = self)
            user ||= User.anonymous_user
            user.admin? ||
                user.has_permission?('misc', 'alt', 'index', scope) ||
                (scope == 'own' && user.has_permission?('misc', 'alt', 'index', 'all'))
        end
    end # Alts
end
