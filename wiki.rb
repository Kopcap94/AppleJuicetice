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
				get_data_from_api

				sleep 60
				start_check_recent_changes
			}
		end

		def get_data_from_api
			d =  JSON.parse(
				HTTParty.get(
					"http://ru.mlp.wikia.com/api.php?action=query&list=recentchanges&rclimit=50&rcprop=user|title|timestamp|ids|comment&format=json",
					:verify => false
				).body,
				:symbolize_names => true
			)[ :query ][ :recentchanges ]

			rcid = @config[ 'rcid' ]
			show_uploads = @config[ 'show_uploads' ]

			if d[ 0 ][ :rcid ] <= rcid then
				return
			end
			last_rcid = d[ 0 ][ :rcid ]

			d.reverse.each do | obj |
				if obj[ :rcid ] <= rcid then
					next
				elsif obj[ :type ] == 'log' and obj[ :ns ] == 6 and !show_uploads then
					next
				end

				case obj[ :type ]
				when "log"
					type = "Лог"
				when "edit"
					type = "Изменение страницы"
				when "new"
					type = "Новая страница"
				else
					type = "Неизвестный тип изменения"
				end

				url = "http://ru.mlp.wikia.com/index.php?diff=#{ obj[ :revid ] }"
				message = "="*80 + "\n**Тип правки:** #{ type }\n**Участник:** #{ obj[ :user ] }\n**Страница:** #{ obj[ :title ] }\n"
				if obj[ :ns ] != 6 then
					message = message + "**Описание правки:** #{ obj[ :comment ] }\n**Изменения:** #{ url }\n" + "="*80
				else
					message = message + "**Изображение:** http://ru.mlp.wikia.com/index.php?title=#{ obj[ :title ].split( "\s" ).join( "_" ) }\n" + "="*80
				end

				@bot.send_message( @channels[ 'recentchanges' ], message )
				sleep 1
			end

			@config[ 'rcid' ] = last_rcid
			@client.save_config
		end
	  end
	end
end