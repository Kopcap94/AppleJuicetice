require 'httparty'
require 'json'

module DiscordBot
	module Wiki
	  class Wiki
		include HTTParty

		def initialize( client )
			@client = client
			@bot = client.bot
			@channels = client.channels
			@config = client.config
		end

		def start_check_recent_changes
			Thread.new {
				begin
					get_data_from_api
				rescue => err
					puts err
				end

				sleep @config[ 'rc_refresh' ]
				start_check_recent_changes
			}
		end

		def get_data_from_api
			d =  JSON.parse(
				HTTParty.get(
					"http://ru.mlp.wikia.com/api.php?action=query&list=recentchanges&rclimit=50&rcprop=user|title|timestamp|ids|comment|sizes&format=json",
					:verify => false
				).body,
				:symbolize_names => true
			)[ :query ][ :recentchanges ]

			rcid = @config[ 'rcid' ]
			show_uploads = @config[ 'show_uploads' ]
			last_rcid = d[ 0 ][ :rcid ]

			if rcid == 0 then
				@config[ 'rcid' ] = last_rcid
				@client.save_config
				return
			end

			if last_rcid <= rcid then
				return
			end

			d.reverse.each do | obj |
				if obj[ :rcid ] <= rcid then
					next
				elsif obj[ :type ] == 'log' and obj[ :ns ] == 6 and !show_uploads then
					next
				end

				emb = Discordrb::Webhooks::Embed.new

				emb.color = "#507299"

				case obj[ :type ]
				when "log"
					type = "Лог :pencil:"
				when "edit"
					type = "Изменение страницы :pencil2:"
				when "new"
					type = "Новая страница :paintbrush:"
				else
					type = "Неизвестный тип изменения :heavy_multiplication_x:"
				end
				emb.title = type
				emb.description = "http://ru.mlp.wikia.com/index.php?diff=#{ obj[ :revid ] }"

				emb.add_field( name: "Участник", value: obj[ :user ], inline: true )
				emb.add_field( name: "Страница", value: obj[ :title ], inline: true )

				if obj[ :ns ] != 6 then
					emb.add_field( name: "Изменения:", value: "#{ obj[ :newlen ] - obj[ :oldlen ] } байт", inline: true )
					emb.add_field( name: "Описание правки", value: "@ #{ obj[ :comment ] }" )
				end

				@bot.send_message( @channels[ 'recentchanges' ], '', false, emb )
				sleep 1
			end

			@config[ 'rcid' ] = last_rcid
			@client.save_config
		end
	  end
	end
end