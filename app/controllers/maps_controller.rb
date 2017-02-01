
class MapsController < ApplicationController
    include ActionView::Helpers::NumberHelper

    before_filter :find_servers
    before_filter :find_map, only: [:show, :download]
    before_render :check_ratings_enabled
    before_render :prefetch_authors
    before_render :paginate_maps, only: [:all, :now_playing, :gamemode]

    def all
        @maps = Map.loaded.order_by_rating.default_variants.select(&:can_view?)
        render 'index'
    end

    def now_playing
        @maps = Map.loaded.order_by_rating.for_slugs(@servers_by_map_slug.keys)
        render 'index'
    end

    def gamemode
        @gamemode_id = params[:gamemode].to_s.to_sym
        if @gamemode_id == :ranked
            # We don't actually want the ranked editions of the maps,
            # we want the standard edition of maps that have a ranked edition.
            # Strange? yes.
            slugs = Map.loaded.edition(Map::Edition::RANKED).pluck(:slug).compact.uniq
            @maps = Map.order_by_rating(current_user_safe).for_slugs(slugs)
        else
            return not_found unless @gamemode = Map::GAMEMODES[@gamemode_id]
            @maps = Map.loaded.gamemode(@gamemode_id).order_by_rating.default_variants
        end
        render "index"
    end

    def rotation
        @server = model_param(Server, :server)
        @maps = @server.rotation_maps
        @maps = Kaminari.paginate_array(@maps).page(current_page).per(27)
        render 'index'
    end

    def show
        @variants = @map.variants.viewable.to_a.sort_by{|m| [m.edition, m.phase] }

        @gamemode_id = @map.gamemode[0].to_sym
        @gamemode = Map::GAMEMODES[@gamemode_id]

        @show_map_ratings = @map.can_view_ratings?(current_user_safe)

        @matches = a_page_of(@map.fucking_matches.criteria.loaded_or_played.recent.desc(:load))
    end

    def download
        fn = @map.dist_file_name or raise NotFound
        @map.can_download? or raise Forbidden
        zip = @map.dist_file or raise NotFound
        send_data zip, filename: fn, type: 'application/zip', disposition: 'attachment'
    end

    protected

    def find_servers
        @servers = Server.pgms.network(Server::Network::PUBLIC).visible_to_public.by_priority.to_a
        @servers_by_datacenter = @servers.group_by(&:datacenter).sort_by{|_, servers| -servers.size }.mash
        @servers_by_map_slug = @servers.select{|s| s.online? && s.current_map? }.group_by{|s| s.current_map.slug }
    end

    def find_map
        id = params[:id]
        @map = Map.find(id) || Map.default_variants(Map.where(slug: id).viewable).first
        not_found unless @map && @map.can_view?
    end

    def check_ratings_enabled
        @show_map_ratings = Map.can_view_any_ratings?(current_user_safe) if @maps
    end

    # Eager load all authors into the identity map
    def prefetch_authors
        User.find(*@maps.flat_map(&:author_ids)) if @maps
    end

    def paginate_maps
        @maps = Kaminari.paginate_array(@maps).page(current_page).per(27) if @maps
    end

    helper do
        def variant_label(map)
            label = "#{map.edition.name.capitalize} edition"
            label << " (#{map.phase.name.downcase})" unless map.phase == Map::Phase::DEFAULT
            label
        end
    end
end
