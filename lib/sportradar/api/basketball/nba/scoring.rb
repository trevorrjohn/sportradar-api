module Sportradar
  module Api
    module Basketball
      class Nba
        class Scoring < Data
          attr_accessor :response, :api, :id, :home, :away, :scores

          def initialize(data, **opts)
            @api      = opts[:api]
            @game     = opts[:game]
            
            @scores = {
              1 => {},
              2 => {},
              3 => {},
              4 => {},
            }
            @id = data['id']
            
            update(data, **opts)
          end

          def update(data, source: nil, **opts)
            new_scores = case source
            when :box
              parse_from_box(data)
            when :pbp
              parse_from_pbp(data)
            when :summary
              parse_from_box(data)
            else
              if data['quarter']
                parse_from_pbp(data)
              elsif data['team']
                parse_from_box(data)
              else # schedule requests
                {}
              end
            end
            # parse data structure
            # handle data from team (all quarters)
            # handle data from quarter (both teams)
            # handle data from game?
            @scores.each { |k, v| v.merge!(new_scores.delete(k) || {} ) }
            new_scores.each { |k, v| @scores.merge!(k => v) }
          end

          def points(team_id)
            @score[team_id].to_i
          end


          private

          def parse_from_box(data)
            id = data.dig('team', 0, 'id')
            da = data.dig('team', 0, 'scoring', 'quarter')
            da_ot = data.dig('team', 0, 'scoring', 'overtime')
            arr = [da].compact.flatten(1)
            a = arr + [da_ot].compact.flatten(1)
            a.each { |h| h[id] = h.delete('points').to_i }
            id = data.dig('team', 1, 'id')
            da = data.dig('team', 1, 'scoring', 'quarter')
            da_ot = data.dig('team', 1, 'scoring', 'overtime')
            arr = [da].compact.flatten(1)
            b = arr + [da_ot].compact.flatten(1)
            b.each { |h| h[id] = h.delete('points').to_i }
            a.zip(b).map{ |a, b| [a['sequence'].to_i, a.merge(b)] }.sort{ |(a,_), (b,_)| a <=> b }.to_h
          end

          def parse_from_pbp(data)
            quarters = data['quarter'][1..-1]
            overtimes = data['overtime']
            overtimes = [overtimes] if !overtimes.is_a?(Array)
            quarters = quarters[0] if (quarters.is_a?(Array) && (quarters.size == 1) && quarters.first.is_a?(Array))
            data = (quarters + overtimes).compact.map{|q| q['scoring'] }
            data.map.with_index(1) { |h, i| [i, { h.dig('home', 'id') => h.dig('home', 'points').to_i, h.dig('away', 'id') => h.dig('away', 'points').to_i }] }.to_h
          end

          def parse_from_summary(data)
            # 
          end



          KEYS_PBP = ["xmlns", "id", "status", "coverage", "home_team", "away_team", "scheduled", "duration", "attendance", "lead_changes", "times_tied", "clock", "quarter", "scoring"]

          KEYS_BOX = ["xmlns", "id", "status", "coverage", "home_team", "away_team", "scheduled", "duration", "attendance", "lead_changes", "times_tied", "clock", "quarter", "team"]

        end
      end
    end
  end
end
