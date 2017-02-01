module PaginationHelper
    def clamp_page(items, page, per_page = nil)
        per_page ||= PGM::Application.config.global_per_page
        [1, page.to_i, (items.count.to_f / per_page).ceil].sort[1]
    end

    def page_param(items, key: nil, per_page: nil)
        clamp_page(items, params[key || :page] || 1, per_page)
    end

    def a_page_of(items, key: nil, page: nil, per_page: nil)
        per_page ||= PGM::Application.config.global_per_page
        page ||= page_param(items, key: key, per_page: per_page)
        items.page(page).per(per_page)
    end
end
