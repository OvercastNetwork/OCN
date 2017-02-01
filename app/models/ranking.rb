class Ranking
    include Mongoid::Document
    include BackgroundIndexes
    store_in :database => "oc_engagements"

    # Maximum age of matches included in ranked stats
    TIME_WINDOW = 90.days

    # Minimum number of matches for a player to display stats and appear on the leaderboard
    MINIMUM_MATCHES = 1

    CONFIDENT_MATCHES = 30

    # Server family for ranked matches (only one for now)
    FAMILY_ID = 'ranked'

    # Maximum difference between two ratings that are considered equal
    # This hopefully corrects for floating point inaccuracy
    RATING_ERROR = 0.0000001

    # Since this model is generated from a map/reduce, all the fields
    # are in this embedded document, which is rather annoying.
    class Value
        include Mongoid::Document
        embedded_in :ranking

        belongs_to :user, index: true
        field :genre, type: Map::Genre # nil means all genres

        field :first_match_at,  type: Time
        field :last_match_at,   type: Time

        field :matches,         type: Integer, default: 0, as: :match_count
        field :wins,            type: Integer, default: 0
        field :losses,          type: Integer, default: 0
        field :ties,            type: Integer, default: 0
        field :forfeits,        type: Integer, default: 0

        field :win_loss_ratio,  type: Float,   default: 0.0
        field :rating,          type: Float,   default: 0.0

        field :qualified,       type: Boolean, default: false
    end

    embeds_one :value, class_name: 'Ranking::Value', autobuild: true

    scope :user, ->(user) { where('value.user_id' => user.id) }
    scope :genre, ->(g) { where('value.genre' => g) }
    scope :global, where('value.genre' => nil)
    scope :qualified, where('value.qualified' => true)

    [:user_id, :genre, :first_match_at, :last_match_at, :matches, :wins, :losses, :ties, :forfeits, :win_loss_ratio, :rating].each do |f|
        index({"value.#{f}" => 1})
    end

    index({'value.genre' => 1, 'value.qualified' => 1, 'value.rating' => -1, 'value.user_id' => -1})

    def qualified?
        value.match_count >= MINIMUM_MATCHES
    end

    def ordinal
        Ranking.qualified.genre(value.genre).gt('value.rating' => value.rating + RATING_ERROR).count + 1
    end

    def stale_at
        (value.first_match_at + TIME_WINDOW + 1.second).utc
    end

    def formatted_rating
        sprintf('%.03f', value.rating.round(3))
    end

    class << self
        def relevant_engagements(engagements)
            engagements.select do |eng|
                eng.family_id == FAMILY_ID
            end
        end

        def make_id(user_id, genre = nil)
            user_id = user_id.id if user_id.is_a? User
            if genre
                "#{user_id}:#{genre.to_s.upcase}"
            else
                user_id
            end
        end

        def find_or_initialize_by_user(user, genre = nil)
            id = make_id(user, genre)
            r = find(id) || new
            r.value.user ||= user
            r.value.genre ||= genre
            r
        end

        def by_ordinal
            # Order must be unambiguous, so resolve ties with user_id
            desc('value.rating', 'value.user_id')
        end

        def leaderboard(genre: nil)
            qualified.genre(genre).by_ordinal.limit(9999)
        end

        def time_window_start(now = Time.now)
            now - TIME_WINDOW
        end

        def starting_before_window(now = Time.now)
            lt('value.first_match_at' => time_window_start(now))
        end

        def starting_in_window(now = Time.now)
            gte('value.first_match_at' => time_window_start(now))
        end

        def ending_before_window(now = Time.now)
            lt('value.last_match_at' => time_window_start(now))
        end

        def ending_in_window(now = Time.now)
            gte('value.last_match_at' => time_window_start(now))
        end

        def by_first_match_time(dir = 1)
            order_by('value.first_match_at' => dir)
        end

        def by_last_match_time(dir = 1)
            order_by('value.last_match_at' => dir)
        end

        def nonempty
            gt('value.matches' => 0)
        end

        def stale(now = Time.now)
            nonempty.starting_before_window(now)
        end

        def first_non_stale(now = Time.now)
            nonempty.starting_in_window(now).by_first_match_time.first
        end

        def recalculate
            recalculate_for_user_ids(all.map{|r| r.value.user_id })
        end

        def recalculate_for_users(users)
            recalculate_for_user_ids(users.map(&:id))
        end

        def recalculate_all
            recalculate_for_engagements(effective_engagements)
        end

        def recalculate_for_user_ids(user_ids)
            recalculate_for_engagements(effective_engagements(user_ids: user_ids), user_ids: user_ids)
        end

        def effective_engagements(user_ids: nil)
            if family = Family.imap_find(FAMILY_ID)
                q = Engagement.ignored(false).family(family).gte(effective_at: time_window_start)
                q = q.in(user_id: user_ids.to_a) if user_ids
                q
            else
                logger.warn("Ranked family does not exist, no rankings will be calculated")
                Engagement.where(id: nil)
            end
        end

        def recalculate_for_engagements(engagements, user_ids: nil)
            # Build the set of Ranking IDs that will be updated by the M/R,
            # which we unfortunately cannot get from the M/R itself if it
            # outputs to a collection.
            nonempty_ids = Set[]
            engagements.each do |eng|
                nonempty_ids << make_id(eng.user_id)
                nonempty_ids << make_id(eng.user_id, eng.genre)
            end

            # Delete rankings that have no engagements.
            # The M/R will not touch these since nothing is emitted for them,
            # so we have to clean them up ourselves.
            q = nin(_id: nonempty_ids.to_a)
            q = q.in('value.user_id' => user_ids) if user_ids
            q.delete

            map_reduce_for_engagements(engagements).execute
        end

        def map_reduce_for_engagements(engagements)
            engagements.map_reduce(map_function, reduce_function)
                       .finalize(finalize_function)
                       .out(merge: collection.name)
        end

        def map_function
            <<-JS
                function() {
                    var sums = {
                        user_id: this.user_id,
                        first_match_at: this.effective_at,
                        last_match_at: this.effective_at,
                        matches: 1,
                        wins: 0,
                        losses: 0,
                        ties: 0,
                        forfeits: 0,
                    };

                    if(this.forfeit_reason) {
                        // Give two losses to anyone who forfeited, regardless of the match result
                        sums.forfeits = 1;
                        sums.losses = 2;
                    } else if(this.rank == 0) {
                        if(this.tied_count == this.competitor_count) {
                            // If all competitors are tied for first, the match is a tie
                            sums.ties = 1;
                        } else {
                            // If some competitors were not in first place, give a win for each of them,
                            // divided evenly among the competitors who were in first.
                            sums.wins = (this.competitor_count - this.tied_count) / this.tied_count;
                        }
                    } else if(this.rank > 0) {
                        // Give one loss to everyone who was not in first place
                        sums.losses = 1;
                    }

                    sums.genre = null;
                    emit(this.user_id, sums);
                    sums.genre = this.genre;
                    emit(this.user_id + ":" + this.genre, sums);
                }
            JS
        end

        def reduce_function
            <<-JS
                function(key, values) {
                    var sums = {
                        user_id: values[0].user_id,
                        genre: values[0].genre,
                        first_match_at: null,
                        last_match_at: null,
                        matches: 0,
                        wins: 0,
                        losses: 0,
                        ties: 0,
                        forfeits: 0
                    };

                    for(var i = 0; i < values.length; i++) {
                        var value = values[i];

                        if(!sums.first_match_at || value.first_match_at.getTime() < sums.first_match_at.getTime()) {
                            sums.first_match_at = value.first_match_at;
                        }

                        if(!sums.last_match_at || value.last_match_at.getTime() > sums.last_match_at.getTime()) {
                            sums.last_match_at = value.last_match_at;
                        }

                        sums.matches += value.matches;
                        sums.wins += value.wins;
                        sums.losses += value.losses;
                        sums.ties += value.ties;
                        sums.forfeits += value.forfeits;
                    }

                    return sums;
                }
            JS
        end

        def finalize_function
            %Q{
                function(key, sums) {
                    sums.qualified = sums.matches >= #{MINIMUM_MATCHES};
                    sums.win_loss_ratio = sums.wins == 0 ? 0 : sums.wins / sums.losses;
                    sums.rating = sums.wins / Math.max(30, sums.wins + sums.losses);
                    return sums;
                }
            }
        end
    end
end
