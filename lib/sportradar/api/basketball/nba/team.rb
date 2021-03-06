module Sportradar
  module Api
    module Basketball
      class Nba
        class Team < Data
          attr_accessor :response, :id, :market, :name, :alias, :full_name, :venue, :records, :player_stats, :team_stats
          @all_hash = {}
          def self.new(data, **opts)
            existing = @all_hash[data['id']]
            if existing
              existing.update(data, **opts)
              existing
            else
              @all_hash[data['id']] = super
            end
          end
          def self.all
            @all_hash.values
          end

          def initialize(data, **opts)
            @response = data
            @api      = opts[:api]
            @games_hash   = {}
            @players_hash = {}
            @player_stats = {}
            @records      = {}

            case response
            when String
              @id = response
            when Hash
              @id = data['id']
              update(response, **opts)
            end
          end

          def profile
            Profile.new(self)
          end

          def update(data, **opts)
            handle_names(data)

            @venue    = Venue.new(data['venue']) if data['venue']

            @alias    = data['alias']                 if data['alias']
            @points   = data['points'].to_i           if data['points']
            @home     = data['home'] == 'true'        if data['home']
            @away     = data['away'] == 'true'        if data['away']
            @scoring  = data.dig('scoring', 'quarter') if data.dig('scoring', 'quarter')

            parse_records(data)                                          if data['records']
            parse_players(data.dig('players', 'player'), opts[:game])   if data.dig('players', 'player')
            parse_stats(data['statistics'])                             if data['statistics']
            if opts[:game]
              add_game(opts[:game])
              opts[:game].update_score(id => @points) if @points
              opts[:game].update_stats(self, @stats)  if @stats
            end
          end
          def handle_names(data)
            # need to do some more work here
            @name = data['name'] if data['name']
            if data['name'] && !data.key?('market')
              @full_name = data['name']
              if @full_name.split.size > 1
                if @full_name.include? 'Blazers'
                  @market = 'Portland'
                  @name = 'Trail Blazers'
                  @full_name = 'Portland Trail Blazers'
                else
                  @market = @full_name.split[0..-2].join(' ')
                  @name = @full_name.split.last
                end
              end
            elsif data['name'] && data['market']
              @market = data['market']
              @full_name = [@market, data['name']].join(' ')
            end
          end

          def record(type = 'overall')
            @records[type]
          end

          def games
            @games_hash.values
          end
          def add_game(game)
            @games_hash[game.id] = game.id if game
          end

          def parse_stats(data)
            @stats = data
          end

          def players
            get_roster if @players_hash.empty?
            @players_hash.values
          end
          alias :roster :players
          def parse_players(data, game)
            create_data(@players_hash, data, klass: Player, api: api, team: self, game: game)
          end
          def update_player_stats(player, stats, game = nil)
            game ? game.update_player_stats(player, stats) : @player_stats.merge!(player.id => stats.merge!(player: player))
          end

          def get_roster
            data = api.get_data(path_roster)['team']
            update(data)
            data
          end

          def get_season_stats
            data = api.get_data(path_season_stats).dig('season', 'team')
            parse_season_stats(data)
          end

          def parse_records(data)
            @records['overall'] = Record.new(data, type: 'overall')
            data['records'].each { |type, record| @records[type] = Record.new(record, type: type) }
          end

          def parse_season_stats(data)
            @team_stats = data.dig('team_records')
            update(data)
            player_data = data.dig('player_records', 'player')
            create_data(@players_hash, player_data, klass: Player, api: api, team: self)
            data
          end

          def path_base
            "teams/#{ id }"
          end
          def path_base_stats(season_year = api.default_year, nba_season = api.default_season)
            "seasontd/#{season_year}/#{nba_season}/teams/#{id}/"
          end
          def path_roster
            "#{ path_base }/profile"
          end
          def path_season_stats
            "#{ path_base_stats }/statistics"
          end


          def api
            @api || Sportradar::Api::Basketball::Nba.new
          end

          KEYS_SCHEDULE = ["name", "alias", "id", "__content__"]

        end
      end
    end
  end
end

__END__
ss = sr.schedule;
sd = sr.daily_schedule;
sr = Sportradar::Api::Basketball::Nba.new
lh = sr.league_hierarchy;
t = lh.teams.first;
ss = t.get_season_stats;
g = sd.games.last;
t = g.home;
Sportradar::Api::Basketball::Nba::Team.all.size


# week_count = ss.weeks.count;
# w1 = ss.weeks.first;
# w1 = ss.weeks(1);