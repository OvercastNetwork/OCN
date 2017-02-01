class RevisionsController < ApplicationController
    layout "application"

    PAGES = 50 # Would be really nice if we could actually detect this

    def index
        redirect_to revision_path(Repository.select(&:visible?).first.id)
    end

    def show
        @repositories = Repository.select(&:visible?)
        @repository = @repositories.find{|r| r.id.to_s == params[:id].to_s }
        return redirect_to revisions_path unless @repository

        @per_page = PGM::Application.config.global_per_page
        @page = (1..PAGES).clamp(int_param(:page, default: 1))

        # Because some commits are hidden by INT, a raw page might be
        # smaller than our page, so we have to keep getting more results
        # until our page is full.
        @revs = []
        raw_page = @page
        while @revs.size < @per_page
            begin
                raw_revs = @repository.revisions(per_page: @per_page, page: raw_page).reject(&:internal?)
                break if raw_revs.empty?
                @revs += raw_revs[0...(@per_page - @revs.size)]
                raw_page += 1
            rescue IOError, Timeout::Error
                @failed = true
                break
            end
        end

        @repository.prefetch_authors(@revs)
    end

    helper do
        def paginate_revs
            paginator = Kaminari::Helpers::Paginator.new(self, current_page: @page, total_pages: PAGES, per_page: @per_page)
            paginator.to_s
        end
    end
end
